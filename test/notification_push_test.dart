import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/models/course.dart';
import 'package:course_schedule_app/services/notification_service.dart';

/// Tests for how often the status is actually pushed to the native service.
///
/// The status text is recomputed every 30 seconds, but the notification must
/// only be re-posted when the text really changed — otherwise the shade gets
/// touched every half minute for no visible difference.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serviceChannel = MethodChannel('com.example.course_schedule_app/service');

  final pushed = <String>[];

  setUp(() {
    pushed.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, (call) async {
      if (call.method == 'startForegroundService') {
        final args = call.arguments;
        final body = args is Map ? args['body'] as String? : null;
        if (body != null) pushed.add(body);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(serviceChannel, null);
  });

  final firstDay = DateTime(2026, 3, 2);

  Course math() => const Course(
        id: 'math',
        name: '高等数学',
        teacher: '',
        location: '综合楼A301',
        dayOfWeek: 1,
        startPeriod: 1,
        endPeriod: 2,
        startWeek: 1,
        endWeek: 20,
      );

  test('a pass at a new instant pushes the new text', () {
    final body = NotificationService.debugCheckSchedule(
      courses: [math()],
      firstDay: firstDay,
      now: DateTime(2026, 3, 2, 7, 44),
    );
    expect(body, '下节课 8:00 高等数学 · 综合楼A301 · 今日还剩 1 节');
  });

  test('the status is pushed exactly once per distinct text', () {
    final courses = [math()];

    expect(
      NotificationService.debugCheckSchedule(
        courses: courses,
        firstDay: firstDay,
        now: DateTime(2026, 3, 2, 7, 44),
      ),
      isNotNull,
    );
    // Second pass, same text: nothing new to send.
    final second = NotificationService.debugCheckSchedule(
      courses: courses,
      firstDay: firstDay,
      now: DateTime(2026, 3, 2, 7, 44),
      resetStatus: false,
    );
    expect(second, isNull,
        reason: 'identical text must not re-post the notification');
  });

  test('a boundary crossing produces a distinct text', () {
    final courses = [math()];

    final before = NotificationService.debugCheckSchedule(
      courses: courses,
      firstDay: firstDay,
      now: DateTime(2026, 3, 2, 7, 44),
    );
    final during = NotificationService.debugCheckSchedule(
      courses: courses,
      firstDay: firstDay,
      now: DateTime(2026, 3, 2, 8, 30),
      resetStatus: false,
    );

    expect(before, isNotNull);
    expect(during, isNotNull);
    expect(before, isNot(equals(during)));
    expect(during, '正在上 高等数学 · 今日还剩 1 节');
  });

  test('only changed text reaches the native channel', () {
    final courses = [math()];

    NotificationService.debugCheckSchedule(
      courses: courses,
      firstDay: firstDay,
      now: DateTime(2026, 3, 2, 7, 44),
    );
    NotificationService.debugCheckSchedule(
      courses: courses,
      firstDay: firstDay,
      now: DateTime(2026, 3, 2, 7, 44),
      resetStatus: false,
    );
    NotificationService.debugCheckSchedule(
      courses: courses,
      firstDay: firstDay,
      now: DateTime(2026, 3, 2, 8, 30),
      resetStatus: false,
    );
    expect(pushed, [
      '下节课 8:00 高等数学 · 综合楼A301 · 今日还剩 1 节',
      '正在上 高等数学 · 今日还剩 1 节',
    ]);
  });

  test('an empty schedule still refreshes the status', () {
    // The status refresh must not sit behind the "nothing to do" guard, or a
    // user with no courses would keep whatever text the notification last had.
    expect(
      NotificationService.debugCheckSchedule(
        courses: const [],
        firstDay: firstDay,
        now: DateTime(2026, 3, 2, 9, 0),
      ),
      isNotNull,
    );
  });
}
