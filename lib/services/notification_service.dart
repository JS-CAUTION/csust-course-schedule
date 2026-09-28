import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../services/database_service.dart';
import '../services/foreground_service_manager.dart';
import '../services/foreground_status.dart';

/// Keeps the foreground service's notification showing what today looks like.
///
/// A Dart Timer fires every 30 seconds, recomputes the status text and — only
/// when the text actually changed — pushes it to the native foreground
/// service. A persistent Foreground Service keeps this isolate alive while the
/// app is in the background on aggressive OEM firmware (vivo, Oppo, Xiaomi).
///
/// There are no longer any per-course notifications. The pre-class reminder and
/// the in-class "正在上课" banner were both retired once the always-present
/// service notification could carry the same information; see DEV_STATE.md.
/// Retiring them also retired the packed notification IDs and the
/// reminder/ongoing slot-sharing invariant they existed to support — the
/// service notification (native id 9000) is now the only course notification,
/// and it is updated in place rather than posted per occurrence.
///
/// Freshness contract: the text only changes at session boundaries (roughly
/// 6–10 times a day), so a 30-second poll is far finer than needed. Because the
/// timer keeps running while the app is backgrounded, the text tracks time
/// changes without any extra scheduling mechanism.
class NotificationService {
  static const _pollInterval = Duration(seconds: 30);

  static bool _serviceStarted = false;
  static Timer? _pollTimer;
  static List<Course> _courses = [];
  static DateTime? _firstDay;

  /// Last text pushed to the native side. Guards against re-posting an
  /// identical notification every 30 seconds.
  static String? _lastStatusBody;

  // ─── Init ───

  static Future<void> init() async {
    await _rescheduleIfNeeded();
  }

  // ─── Public API ───

  static Future<void> scheduleAll(List<Course> courses) async {
    _courses = courses;
    _firstDay = await StorageService.getSemesterFirstDay();
    await _startPolling();
  }

  static Future<void> cancelAll() async {
    _stopPolling();
    _lastStatusBody = null;
  }

  // ─── Test seams ───

  /// Runs one scheduling pass at an injected instant and returns the text that
  /// was pushed to the native side, or null when nothing changed.
  ///
  /// Drives the real pass rather than a copy of its logic: the status is only
  /// correct if the week gate, the boundary arithmetic and the "only push on
  /// change" rule all hold together.
  ///
  /// Set [resetStatus] to false to keep the previous text, which is how the
  /// de-duplication rule is observed across two passes.
  ///
  /// Returns null when the pass produced no change, i.e. when nothing was sent
  /// to the native side.
  @visibleForTesting
  static String? debugCheckSchedule({
    required List<Course> courses,
    required DateTime firstDay,
    required DateTime now,
    bool resetStatus = true,
  }) {
    _lastStatusBody = resetStatus ? null : _lastStatusBody;
    final before = _lastStatusBody;
    _courses = courses;
    _firstDay = firstDay;
    _checkSchedule(now: now);
    return _lastStatusBody == before ? null : _lastStatusBody;
  }

  // ─── Polling ───

  static Future<void> _startPolling() async {
    _pollTimer?.cancel();

    // The service owns the notification, so it has to be up before the first
    // status can be shown.
    if (!_serviceStarted) {
      _serviceStarted = true;
      await ForegroundServiceManager.start();
      // Give Android time to spin up the Service before the first update.
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _checkSchedule();

    // Align the periodic timer to wall-clock :00 and :30 seconds so a boundary
    // lands within ~0.2s of the minute it belongs to.
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

  /// [now] is injectable so the status decision can be regression-tested
  /// deterministically; production callers omit it and get the wall clock.
  ///
  /// There is deliberately no early return here. The status must be recomputed
  /// even when the schedule is empty or the semester first day is unset — a
  /// guard would freeze the on-screen notification on whatever it last said.
  static void _checkSchedule({DateTime? now}) {
    now ??= DateTime.now();
    _refreshForegroundStatus(now);
  }

  static void _refreshForegroundStatus(DateTime now) {
    final status = buildForegroundStatus(
      courses: _courses,
      firstDay: _firstDay,
      now: now,
    );

    // Content equality is the debounce: the text carries a minute-resolution
    // clock time, so an unchanged string means there is nothing new to show.
    if (status.body == _lastStatusBody) return;
    _lastStatusBody = status.body;
    ForegroundServiceManager.updateStatus(status.body);
  }

  // ─── Boot recovery ───

  static Future<void> _rescheduleIfNeeded() async {
    final courses = await StorageService.getAllCourses();
    if (courses.isNotEmpty) await scheduleAll(courses);
  }
}
