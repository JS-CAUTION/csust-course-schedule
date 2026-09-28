import 'database_service.dart';
import '../models/course.dart';

/// What a course is doing at the instant the status is computed.
enum CoursePhase {
  /// The clock has not reached the session's start yet.
  before,

  /// The clock is inside the session (start inclusive, end exclusive).
  ongoing,

  /// The session has already ended.
  finished,
}

/// One of today's courses, resolved against the clock.
class TodayCourse {
  const TodayCourse({
    required this.course,
    required this.slot,
    required this.phase,
  });

  final Course course;
  final TimeSlot slot;
  final CoursePhase phase;

  /// Clock time the session starts, e.g. `8:00`.
  String get startTime => slot.startTime;

  /// `name`, then the location when the course has one.
  ///
  /// The order is deliberate: it survives Android eliding the tail of a
  /// collapsed notification, so the course identity is never the part that
  /// gets cut.
  String get label =>
      course.location.isEmpty ? course.name : '${course.name} · ${course.location}';
}

/// The rendered foreground-service notification text.
///
/// [body] is what the native side puts in `setContentText`. [known] is false
/// when the schedule cannot be computed at all (no semester first day, or no
/// courses) and the text therefore falls back to a neutral label rather than
/// asserting a fact about today.
class ForegroundStatus {
  const ForegroundStatus({required this.body, required this.known});

  final String body;
  final bool known;

  @override
  String toString() =>
      'ForegroundStatus(body: $body, known: $known)';
}

/// Shown when the schedule is unknown, and as the native service's default.
const String kForegroundFallbackBody = '流转';

/// How long before a session starts the text switches from the resting
/// "下节课 …" wording to the leading "… 上课" wording.
///
/// This used to be a user setting ("提醒提前量"). It was retired because it no
/// longer scheduled anything — the reminder notification it once controlled is
/// gone, and the status notification is always present — so all it did was pick
/// when one wording replaced another. Hard-coded at the old default so the
/// pre-class window keeps working without a knob nobody needs to turn.
const Duration kPreClassWindow = Duration(minutes: 15);

/// Courses that actually happen on [now]'s date, in the current week, ordered
/// by start time.
///
/// The week gate ([Course.isActiveInWeek]) is an invariant of this predicate,
/// not an optimisation. Commit bb6b3b9 dropped the equivalent gate from the
/// notification path and made an off-week course notify alongside the on-week
/// course sharing its time slot. Every "does this course happen today" decision
/// must route through here so that gate only ever has one home.
List<TodayCourse> coursesForToday({
  required List<Course> courses,
  required DateTime firstDay,
  required DateTime now,
}) {
  final week = StorageService.calculateWeekNumber(firstDay, now);
  final today = DateTime(now.year, now.month, now.day);
  final nowMinute = now.hour * 60 + now.minute;

  final result = <TodayCourse>[];
  for (final course in courses) {
    if (!occursOn(
      course: course,
      firstDay: firstDay,
      week: week,
      date: today,
    )) {
      continue;
    }

    // The slot must be looked up by startPeriod, never by endPeriod:
    // TimeSlot.slots only defines the five slot-leading periods (1, 3, 5, 7, 9)
    // while a real course stores e.g. startPeriod 1 / endPeriod 2, so
    // forPeriod(endPeriod) returns null for every real course.
    final slot = TimeSlot.forPeriod(course.startPeriod);
    if (slot == null) continue;

    final phase = nowMinute < slot.startMinuteOfDay
        ? CoursePhase.before
        : (nowMinute < slot.endMinuteOfDay
            ? CoursePhase.ongoing
            : CoursePhase.finished);

    result.add(TodayCourse(course: course, slot: slot, phase: phase));
  }

  result.sort((a, b) => a.slot.startMinuteOfDay.compareTo(b.slot.startMinuteOfDay));
  return result;
}

/// Whether [course] runs on [date], given that [date] falls in [week].
///
/// Pure and injectable so both the notification path and the status builder
/// share one week gate.
bool occursOn({
  required Course course,
  required DateTime firstDay,
  required int week,
  required DateTime date,
}) {
  if (!course.isActiveInWeek(week)) return false;
  if (TimeSlot.forPeriod(course.startPeriod) == null) return false;

  // semesterMonday is derived from firstDay's own weekday, so calendar days
  // before the semester starts fall in week 0 and are rejected by the gate
  // above rather than producing a negative offset.
  final semesterMonday =
      firstDay.subtract(Duration(days: firstDay.weekday - 1));
  // 0 = Sunday .. 6 = Saturday, matching Course.dayOfWeek.
  final dayOffset = course.dayOfWeek == 0 ? 6 : course.dayOfWeek - 1;
  final courseDate =
      semesterMonday.add(Duration(days: (week - 1) * 7 + dayOffset));

  return courseDate.isAtSameMomentAs(DateTime(date.year, date.month, date.day));
}

/// Builds the foreground notification text for the state of [now].
///
/// Pure, so every branch is deterministically testable by injecting a clock.
ForegroundStatus buildForegroundStatus({
  required List<Course> courses,
  required DateTime? firstDay,
  required DateTime now,
}) {
  if (firstDay == null || courses.isEmpty) {
    // Nothing can be asserted about today, so stay neutral.
    return const ForegroundStatus(body: kForegroundFallbackBody, known: false);
  }

  final todays = coursesForToday(courses: courses, firstDay: firstDay, now: now);
  final remaining = todays.where((c) => c.phase != CoursePhase.finished).toList();

  if (remaining.isEmpty) {
    // Two different statements, so they get two different sentences: "done for
    // today" is not the same news as "there was never anything today".
    final body =
        todays.isEmpty ? '今日无课• ᴗ •̥' : '今日课程已结束( ノ^ω^)ノ゚';
    return ForegroundStatus(body: body, known: true);
  }

  TodayCourse? current;
  for (final c in remaining) {
    if (c.phase == CoursePhase.ongoing) {
      current = c;
      break;
    }
  }
  final count = remaining.length;

  if (current != null) {
    // In class: the location and clock time were already shown by the "next
    // class" state that led here, and the student is already in the room.
    final body = '正在上 ${current.course.name} · 今日还剩 $count 节';
    return ForegroundStatus(body: body, known: true);
  }

  final next = remaining.first;
  final startsSoon =
      _minutesUntil(next.slot.startMinuteOfDay, now) <= kPreClassWindow.inMinutes;

  // The pre-class wording leads with the course name and the word 上课 instead
  // of "下节课", so the one state that has to compete for attention is
  // structurally different from the resting state rather than a small edit.
  final body = startsSoon
      ? '${next.course.name} ${next.startTime} 上课'
          '${_locationSuffix(next)} · 今日还剩 $count 节'
      : '下节课 ${next.startTime} ${next.label} · 今日还剩 $count 节';
  return ForegroundStatus(body: body, known: true);
}

String _locationSuffix(TodayCourse c) =>
    c.course.location.isEmpty ? '' : ' · ${c.course.location}';

int _minutesUntil(int startMinuteOfDay, DateTime now) =>
    startMinuteOfDay - (now.hour * 60 + now.minute);
