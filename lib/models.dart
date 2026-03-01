enum StepType { preStart, zazen, kinhin }

class SessionStep {
  final StepType type;
  final Duration duration;

  const SessionStep({
    required this.type,
    required this.duration,
  });

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

  /// Rounded minutes for display (e.g. 23m40s rounds to 24).
  static int _roundedMinutes(Duration d) => (d.inSeconds / 60).round();

  int get displayMinutesTotal => displaySteps.fold<int>(
        0,
        (int sum, SessionStep step) => sum + SessionPreset._roundedMinutes(step.duration),
      );

  String get breakdownLabel {
    if (displaySteps.isEmpty) {
      return '';
    }
    return displaySteps
        .map<String>(
          (SessionStep step) => SessionPreset._roundedMinutes(step.duration).toString(),
        )
        .join(' + ');
  }

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

int _roundedMinutesFromDuration(Duration d) => (d.inSeconds / 60).round();

/// Builds a display name for a preset from its steps. Use [emptyName] when there
/// are no display steps, and [withTotal] for "{breakdown} ({total} min total)".
String buildPresetNameFromSteps(
  List<SessionStep> steps, {
  required String emptyName,
  required String Function(String breakdown, int total) withTotal,
}) {
  final List<SessionStep> effectiveSteps = _displayStepsFor(steps);
  if (effectiveSteps.isEmpty) {
    return emptyName;
  }

  final String breakdown = effectiveSteps
      .map<String>(
        (SessionStep step) => _roundedMinutesFromDuration(step.duration).toString(),
      )
      .join(' + ');
  final int totalMinutes = effectiveSteps.fold<int>(
    0,
    (int sum, SessionStep step) => sum + _roundedMinutesFromDuration(step.duration),
  );

  return withTotal(breakdown, totalMinutes);
}


