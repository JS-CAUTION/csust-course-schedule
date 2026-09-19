import 'package:flutter/services.dart';

/// Native Android notification helpers via MethodChannel.
class NativeAlarmService {
  static const _channel = MethodChannel('com.example.course_schedule_app/alarm');

  /// Post a notification immediately.
  ///
  /// [type] must be one of `reminder` / `ongoing` / `dismiss`:
  ///   - `reminder`  课后可划掉，有提示音（课前提醒）
  ///   - `ongoing`   常驻不可划掉（正在上课）
  ///   - `dismiss`   静默且可自动清除
  /// Unknown values on the native side degrade to `ongoing`.
  ///
  /// [durationText] is an optional time-range suffix (e.g. `8:00~9:40`)
  /// appended after [body]; empty string omits it.
  static Future<void> fireImmediate({
    required int id,
    required int notifyId,
    required String title,
    required String body,
    String type = 'ongoing',
    String durationText = '',
  }) async {
    try {
      await _channel.invokeMethod('fireImmediate', {
        'id': id,
        'notifyId': notifyId,
        'title': title,
        'body': body,
        'type': type,
        'durationText': durationText,
      });
    } catch (_) {}
  }

  /// Cancel a notification by its notifyId.
  static Future<void> cancelNotification(int notifyId) async {
    try {
      await _channel.invokeMethod('cancelNotification', {'notifyId': notifyId});
    } catch (_) {}
  }
}
