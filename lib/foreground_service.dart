import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Runs the session timer in a foreground service so it keeps running when
/// the app is in the background. Android only.
class ForegroundService {
  static const MethodChannel _channel =
      MethodChannel('zazen_timer/foreground_service');

  /// Starts the session in the native foreground service. The timer and
  /// haptics run in the service and keep going when the app is backgrounded.
  static Future<void> startSession({
    required String presetJson,
    String title = 'Zazen Timer',
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('start', <String, dynamic>{
        'preset_json': presetJson,
        'title': title,
      });
    } catch (_) {
      // Ignore if not implemented or service fails (e.g. on emulator).
    }
  }

  static Future<void> stopSession() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Ignore.
    }
  }

  /// Current session state, or null if no session is running.
  /// Keys: preset_json, step_index, remaining_seconds, step_duration_seconds.
  static Future<Map<Object?, Object?>?> getState() async {
    if (!Platform.isAndroid) return null;
    try {
      final dynamic result = await _channel.invokeMethod<dynamic>('getState');
      if (result is Map) return result as Map<Object?, Object?>;
      return null;
    } catch (_) {
      return null;
    }
  }
}
