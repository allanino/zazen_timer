import 'package:flutter/material.dart';

import 'models.dart';
import 'time_picker_screen.dart';

class PresetEditScreen extends StatefulWidget {
  final SessionPreset? preset;

  const PresetEditScreen({super.key, this.preset});

  @override
  State<PresetEditScreen> createState() => _PresetEditScreenState();
}

class _PresetEditScreenState extends State<PresetEditScreen> {
  final List<_EditableStep> _steps = <_EditableStep>[];

  @override
  void initState() {
    super.initState();
    if (widget.preset != null) {
      for (final SessionStep s in widget.preset!.steps) {
        _steps.add(_EditableStep(type: s.type, totalSeconds: s.duration.inSeconds));
      }
    } else {
      _steps.addAll(<_EditableStep>[
        _EditableStep(type: StepType.preStart, totalSeconds: 60),
        _EditableStep(type: StepType.zazen, totalSeconds: 40 * 60),
      ]);
    }
  }

  List<SessionStep> _buildSessionSteps() {
    final List<SessionStep> steps = <SessionStep>[];
    for (final _EditableStep editable in _steps) {
      if (editable.totalSeconds <= 0) {
        continue;
      }
      steps.add(
        SessionStep(
          type: editable.type,
          duration: Duration(seconds: editable.totalSeconds),
        ),
      );
    }
    return steps;
  }

  void _addStep() {
    setState(() {
      _steps.add(_EditableStep(type: StepType.zazen, totalSeconds: 10 * 60));
    });
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    setState(() {
      _steps.removeAt(index);
    });
  }

  Future<void> _save() async {
    final List<SessionStep> steps = _buildSessionSteps();

    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one step with duration.')),
      );
      return;
    }

    final String name = buildPresetNameFromSteps(steps);

    final SessionPreset preset = SessionPreset(
      id: widget.preset?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      steps: steps,
    );

    if (!mounted) return;
    Navigator.of(context).pop<SessionPreset>(preset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                8,
                8,
                8 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 42, bottom: 12),
                children: <Widget>[
            ..._steps.asMap().entries.map((MapEntry<int, _EditableStep> entry) {
              final int index = entry.key;
              final _EditableStep step = entry.value;
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButton<StepType>(
                              isExpanded: true,
                              value: step.type,
                              underline: const SizedBox.shrink(),
                              items: StepType.values
                                  .map(
                                    (StepType t) =>
                                        DropdownMenuItem<StepType>(
                                      value: t,
                                      child: Text(
                                        switch (t) {
                                          StepType.preStart => 'Pre-start',
                                          StepType.zazen => 'Zazen',
                                          StepType.kinhin => 'Kinhin',
                                        },
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (StepType? value) {
                                if (value == null) return;
                                setState(() {
                                  step.type = value;
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeStep(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          const Text('Duration'),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              final (int, int, int)? result =
                                  await Navigator.of(context).push<(int, int, int)>(
                                MaterialPageRoute<(int, int, int)>(
                                  builder: (BuildContext context) =>
                                      TimePickerScreen(
                                    title: 'Set duration',
                                    initialHour: step.totalSeconds ~/ 3600,
                                    initialMinute: (step.totalSeconds % 3600) ~/ 60,
                                    initialSecond: step.totalSeconds % 60,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  step.totalSeconds =
                                      result.$1 * 3600 + result.$2 * 60 + result.$3;
                                });
                              }
                            },
                            child: Text(
                              step.durationLabel,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add),
                label: const Text('Add step'),
              ),
            ),
            const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Save preset'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableStep {
  StepType type;
  int totalSeconds;

  _EditableStep({
    required this.type,
    required this.totalSeconds,
  });

  /// Label like "5m" or "5m12s".
  String get durationLabel {
    final int totalMinutes = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    if (secs != 0) {
      return '${totalMinutes}m${secs}s';
    }
    return '${totalMinutes}m';
  }
}

