import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/course.dart';
import '../services/database_service.dart';
import '../services/native_alarm_service.dart';
import '../services/foreground_service_manager.dart';

/// Manages course push notifications using periodic polling instead of AlarmManager.
///
/// A Dart Timer fires every ~30 seconds, checks the current time against the
/// course schedule, and posts/updates notifications through the native channel.
/// A persistent Foreground Service keeps the Dart isolate running when the app
/// is in the background on aggressive OEM firmware (vivo, Oppo, Xiaomi).
///
/// Architecture:
///   - Reminder: posted at (class start - advanceMinutes). Dismissible, makes a
///     sound. Replaced by the ongoing banner when class starts.
///   - Ongoing:  posted at class start, same notifyId as the reminder so it
///     replaces it in place. Non-dismissible until class ends.
///   - Cancel:   at class end the ongoing banner is removed via
///     `cancelNotification` (there is no separate "dismiss" notification —
///     `_kindDismiss` exists only to keep the ID space unambiguous).
///
/// At most one notification per course is ever live: only the occurrence
/// falling on today's date in the current week is considered.
class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelOngoingId = 'course_ongoing';
  static const _pollInterval = Duration(seconds: 30);

  static bool _serviceStarted = false;
  static Timer? _pollTimer;
  static List<Course> _courses = [];
  static DateTime? _firstDay;
  static int _advanceMinutes = 15;

  // Which notification each course is currently showing, keyed by course ID.
  // null/absent = nothing shown; "reminder" / "ongoing" = currently displayed.
  // Note: this is *our* record of what we posted, so a user-dismissed reminder
  // is still recorded here — we deliberately do not re-post it every 30s.
  static final Map<String, String?> _activeNotification = {};

  // ─── Init ───

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await plugin.initialize(initSettings,
        onDidReceiveNotificationResponse: _onTap);

    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    // Course notifications channel
    const ongoingChannel = AndroidNotificationChannel(
      _channelOngoingId,
      '上课常驻',
      description: '上课期间常驻通知栏',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    await androidPlugin?.createNotificationChannel(ongoingChannel);

    await _rescheduleIfNeeded();
  }

  // ─── Public API ───

  static Future<void> scheduleAll(List<Course> courses) async {
    _courses = courses;
    _firstDay = await StorageService.getSemesterFirstDay();
    _advanceMinutes = await StorageService.getAdvanceMinutes();
    await _startPolling();
  }

  static Future<void> cancelAll() async {
    _stopPolling();
    _activeNotification.clear();
  }

  // ─── Tap handler ───

  static void _onTap(NotificationResponse response) {}

  // ─── Internals: IDs / helpers ───

  // Notification IDs are *packed*, never hashed.
  //
  // The previous scheme used `'$courseId-reminder-$week'.hashCode.abs()`.
  // A 32-bit hash over ~800 generated IDs collides with high probability
  // (birthday paradox), and two colliding IDs make Android overwrite one
  // course's notification with another's — a silent, intermittent lost
  // reminder. Dart hash codes are also seeded per process, so the same code
  // produced different collisions on different launches.
  //
  // Packing is exact and therefore collision-free by construction:
  //   bits  0- 2  kind   (0=reminder, 1=ongoing, 2=dismiss)
  //   bits  3-14  course index in the current schedule (0..4095)
  //   bits 15-19  week   (1..20, stored 0-based)
  //
  // Keyed on a per-session course *index* rather than on the course ID
  // because course IDs are opaque strings: mapping them into 12 bits would
  // require a hash (collisions again) or a persisted registry. An index is
  // exact. IDs stay stable for a given schedule within a session, which is
  // all the notification layer needs.
  static const _kindReminder = 0;
  static const _kindOngoing = 1;
  static const _kindDismiss = 2;

  static const _kindMask = 0x7;
  static const _courseIndexShift = 3;
  static const _courseIndexBits = 12;
  static const _courseIndexMask = (1 << _courseIndexBits) - 1;
  static const _weekShift = 15;
  static const _weekMask = 0x1F;

  /// Lowest generated ID. Keeps every ID far away from the foreground
  /// service's fixed notification ID (9000) and other libraries' IDs.
  /// All packed IDs stay below 0x21000000, well inside signed int32.
  static const notificationIdBase = 0x20000000;

  static int _packId({
    required int kind,
    required int week,
    required int courseIndex,
  }) {
    assert(kind >= 0 && kind <= 2, 'notification kind out of range: $kind');
    assert(week >= 1 && week <= 20, 'week out of range: $week');
    assert(courseIndex >= 0 && courseIndex <= _courseIndexMask,
        'course index out of range: $courseIndex');
    final w = week.clamp(1, 20) - 1;
    final ci = courseIndex.clamp(0, _courseIndexMask);
    return notificationIdBase |
        (w << _weekShift) |
        (ci << _courseIndexShift) |
        kind;
  }

  static int _reminderId(int courseIndex, int week) =>
      _packId(kind: _kindReminder, week: week, courseIndex: courseIndex);

  static int _ongoingId(int courseIndex, int week) =>
      _packId(kind: _kindOngoing, week: week, courseIndex: courseIndex);

  /// The notification kind encoded in a packed ID.
  static int notificationKind(int id) => id & _kindMask;

  /// The week number (1..20) encoded in a packed ID.
  static int notificationWeek(int id) => ((id >> _weekShift) & _weekMask) + 1;

  /// The course index encoded in a packed ID.
  static int notificationCourseIndex(int id) =>
      (id >> _courseIndexShift) & _courseIndexMask;

  /// The native layer's expected `type` string for a packed ID.
  static String _nativeType(int id) {
    switch (id & _kindMask) {
      case _kindReminder:
        return 'reminder';
      case _kindDismiss:
        return 'dismiss';
      default:
        return 'ongoing';
    }
  }

  // ─── Test seams ───
  // Exposed so the collision/uniqueness contract can be verified against the
  // real formula instead of a copy of it in the test file.

  @visibleForTesting
  static int debugReminderId(int courseIndex, int week) =>
      _reminderId(courseIndex, week);

  @visibleForTesting
  static int debugOngoingId(int courseIndex, int week) =>
      _ongoingId(courseIndex, week);

  /// State key — one entry per course (not per week): only the current week's
  /// occurrence of a course is ever notified, so the week is not part of the
  /// identity.
  static String _stateKey(String courseId) => courseId;

  static String _body(
      String name, String timeStr, String location, String suffix) {
    final parts = [name, timeStr];
    if (location.isNotEmpty) parts.add(location);
    if (suffix.isNotEmpty) parts.add(suffix);
    return parts.join(' · ');
  }

  // ─── Polling ───

  static Future<void> _startPolling() async {
    _pollTimer?.cancel();

    // Start foreground service first so it anchors the notification bar,
    // then course notifications stack on top.
    if (!_serviceStarted) {
      _serviceStarted = true;
      await ForegroundServiceManager.start();
      // Give Android time to spin up the Service and post its notification
      // before we fire course notifications via fireImmediate.
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _checkSchedule();

    // Align the periodic timer to wall-clock :00 and :30 seconds
    // so reminders fire at precise times (±0.2s) rather than up to 30s late.
    final now = DateTime.now();
    final offset = now.second % 30;
    final msToBoundary = (30 - offset) * 1000 - now.millisecond;
    final delay = msToBoundary > 0 ? msToBoundary : 30000;

    _pollTimer = Timer(Duration(milliseconds: delay), () {
      _checkSchedule();
      _pollTimer = Timer.periodic(_pollInterval, (_) => _checkSchedule());
    });
  }

  static void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_serviceStarted) {
      _serviceStarted = false;
      ForegroundServiceManager.stop();
    }
  }

  static void _checkSchedule() {
    if (_firstDay == null || _courses.isEmpty) return;

    final now = DateTime.now();
    final semesterMonday =
        _firstDay!.subtract(Duration(days: _firstDay!.weekday - 1));

    // Only the occurrence that is happening right now matters.
    //
    // The previous code looped over every week in [startWeek, endWeek] and
    // compared `now` against each week's reminder time. For a course spanning
    // weeks 1-20, every *future* week's reminder timestamp is in the past, so
    // `now.isAfter(reminderDt)` was true for weeks 5, 6, ... as well — firing
    // a reminder a week early that the correct occurrence then overwrote.
    final currentWeek = StorageService.calculateWeekNumber(_firstDay!);
    final today = DateTime(now.year, now.month, now.day);

    for (int courseIndex = 0; courseIndex < _courses.length; courseIndex++) {
      final course = _courses[courseIndex];
      final key = _stateKey(course.id);
      final currentState = _activeNotification[key];
      final oId = _ongoingId(courseIndex, currentWeek);

      final slot = TimeSlot.forPeriod(course.startPeriod);

      // Resolve this course's date in the current week and require it to be
      // today. 0 = Sunday .. 6 = Saturday (matches Course.dayOfWeek).
      final dayOffset = course.dayOfWeek == 0 ? 6 : course.dayOfWeek - 1;
      final courseDate = semesterMonday
          .add(Duration(days: (currentWeek - 1) * 7 + dayOffset));

      final occursToday = slot != null && courseDate.isAtSameMomentAs(today);

      if (!occursToday) {
        // Not today → drop any stale state for this course.
        // (Nothing is posted for it, so there is nothing to cancel.)
        _activeNotification.remove(key);
        continue;
      }

      final startMin = slot.startMinuteOfDay;
      final endMin = slot.endMinuteOfDay;
      final reminderMin = startMin - _advanceMinutes;

      final reminderDt = DateTime(
          today.year, today.month, today.day, reminderMin ~/ 60, reminderMin % 60);
      final startDt = DateTime(
          today.year, today.month, today.day, startMin ~/ 60, startMin % 60);
      final endDt =
          DateTime(today.year, today.month, today.day, endMin ~/ 60, endMin % 60);

      if (!now.isBefore(endDt)) {
        // Class finished — remove the card entirely.
        if (currentState != null) {
          NativeAlarmService.cancelNotification(oId);
          _activeNotification.remove(key);
        }
      } else if (!now.isBefore(startDt)) {
        // In class — the ongoing banner replaces the reminder in place,
        // because both are posted under the same notifyId [oId].
        if (currentState != 'ongoing') {
          _fireNotification(
            id: oId,
            notifyId: oId,
            title: '正在上课',
            body: _body(course.name, slot.startTime, course.location, ''),
            durationText: '${slot.startTime}~${slot.endTime}',
          );
          _activeNotification[key] = 'ongoing';
        }
      } else if (!now.isBefore(reminderDt)) {
        // Before class — reminder.
        //
        // notifyId MUST be [oId], not the reminder's own [_reminderId]. The two
        // share one notification slot on purpose:
        //   - starting class overwrites the reminder instead of stacking a
        //     second notification beside it, and
        //   - the "class finished" branch above cancels that same [oId], which
        //     is the only thing that ever removes the reminder.
        // Posting it under a different id orphans the reminder in the shade
        // forever, because nothing else knows that id.
        if (currentState != 'reminder') {
          _fireNotification(
            id: _reminderId(courseIndex, currentWeek),
            notifyId: oId,
            title: '课程提醒',
            body: _body(course.name, slot.startTime, course.location, '即将上课'),
          );
          _activeNotification[key] = 'reminder';
        }
      } else {
        // Too early — nothing to show yet.
        _activeNotification.remove(key);
      }
    }
  }

  static Future<void> _fireNotification({
    required int id,
    required int notifyId,
    required String title,
    required String body,
    String durationText = '',
  }) async {
    await NativeAlarmService.fireImmediate(
      id: id,
      notifyId: notifyId,
      title: title,
      body: body,
      type: _nativeType(id),
      durationText: durationText,
    );
  }

  // ─── Boot recovery ───

  static Future<void> _rescheduleIfNeeded() async {
    final courses = await StorageService.getAllCourses();
    if (courses.isNotEmpty) await scheduleAll(courses);
  }
}
