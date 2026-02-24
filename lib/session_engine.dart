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
    if (_remaining.inSeconds > 1) {
      _remaining -= const Duration(seconds: 1);
      _emitTick();
    } else {
      _advanceStep();
    }
  }

  void _advanceStep() {
    final SessionStep finishedStep = currentStep;

    if (_currentStepIndex + 1 < preset.steps.length) {
      _currentStepIndex++;
      _remaining = currentStep.duration;
      onTransition(finishedStep, currentStep);
      _emitTick();
    } else {
      _timer?.cancel();
      _timer = null;
      _remaining = Duration.zero;
      onTransition(finishedStep, null);
      onSessionEnd();
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

