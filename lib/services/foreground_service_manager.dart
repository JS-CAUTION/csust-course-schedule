import 'package:flutter/services.dart';

/// Manages the Android Foreground Service that keeps the app alive in the
/// background and owns the persistent course-status notification.
class ForegroundServiceManager {
  static const _channel = MethodChannel('com.example.course_schedule_app/service');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }

  /// Replaces the service notification's body text in place.
  ///
  /// Routed through the same method as [start] so the native side has a single
  /// path: the service calls `startForeground` again, which updates the
  /// existing notification rather than posting a second one.
  static Future<void> updateStatus(String body) async {
    try {
      await _channel.invokeMethod('startForegroundService', {'body': body});
    } catch (_) {}
  }
}
