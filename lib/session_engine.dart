import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';

class SessionEngine {
  final SessionPreset preset;
  final void Function(SessionStep currentStep, Duration remaining) onTick;
  final void Function(SessionStep? finishedStep, SessionStep? nextStep)
      onTransition;
  final VoidCallback onSessionEnd;

  int _currentStepIndex = 0;
  late Duration _remaining;
  Timer? _timer;
  DateTime? _sessionStartTime;

  SessionEngine({
    required this.preset,
    required this.onTick,
    required this.onTransition,
    required this.onSessionEnd,
  }) {
    _remaining = preset.steps.first.duration;
  }

  SessionStep get currentStep => preset.steps[_currentStepIndex];
  Duration get remaining => _remaining;

  bool get isRunning => _timer != null;

  void start() {
    _sessionStartTime = DateTime.now();
    _currentStepIndex = 0;
    _remaining = preset.steps.first.duration;
    _emitTick();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  void _emitTick() {
    onTick(currentStep, _remaining);
  }

  void _tick() {
    final DateTime? startTime = _sessionStartTime;
    if (startTime == null) return;

    final DateTime now = DateTime.now();
    Duration elapsed = now.difference(startTime);
    if (elapsed.isNegative) {
      elapsed = Duration.zero;
    }

    final Duration totalDuration = preset.steps.fold<Duration>(
      Duration.zero,
      (Duration sum, SessionStep step) => sum + step.duration,
    );

    if (elapsed >= totalDuration) {
      _timer?.cancel();
      _timer = null;
      _sessionStartTime = null;
      _remaining = Duration.zero;
      for (int i = _currentStepIndex; i < preset.steps.length - 1; i++) {
        onTransition(preset.steps[i], preset.steps[i + 1]);
      }
      onTransition(preset.steps[preset.steps.length - 1], null);
      onSessionEnd();
      return;
    }

    Duration offset = Duration.zero;
    int newStepIndex = 0;
    for (int i = 0; i < preset.steps.length; i++) {
      final SessionStep step = preset.steps[i];
      final Duration stepEnd = offset + step.duration;
      if (elapsed < stepEnd) {
        newStepIndex = i;
        final Duration timeIntoStep = elapsed - offset;
        if (timeIntoStep.isNegative) {
          _remaining = step.duration;
        } else {
          _remaining = step.duration - timeIntoStep;
          if (_remaining.isNegative) {
            _remaining = Duration.zero;
          }
        }
        break;
      }
      offset = stepEnd;
    }

    for (int i = _currentStepIndex; i < newStepIndex; i++) {
      onTransition(preset.steps[i], preset.steps[i + 1]);
    }
    _currentStepIndex = newStepIndex;

    _emitTick();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _sessionStartTime = null;
  }
}
