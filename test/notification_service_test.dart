import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/models/course.dart';
import 'package:course_schedule_app/services/notification_service.dart';

void main() {
  // ── Notification ID uniqueness ──
  //
  // This group used to re-implement the ID formula locally and assert that a
  // handful of toy inputs ('abc', 'test') differed. That was a tautology: it
  // checked that Dart's String.hashCode separates three arbitrary strings, not
  // that the app's real ID space is collision-free. The production scheme is
  // now a packed bit layout, so uniqueness is a structural property — and
  // these tests pin that structure down.
  group('NotificationService ID uniqueness', () {
    test('IDs are unique across 200 courses × 20 weeks × 2 kinds', () {
      final seen = <int, String>{};
      for (int courseIndex = 0; courseIndex < 200; courseIndex++) {
        for (int week = 1; week <= 20; week++) {
          for (final kind in const ['reminder', 'ongoing']) {
            final id = kind == 'reminder'
                ? NotificationService.debugReminderId(courseIndex, week)
                : NotificationService.debugOngoingId(courseIndex, week);
            final label = 'course=$courseIndex week=$week kind=$kind';
            final previous = seen[id];
            expect(previous, isNull,
                reason: 'ID collision: $label collides with $previous '
                    '(both → $id)');
            seen[id] = label;
          }
        }
      }
      // Guard against the loop silently generating nothing.
      expect(seen.length, 200 * 20 * 2);
    });

    test('IDs are unique at the maximum supported course index and week', () {
      final a = NotificationService.debugReminderId(4095, 20);
      final b = NotificationService.debugOngoingId(4095, 20);
      final c = NotificationService.debugReminderId(4095, 19);
      final d = NotificationService.debugReminderId(4094, 20);
      expect({a, b, c, d}.length, 4, reason: 'max-range IDs must not collide');
    });

    test('IDs are deterministic — same inputs give the same ID', () {
      // Determinism matters because a notification posted before an app
      // restart must be cancellable after it. (The old hashCode scheme was
      // NOT deterministic across processes: Dart seeds string hashes.)
      for (int courseIndex = 0; courseIndex < 50; courseIndex++) {
        for (int week = 1; week <= 20; week++) {
          expect(
            NotificationService.debugOngoingId(courseIndex, week),
            NotificationService.debugOngoingId(courseIndex, week),
          );
        }
      }
    });

    test('kind and week round-trip through the packed layout', () {
      for (final courseIndex in const [0, 1, 17, 255, 4095]) {
        for (final week in const [1, 2, 9, 20]) {
          final reminder =
              NotificationService.debugReminderId(courseIndex, week);
          final ongoing = NotificationService.debugOngoingId(courseIndex, week);

          expect(NotificationService.notificationWeek(reminder), week);
          expect(NotificationService.notificationWeek(ongoing), week);
          expect(NotificationService.notificationCourseIndex(reminder),
              courseIndex);
          expect(NotificationService.notificationCourseIndex(ongoing),
              courseIndex);
          expect(NotificationService.notificationKind(reminder), 0);
          expect(NotificationService.notificationKind(ongoing), 1);
        }
      }
    });

    test('course index and week bit ranges do not overlap', () {
      // The structural guarantee behind the uniqueness test: packId places
      // week strictly above courseIndex, so no (course, week) pair can alias.
      // 12 bits of course index, then 5 bits of week starting at bit 15.
      final maxIndexOnly = NotificationService.debugReminderId(4095, 1);
      final minIndexNextWeek = NotificationService.debugReminderId(0, 2);
      expect(minIndexNextWeek, greaterThan(maxIndexOnly),
          reason: 'week-2 index-0 must sort above week-1 index-4095');
    });

    test('all IDs are positive, non-zero and inside signed int32', () {
      for (int courseIndex = 0; courseIndex < 200; courseIndex++) {
        for (int week = 1; week <= 20; week++) {
          for (final id in [
            NotificationService.debugReminderId(courseIndex, week),
            NotificationService.debugOngoingId(courseIndex, week),
          ]) {
            expect(id, greaterThan(0));
            expect(id, lessThan(0x7FFFFFFF),
                reason: 'Android notification IDs are signed int32');
            // Must not collide with the foreground service's fixed ID.
            expect(id, isNot(equals(9000)));
          }
        }
      }
    });

    test('lowest generated ID clears other notification-ID neighbourhoods', () {
      final lowest = NotificationService.debugReminderId(0, 1);
      expect(lowest, greaterThanOrEqualTo(NotificationService.notificationIdBase));
      expect(lowest, greaterThan(9000));
    });
  });

  group('TimeSlot — source of truth for notification times', () {
    test('period 1: 8:00–9:40', () {
      final s = TimeSlot.forPeriod(1)!;
      expect(s.startTime, '8:00');
      expect(s.endTime, '9:40');
      expect(s.startMinuteOfDay, 480);
      expect(s.endMinuteOfDay, 580);
    });

    test('period 3: 10:10–11:50', () {
      final s = TimeSlot.forPeriod(3)!;
      expect(s.startTime, '10:10');
      expect(s.endTime, '11:50');
      expect(s.startMinuteOfDay, 610);
      expect(s.endMinuteOfDay, 710);
    });

    test('period 5: 14:00–15:40', () {
      final s = TimeSlot.forPeriod(5)!;
      expect(s.startTime, '14:00');
      expect(s.endTime, '15:40');
      expect(s.startMinuteOfDay, 840);
      expect(s.endMinuteOfDay, 940);
    });

    test('period 7: 16:10–17:50', () {
      final s = TimeSlot.forPeriod(7)!;
      expect(s.startTime, '16:10');
      expect(s.endTime, '17:50');
      expect(s.startMinuteOfDay, 970);
      expect(s.endMinuteOfDay, 1070);
    });

    test('period 9: 19:30–21:10', () {
      final s = TimeSlot.forPeriod(9)!;
      expect(s.startTime, '19:30');
      expect(s.endTime, '21:10');
      expect(s.startMinuteOfDay, 1170);
      expect(s.endMinuteOfDay, 1270);
    });

    test('reminder time with default 15min advance: period 1 → 7:45', () {
      final startMin = TimeSlot.forPeriod(1)!.startMinuteOfDay;
      const advance = 15;
      final notifyMin = startMin - advance;
      expect(notifyMin ~/ 60, 7);
      expect(notifyMin % 60, 45);
    });

    test('reminder time with 10min advance: period 1 → 7:50', () {
      final startMin = TimeSlot.forPeriod(1)!.startMinuteOfDay;
      const advance = 10;
      final notifyMin = startMin - advance;
      expect(notifyMin ~/ 60, 7);
      expect(notifyMin % 60, 50);
    });

    test('reminder time with 30min advance: period 5 (14:00) → 13:30', () {
      final startMin = TimeSlot.forPeriod(5)!.startMinuteOfDay;
      const advance = 30;
      final notifyMin = startMin - advance;
      expect(notifyMin ~/ 60, 13);
      expect(notifyMin % 60, 30);
    });
  });

  group('Notification slot sharing — reminder and ongoing must share one slot', () {
    // Regression guard for a real breakage: the reminder was once posted under
    // its OWN notifyId instead of the ongoing one. Android then showed two
    // separate notifications, and since the "class finished" branch cancels
    // only the ongoing id, the reminder was orphaned in the shade forever —
    // it stopped disappearing.
    //
    // Both are posted with `notifyId: oId` in NotificationService._checkSchedule:
    //   - starting class overwrites the reminder in place, and
    //   - ending class cancels that same id, removing the reminder too.
    //
    // These tests pin the two halves of that invariant that are checkable here.
    test('the reminder carries a distinct packed id (kind 0)', () {
      for (final week in const [1, 5, 20]) {
        final r = NotificationService.debugReminderId(0, week);
        final o = NotificationService.debugOngoingId(0, week);
        expect(NotificationService.notificationKind(r), 0);
        expect(NotificationService.notificationKind(o), 1);
        expect(r, isNot(equals(o)));
      }
    });

    test('one course has exactly one ongoing slot per week, shared by both', () {
      // The notifyId actually passed to Android is `debugOngoingId` in BOTH the
      // reminder and the ongoing branch. Asserting it is stable and unique per
      // (course, week) is what makes "cancel at class end" reach the reminder.
      final seen = <int>{};
      for (int courseIndex = 0; courseIndex < 50; courseIndex++) {
        for (int week = 1; week <= 20; week++) {
          final oId = NotificationService.debugOngoingId(courseIndex, week);
          expect(seen.add(oId), isTrue,
              reason: 'ongoing slot must be unique per (course=$courseIndex, '
                  'week=$week) or a cancel would hit the wrong course');
        }
      }
    });

    test('the id round-trips back to its course index for cancellation', () {
      // The cancel path only has the packed id, so it must carry the index.
      for (final courseIndex in const [0, 7, 123, 4095]) {
        final oId = NotificationService.debugOngoingId(courseIndex, 9);
        expect(NotificationService.notificationCourseIndex(oId), courseIndex);
        expect(NotificationService.notificationWeek(oId), 9);
      }
    });
  });

  group('Course.isActiveInWeek — gates which weeks notify', () {
    Course course({
      int startWeek = 1,
      int endWeek = 20,
      WeekMode mode = WeekMode.all,
      List<int> customWeeks = const [],
    }) {
      return Course(
        id: 'c',
        name: '课',
        teacher: '',
        location: '',
        dayOfWeek: 1,
        startPeriod: 1,
        endPeriod: 2,
        startWeek: startWeek,
        endWeek: endWeek,
        weekMode: mode,
        customWeeks: customWeeks,
      );
    }

    test('all-weeks course is active across its range only', () {
      final c = course(startWeek: 3, endWeek: 6);
      expect(c.isActiveInWeek(2), isFalse);
      expect(c.isActiveInWeek(3), isTrue);
      expect(c.isActiveInWeek(6), isTrue);
      expect(c.isActiveInWeek(7), isFalse);
    });

    test('odd-week course skips even weeks', () {
      final c = course(mode: WeekMode.odd);
      expect(c.isActiveInWeek(1), isTrue);
      expect(c.isActiveInWeek(2), isFalse);
      expect(c.isActiveInWeek(3), isTrue);
    });

    test('even-week course skips odd weeks', () {
      final c = course(mode: WeekMode.even);
      expect(c.isActiveInWeek(1), isFalse);
      expect(c.isActiveInWeek(2), isTrue);
      expect(c.isActiveInWeek(4), isTrue);
    });

    test('custom-week course only matches listed weeks', () {
      final c = course(mode: WeekMode.custom, customWeeks: const [1, 5, 9]);
      expect(c.isActiveInWeek(1), isTrue);
      expect(c.isActiveInWeek(5), isTrue);
      expect(c.isActiveInWeek(2), isFalse);
    });
  });
}
