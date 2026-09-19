import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/models/course.dart';

/// Regression tests for the schedule grid's "in class" pulse effect.
///
/// The reported bug: while a class was in progress, using the header arrows to
/// switch to another week left the effect running on whatever card occupied the
/// same grid position. The old check compared only weekday and time slot — both
/// week-independent — so any card in that slot passed.
void main() {
  // Date constants. Kept explicit so the weekday a test intends is readable,
  // and self-checked below rather than trusted.
  const kSunday = 0, kMonday = 1;

  /// 2026-09-14. `DateTime.weekday` is 1=Mon..7=Sun, so the Sunday of that
  /// week is the 13th; `weekday % 7` therefore gives 0=Sun..6=Sat, matching
  /// `Course.dayOfWeek`.
  final baseMonday = DateTime(2026, 9, 14);

  setUpAll(() {
    // Guard: if this fails the calendar constants below are wrong, not the code.
    expect(baseMonday.weekday, DateTime.monday);
    expect(DateTime(2026, 9, 13).weekday, DateTime.sunday);
  });

  Course course({
    int dayOfWeek = kMonday,
    int startPeriod = 1,
    int endPeriod = 2,
    int startWeek = 1,
    int endWeek = 20,
    WeekMode mode = WeekMode.all,
    List<int> customWeeks = const [],
    String name = '高等数学',
  }) {
    return Course(
      id: 'c1',
      name: name,
      teacher: '',
      location: '',
      dayOfWeek: dayOfWeek,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      startWeek: startWeek,
      endWeek: endWeek,
      weekMode: mode,
      customWeeks: customWeeks,
    );
  }

  /// Monday 2026-09-14 at the given time.
  DateTime monAt(int hour, int minute) =>
      DateTime(2026, 9, 14, hour, minute);

  group('shouldPulseInGrid — week gate (the reported bug)', () {
    final c = course(); // every week, Monday, periods 1-2 (8:00-9:40)

    test('pulses while viewing the current week during the session', () {
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(8, 30)),
        isTrue,
      );
    });

    test('does NOT pulse on any other week, same weekday and same clock time',
        () {
      // This is the exact failure: week 5's card sits in the same grid position
      // and matched the old weekday+slot check.
      for (final other in const [1, 3, 5, 6, 19, 20]) {
        expect(
          c.shouldPulseInGrid(
              displayedWeek: other, currentWeek: 4, now: monAt(8, 30)),
          isFalse,
          reason: 'week $other must not pulse while the current week is 4',
        );
      }
    });

    test('the old week-blind check would have pulsed on every one of those', () {
      // Documents why the bug existed: isOngoingAt alone ignores the week.
      for (final other in const [1, 5, 20]) {
        expect(c.isOngoingAt(monAt(8, 30)), isTrue,
            reason: 'isOngoingAt is week-independent by design');
        expect(
          c.shouldPulseInGrid(
              displayedWeek: other, currentWeek: 4, now: monAt(8, 30)),
          isFalse,
        );
      }
    });

    test('pulses again after navigating back to the current week', () {
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 5, currentWeek: 4, now: monAt(8, 30)),
        isFalse,
      );
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(8, 30)),
        isTrue,
      );
    });
  });

  group('shouldPulseInGrid — session time window', () {
    final c = course();

    test('not before the session starts', () {
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(7, 45)),
        isFalse,
      );
    });

    test('start is inclusive', () {
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(8, 0)),
        isTrue,
      );
    });

    test('still pulsing one minute before the end', () {
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(9, 39)),
        isTrue,
      );
    });

    test('end is exclusive', () {
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(9, 40)),
        isFalse,
      );
    });

    test('afternoon slot: periods 5-6 run 14:00-15:40', () {
      final pm = course(startPeriod: 5, endPeriod: 6);
      expect(
        pm.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(14, 30)),
        isTrue,
      );
      expect(
        pm.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(15, 40)),
        isFalse,
      );
    });

    test('evening slot: periods 9-10 run 19:30-21:10', () {
      final eve = course(startPeriod: 9, endPeriod: 10);
      expect(
        eve.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(20, 0)),
        isTrue,
      );
    });
  });

  group('shouldPulseInGrid — weekday', () {
    final c = course(dayOfWeek: kMonday);

    test('Monday course pulses on Monday', () {
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: monAt(8, 30)),
        isTrue,
      );
    });

    test('does NOT pulse on another weekday', () {
      // Tuesday of the same week: same week number, same clock time, and the
      // old check would still have matched on slot alone.
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: DateTime(2026, 9, 15, 8, 30)),
        isFalse,
      );
    });

    test('Sunday course pulses on Sunday (0 vs weekday%7)', () {
      final sundayCourse = course(dayOfWeek: kSunday);
      expect(
        sundayCourse.shouldPulseInGrid(
            displayedWeek: 4, currentWeek: 4, now: DateTime(2026, 9, 13, 8, 30)),
        isTrue,
      );
    });
  });

  group('shouldPulseInGrid — single/double/custom weeks', () {
    test('odd-week course does not pulse in an even week', () {
      final c = course(mode: WeekMode.odd);
      // Current week 6 is even: the course does not run at all, so even though
      // the grid shows the current week, nothing should pulse.
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 6, currentWeek: 6, now: monAt(8, 30)),
        isFalse,
      );
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 5, currentWeek: 5, now: monAt(8, 30)),
        isTrue,
      );
    });

    test('even-week course does not pulse in an odd week', () {
      final c = course(mode: WeekMode.even);
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 5, currentWeek: 5, now: monAt(8, 30)),
        isFalse,
      );
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 8, currentWeek: 8, now: monAt(8, 30)),
        isTrue,
      );
    });

    test('custom-week course only pulses on a listed week', () {
      final c = course(mode: WeekMode.custom, customWeeks: const [3, 7, 11]);
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 7, currentWeek: 7, now: monAt(8, 30)),
        isTrue,
      );
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 5, currentWeek: 5, now: monAt(8, 30)),
        isFalse,
      );
    });

    test('course outside its week range does not pulse', () {
      final c = course(startWeek: 1, endWeek: 8);
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 9, currentWeek: 9, now: monAt(8, 30)),
        isFalse,
      );
      expect(
        c.shouldPulseInGrid(
            displayedWeek: 8, currentWeek: 8, now: monAt(8, 30)),
        isTrue,
      );
    });
  });

  group('isOngoingAt — period handling', () {
    test('a 大节 is stored as start/end pair, both derived from the start slot',
        () {
      // Real courses come from the parser as (1,2), (3,4), ... (9,10). The end
      // period is never a slot-leading period, so the end time must come from
      // the start period's slot — looking up endPeriod returns null.
      expect(TimeSlot.forPeriod(1), isNotNull);
      expect(TimeSlot.forPeriod(2), isNull,
          reason: 'only slot-leading periods exist in TimeSlot.slots');

      final firstPeriod = course(startPeriod: 1, endPeriod: 2);
      expect(firstPeriod.isOngoingAt(monAt(8, 0)), isTrue);
      expect(firstPeriod.isOngoingAt(monAt(9, 39)), isTrue);
      expect(firstPeriod.isOngoingAt(monAt(9, 40)), isFalse);

      final thirdPeriod = course(startPeriod: 3, endPeriod: 4);
      expect(thirdPeriod.isOngoingAt(monAt(10, 10)), isTrue);
      expect(thirdPeriod.isOngoingAt(monAt(11, 50)), isFalse);
    });

    test('degenerate start == end still resolves via the start slot', () {
      final c = course(startPeriod: 5, endPeriod: 5);
      expect(c.isOngoingAt(monAt(14, 0)), isTrue);
      expect(c.isOngoingAt(monAt(15, 40)), isFalse);
    });

    test('a period with no slot does not throw and never pulses', () {
      for (final p in const [0, 2, 4, 11, 99]) {
        final c = course(startPeriod: p, endPeriod: p);
        expect(c.isOngoingAt(monAt(8, 30)), isFalse, reason: 'period $p');
        expect(
          c.shouldPulseInGrid(
              displayedWeek: 4, currentWeek: 4, now: monAt(8, 30)),
          isFalse,
          reason: 'period $p',
        );
      }
    });
  });
}
