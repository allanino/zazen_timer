enum StepType { preStart, zazen, kinhin }

class SessionStep {
  final StepType type;
  final Duration duration;

  const SessionStep({
    required this.type,
    required this.duration,
  });

  String get label {
    switch (type) {
      case StepType.preStart:
        return 'Until start';
      case StepType.zazen:
        return 'Zazen';
      case StepType.kinhin:
        return 'Kinhin';
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.name,
        'durationSeconds': duration.inSeconds,
      };

  factory SessionStep.fromJson(Map<String, dynamic> json) => SessionStep(
        type:
            StepType.values.firstWhere((StepType t) => t.name == json['type']),
        duration: Duration(
          seconds: json['durationSeconds'] as int? ?? 0,
        ),
      );
}

List<SessionStep> _displayStepsFor(List<SessionStep> steps) {
  final List<SessionStep> meditationOnly = steps
      .where(
        (SessionStep s) =>
            s.type == StepType.zazen || s.type == StepType.kinhin,
      )
      .toList();
  if (meditationOnly.isNotEmpty) {
    return meditationOnly;
  }
  return steps;
}

class SessionPreset {
  final String id;
  final String name;
  final List<SessionStep> steps;

  const SessionPreset({
    required this.id,
    required this.name,
    required this.steps,
  });

  List<SessionStep> get displaySteps => _displayStepsFor(steps);

  Duration get totalDuration => steps.fold<Duration>(
        Duration.zero,
        (Duration sum, SessionStep step) => sum + step.duration,
      );

  int get displayMinutesTotal => displaySteps.fold<int>(
        0,
        (int sum, SessionStep step) => sum + step.duration.inMinutes,
      );

  String get breakdownLabel {
    if (displaySteps.isEmpty) {
      return '';
    }
    return displaySteps
        .map<String>(
          (SessionStep step) => step.duration.inMinutes.toString(),
        )
        .join(' + ');
  }

  String get totalLabel => '$displayMinutesTotal min total';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'steps': steps.map<Map<String, dynamic>>((SessionStep s) => s.toJson()).toList(),
      };

  factory SessionPreset.fromJson(Map<String, dynamic> json) => SessionPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        steps: (json['steps'] as List<dynamic>)
            .map<SessionStep>(
              (dynamic raw) =>
                  SessionStep.fromJson(raw as Map<String, dynamic>),
            )
            .toList(),
      );
}

String buildPresetNameFromSteps(List<SessionStep> steps) {
  final List<SessionStep> effectiveSteps = _displayStepsFor(steps);
  if (effectiveSteps.isEmpty) {
    return 'Session';
  }

  final String breakdown = effectiveSteps
      .map<String>(
        (SessionStep step) => step.duration.inMinutes.toString(),
      )
      .join(' + ');
  final int totalMinutes = effectiveSteps.fold<int>(
    0,
    (int sum, SessionStep step) => sum + step.duration.inMinutes,
  );

  return '$breakdown ($totalMinutes min total)';
}


