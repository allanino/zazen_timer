import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'models.dart';

/// Runs session steps in Dart (used on web where there is no native session service).
class _LocalSessionRunner {
  List<SessionStep> _steps = <SessionStep>[];
  int _stepIndex = 0;
  Duration _remaining = Duration.zero;
  Timer? _timer;

  void start(SessionPreset preset) {
    stop();
    _steps = List<SessionStep>.from(preset.steps);
    if (_steps.isEmpty) return;
    _stepIndex = 0;
    _remaining = _steps[0].duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining -= const Duration(seconds: 1);
      if (_remaining <= Duration.zero) {
        _stepIndex += 1;
        if (_stepIndex >= _steps.length) {
          stop();
          return;
        }
        _remaining = _steps[_stepIndex].duration;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _steps = <SessionStep>[];
    _stepIndex = 0;
    _remaining = Duration.zero;
  }

  SessionState? get currentState {
    if (_steps.isEmpty || _stepIndex >= _steps.length) return null;
    final SessionStep step = _steps[_stepIndex];
    return SessionState(
      stepIndex: _stepIndex,
      stepType: step.type.name,
      remaining: _remaining,
      stepTotal: step.duration,
    );
  }
}

final _LocalSessionRunner _localRunner = _LocalSessionRunner();

/// Platform channel for the session foreground service (Android).
/// On web, runs the session in Dart via [_LocalSessionRunner].
class SessionService {
  static const MethodChannel _channel = MethodChannel('session_service');

  /// Serializes [preset.steps] to JSON and starts the foreground service (Android)
  /// or the in-Dart runner (web).
  static Future<void> startSession({required SessionPreset preset}) async {
    if (kIsWeb) {
      _localRunner.start(preset);
      return;
    }
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

  /// Stops the session foreground service or the in-Dart runner.
  static Future<void> stopSession() async {
    if (kIsWeb) {
      _localRunner.stop();
      return;
    }
    try {
      await _channel.invokeMethod<void>('stopSession');
    } on PlatformException catch (_) {
      rethrow;
    }
  }

  /// Returns current session state from the service or local runner, or null if no session is running.
  static Future<SessionState?> getSessionState() async {
    if (kIsWeb) {
      return _localRunner.currentState;
    }
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
