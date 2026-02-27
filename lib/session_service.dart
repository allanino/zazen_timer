import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Platform channel for the session foreground service (Android).
/// The service runs the timer and vibrations; Flutter displays state when in foreground.
class SessionService {
  static const MethodChannel _channel = MethodChannel('session_service');

  /// Serializes [preset.steps] to JSON and starts the foreground service.
  /// Steps use type name (preStart, zazen, kinhin) and duration in seconds.
  static Future<void> startSession({required SessionPreset preset}) async {
    final List<Map<String, dynamic>> payload = preset.steps
        .map<Map<String, dynamic>>((SessionStep s) => <String, dynamic>{
              't': s.type.name,
              'd': s.duration.inSeconds,
            })
        .toList();
    final String sessionJson = jsonEncode(payload);
    try {
      await _channel.invokeMethod<void>(
        'startSession',
        <String, dynamic>{'session': sessionJson},
      );
    } on PlatformException catch (_) {
      rethrow;
    }
  }

  /// Stops the session foreground service.
  static Future<void> stopSession() async {
    try {
      await _channel.invokeMethod<void>('stopSession');
    } on PlatformException catch (_) {
      rethrow;
    }
  }

  /// Returns current session state from the service, or null if no session is running.
  static Future<SessionState?> getSessionState() async {
    try {
      final dynamic raw = await _channel.invokeMethod<dynamic>('getSessionState');
      if (raw == null || raw is! Map) return null;
      final Map<dynamic, dynamic> map = raw;
      final int stepIndex = map['stepIndex'] as int? ?? 0;
      final String stepType = map['stepType'] as String? ?? 'zazen';
      final int remainingMs = map['remainingMs'] as int? ?? 0;
      final int stepTotalMs = map['stepTotalMs'] as int? ?? 0;
      return SessionState(
        stepIndex: stepIndex,
        stepType: stepType,
        remaining: Duration(milliseconds: remainingMs),
        stepTotal: Duration(milliseconds: stepTotalMs),
      );
    } on PlatformException catch (_) {
      return null;
    }
  }
}

/// Current step and timing from the session service.
class SessionState {
  const SessionState({
    required this.stepIndex,
    required this.stepType,
    required this.remaining,
    required this.stepTotal,
  });

  final int stepIndex;
  final String stepType;
  final Duration remaining;
  final Duration stepTotal;

  /// Builds a [SessionStep] for UI (e.g. CircularTimer) from [stepType].
  SessionStep toSessionStep() {
    final StepType type = StepType.values.firstWhere(
      (StepType t) => t.name == stepType,
      orElse: () => StepType.zazen,
    );
    return SessionStep(type: type, duration: stepTotal);
  }
}
