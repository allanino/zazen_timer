import 'package:flutter/services.dart';

class Haptics {
  static const MethodChannel _channel = MethodChannel('zazen_timer/haptics');

  static Future<bool> hasVibrator() async {
    try {
      return (await _channel.invokeMethod<bool>('hasVibrator')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _pattern(List<int> pattern) async {
    try {
      await _channel.invokeMethod<void>(
        'vibratePattern',
        <String, dynamic>{'pattern': pattern},
      );
    } catch (_) {
      // Ignore (e.g. running on a platform without an implementation).
    }
  }

  /// Three medium vibrations – used at zazen start and kinhin -> zazen.
  static Future<void> threeMedium() async {
    await _pattern(<int>[0, 100, 200, 100, 200, 100]);
  }

  /// Two medium vibrations – used at zazen -> kinhin.
  static Future<void> twoMedium() async {
    await _pattern(<int>[0, 100, 200, 100]);
  }

  /// One long vibration – used at session end.
  static Future<void> oneLong() async {
    try {
      await _channel.invokeMethod<void>(
        'vibrateOneShot',
        <String, dynamic>{'durationMs': 300},
      );
    } catch (_) {
      // Ignore.
    }
  }
}

