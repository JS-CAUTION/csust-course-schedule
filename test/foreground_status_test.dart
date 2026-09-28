import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/models/course.dart';
import 'package:course_schedule_app/services/foreground_status.dart';

/// Tests for the foreground notification text.
///
/// This is now the app's ONLY reminder surface: the pre-class reminder
/// notification was retired, so the text must change at the right instant or
/// the user is not reminded at all. Everything here injects a clock — the
/// builder never reads the wall clock itself.
void main() {
  // Monday 2026-03-02, the semester's first day. Week N's Monday is
  // firstDay + (N-1)*7 days.
  final firstDay = DateTime(2026, 3, 2);
  DateTime mondayOfWeek(int week) =>
      firstDay.add(Duration(days: (week - 1) * 7));
  DateTime at(int week, int hour, int minute) {
    final d = mondayOfWeek(week);
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  /// Period 1 (08:00–09:40) Monday course.
  Course math({
    String id = 'math',
    String location = '综合楼A301',
    int startWeek = 1,
    int endWeek = 20,
    WeekMode mode = WeekMode.all,
    List<int> customWeeks = const [],
    int dayOfWeek = 1,
    int startPeriod = 1,
  }) {
    return Course(
      id: id,
      name: id,
      teacher: '',
      location: location,
      dayOfWeek: dayOfWeek,
      startPeriod: startPeriod,
      endPeriod: startPeriod + 1,
      startWeek: startWeek,
      endWeek: endWeek,
      weekMode: mode,
      customWeeks: customWeeks,
    );
  }

  Course named(String name, {String location = '', int startPeriod = 3}) => Course(
        id: name,
        name: name,
        teacher: '',
        location: location,
        dayOfWeek: 1,
        startPeriod: startPeriod,
        endPeriod: startPeriod + 1,
        startWeek: 1,
        endWeek: 20,
      );

  /// A Monday timetable: 08:00 高等数学 / 10:10 大学英语 / 14:00 物理.
  List<Course> threeCourses() => [
        named('高等数学', location: '综合楼A301', startPeriod: 1),
        named('大学英语', location: '外语楼B204', startPeriod: 3),
        named('物理', location: '综合楼C101', startPeriod: 5),
      ];

  String bodyAt(DateTime now, {List<Course>? courses}) {
    return buildForegroundStatus(
      courses: courses ?? threeCourses(),
      firstDay: firstDay,
      now: now,
    ).body;
  }

  group('resting state — next class plus remaining count', () {
    test('before the first class of the day', () {
      // 07:44 is outside the default 15-minute window (which opens at 07:45).
      expect(bodyAt(at(1, 7, 44)),
          '下节课 8:00 高等数学 · 综合楼A301 · 今日还剩 3 节');
    });

    test('between the first and second class', () {
      expect(bodyAt(at(1, 9, 40)),
          '下节课 10:10 大学英语 · 外语楼B204 · 今日还剩 2 节');
    });

    test('between the second and third class', () {
      expect(bodyAt(at(1, 11, 50)),
          '下节课 14:00 物理 · 综合楼C101 · 今日还剩 1 节');
    });

    test('the location segment is omitted when the course has none', () {
      final courses = [named('高等数学', startPeriod: 1)];
      expect(bodyAt(at(1, 7, 44), courses: courses),
          '下节课 8:00 高等数学 · 今日还剩 1 节');
    });
  });

  group('in class', () {
    test('shows the course being taken and counts it as remaining', () {
      // 08:00–09:40 session; at 08:00 it is ongoing and NOT yet finished, so it
      // counts: "还剩 3 节" turning into "还剩 2 节" only at 09:40.
      expect(bodyAt(at(1, 8, 0)), '正在上 高等数学 · 今日还剩 3 节');
      expect(bodyAt(at(1, 8, 30)), '正在上 高等数学 · 今日还剩 3 节');
      expect(bodyAt(at(1, 9, 39)), '正在上 高等数学 · 今日还剩 3 节');
    });

    test('the session end is exclusive — 09:40 is already finished', () {
      expect(bodyAt(at(1, 9, 40)), startsWith('下节课'));
    });

    test('the location is not repeated while in class', () {
      expect(bodyAt(at(1, 8, 30)), isNot(contains('综合楼')));
    });
  });

  group('pre-class window', () {
    test('leads with the course name and 上课, not 下节课', () {
      expect(bodyAt(at(1, 9, 55)),
          '大学英语 10:10 上课 · 外语楼B204 · 今日还剩 2 节');
    });

    test('the window opens exactly kPreClassWindow before the start', () {
      // 08:00 start, 15-minute window → opens at 07:45. The window length is a
      // constant now that the "提醒提前量" setting was retired; this pins the
      // boundary so it cannot silently drift.
      expect(kPreClassWindow, const Duration(minutes: 15));
      expect(bodyAt(at(1, 7, 44)), startsWith('下节课'));
      expect(bodyAt(at(1, 7, 45)), contains('上课'));
    });

    test('the pre-class wording differs structurally from the resting one', () {
      final resting = bodyAt(at(1, 9, 40));
      final soon = bodyAt(at(1, 9, 55));
      expect(resting, isNot(equals(soon)));
      expect(resting, startsWith('下节课'));
      expect(soon, startsWith('大学英语'));
    });
  });

  group('nothing left today', () {
    test('all classes finished', () {
      expect(bodyAt(at(1, 15, 40)), '今日课程已结束( ノ^ω^)ノ゚');
      expect(bodyAt(at(1, 23, 0)), '今日课程已结束( ノ^ω^)ノ゚');
    });

    test('a day that never had classes says so differently', () {
      // Saturday of week 1 with a Monday-only timetable.
      final saturday = mondayOfWeek(1).add(const Duration(days: 5));
      expect(bodyAt(DateTime(saturday.year, saturday.month, saturday.day, 9, 30)),
          '今日无课• ᴗ •̥');
    });
  });

  group('week gate — only the current week counts', () {
    test('an odd-week course is absent in an even week', () {
      final odd = math(id: '奇数周课', mode: WeekMode.odd);
      expect(bodyAt(at(2, 7, 46), courses: [odd]), '今日无课• ᴗ •̥');
      expect(bodyAt(at(1, 7, 46), courses: [odd]), contains('奇数周课'));
    });

    test('two courses in one slot on different weeks do not both count', () {
      // Regression guard: the notification path once dropped its week gate and
      // fired for BOTH of these. Sharing a time slot must not make the off-week
      // course visible. 07:50 is inside the pre-class window for an 08:00 start.
      final odd = math(id: '奇数周课', mode: WeekMode.odd);
      final even = math(id: '偶数周课', mode: WeekMode.even);

      expect(bodyAt(at(2, 7, 50), courses: [odd, even]),
          '偶数周课 8:00 上课 · 综合楼A301 · 今日还剩 1 节');
      expect(bodyAt(at(3, 7, 50), courses: [odd, even]),
          '奇数周课 8:00 上课 · 综合楼A301 · 今日还剩 1 节');
    });

    test('a course outside its week range is absent', () {
      final early = math(id: '早课', startWeek: 1, endWeek: 4);
      expect(bodyAt(at(2, 7, 46), courses: [early]), contains('早课'));
      expect(bodyAt(at(6, 7, 46), courses: [early]), '今日无课• ᴗ •̥');
    });

    test('a custom-week course shows only in its listed weeks', () {
      final custom = math(id: '自定义课', mode: WeekMode.custom, customWeeks: const [1, 5, 9]);
      expect(bodyAt(at(1, 7, 46), courses: [custom]), contains('自定义课'));
      expect(bodyAt(at(2, 7, 46), courses: [custom]), '今日无课• ᴗ •̥');
      expect(bodyAt(at(5, 7, 46), courses: [custom]), contains('自定义课'));
    });

    test('a course on another weekday is not today', () {
      final tuesday = math(id: '周二课', dayOfWeek: 2);
      expect(bodyAt(at(1, 7, 46), courses: [tuesday]), '今日无课• ᴗ •̥');
    });

    test('days before the semester starts assert nothing', () {
      // Week 0 exists arithmetically but no course is active in it.
      final before = DateTime(2026, 2, 23, 9, 0);
      expect(bodyAt(before), '今日无课• ᴗ •̥');
    });
  });

  group('unknown schedule falls back instead of guessing', () {
    test('no semester first day', () {
      final s = buildForegroundStatus(
        courses: threeCourses(),
        firstDay: null,
        now: at(1, 7, 46),
      );
      expect(s.known, isFalse);
      expect(s.body, kForegroundFallbackBody);
    });

    test('empty course list', () {
      final s = buildForegroundStatus(
        courses: const [],
        firstDay: firstDay,
        now: at(1, 7, 46),
      );
      expect(s.known, isFalse);
      expect(s.body, kForegroundFallbackBody);
    });

    test('a known schedule reports known=true', () {
      final s = buildForegroundStatus(
        courses: threeCourses(),
        firstDay: firstDay,
        now: at(1, 7, 46),
      );
      expect(s.known, isTrue);
    });
  });

  group('ordering', () {
    test('courses are ordered by start time regardless of storage order', () {
      final shuffled = [
        named('物理', location: 'C101', startPeriod: 5),
        named('高等数学', location: 'A301', startPeriod: 1),
        named('大学英语', location: 'B204', startPeriod: 3),
      ];
      expect(bodyAt(at(1, 7, 44), courses: shuffled),
          '下节课 8:00 高等数学 · A301 · 今日还剩 3 节');
    });

    test('the soonest remaining class is the one shown', () {
      expect(bodyAt(at(1, 12, 0)), contains('物理'));
    });
  });

  group('determinism', () {
    test('the same instant always yields the same text', () {
      // Underpins the "only push when the text changed" debounce: a value that
      // drifted between identical calls would re-post the notification on every
      // 30-second poll.
      for (final now in [at(1, 7, 46), at(1, 8, 30), at(1, 9, 55), at(1, 16, 0)]) {
        expect(bodyAt(now), bodyAt(now));
      }
    });

    test('the text is stable across the whole minute it describes', () {
      expect(bodyAt(at(1, 7, 46)), bodyAt(at(1, 7, 46).add(const Duration(seconds: 30))));
    });
  });
}
