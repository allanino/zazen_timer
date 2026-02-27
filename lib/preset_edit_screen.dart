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
  void dispose() {
    for (final _EditableStep step in _steps) {
      step.minutesController.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.preset != null) {
      for (final SessionStep s in widget.preset!.steps) {
        _steps.add(_EditableStep(type: s.type, minutes: s.duration.inMinutes));
      }
    } else {
      _steps.addAll(<_EditableStep>[
        _EditableStep(type: StepType.preStart, minutes: 1),
        _EditableStep(type: StepType.zazen, minutes: 40),
      ]);
    }
  }

  List<SessionStep> _buildSessionSteps() {
    final List<SessionStep> steps = <SessionStep>[];
    for (final _EditableStep editable in _steps) {
      final int minutes = editable.minutes;
      if (minutes <= 0) {
        continue;
      }
      steps.add(
        SessionStep(
          type: editable.type,
          duration: Duration(minutes: minutes),
        ),
      );
    }
    return steps;
  }

  void _addStep() {
    setState(() {
      _steps.add(_EditableStep(type: StepType.zazen, minutes: 10));
    });
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    setState(() {
      _steps[index].minutesController.dispose();
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
                          const Text('Minutes'),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              final (int, int, int)? result =
                                  await Navigator.of(context).push<(int, int, int)>(
                                MaterialPageRoute<(int, int, int)>(
                                  builder: (BuildContext context) =>
                                      TimePickerScreen(
                                    title: 'Set duration',
                                    initialHour: step.minutes ~/ 60,
                                    initialMinute: step.minutes % 60,
                                    initialSecond: 0,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  step.minutes = result.$1 * 60 + result.$2;
                                });
                              }
                            },
                            child: Text(
                              '${step.minutes} min',
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
  final TextEditingController minutesController;

  int get minutes => int.tryParse(minutesController.text) ?? 0;

  set minutes(int value) {
    minutesController.text = value.toString();
  }

  _EditableStep({
    required this.type,
    required int minutes,
  }) : minutesController =
            TextEditingController(text: minutes.toString());
}

