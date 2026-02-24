import 'package:flutter/material.dart';

import 'models.dart';
import 'minute_picker_screen.dart';
import 'package:flutter/services.dart';

class PresetEditScreen extends StatefulWidget {
  const PresetEditScreen({super.key});

  @override
  State<PresetEditScreen> createState() => _PresetEditScreenState();
}

class _PresetEditScreenState extends State<PresetEditScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'New preset');
  final FocusNode _nameFocusNode = FocusNode();
  String _lastReportedText = '';
  final List<_EditableStep> _steps = <_EditableStep>[
    _EditableStep(type: StepType.preStart, minutes: 5),
    _EditableStep(type: StepType.zazen, minutes: 40),
  ];

  @override
  void dispose() {
    _nameController.removeListener(_nameListener);
    _nameController.dispose();
    _nameFocusNode.dispose();
    for (final _EditableStep step in _steps) {
      step.minutesController.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _lastReportedText = _nameController.text;
    _nameController.addListener(_nameListener);
  }


  void _nameListener() {
    final TextEditingValue v = _nameController.value;
    // If IME is composing (e.g., using on-screen keyboard composition), avoid
    // repainting which can interfere with composition. Only rebuild when
    // composition is not active and the text actually changed.
    // Push the current editing state to the platform IME to keep the
    // on-screen/extract editor in sync. Some keyboards (notably on Wear OS)
    // keep their own copy of the text and don't update properly; forcing an
    // explicit setEditingState helps synchronize them.
    try {
      SystemChannels.textInput.invokeMethod<void>('TextInput.setEditingState', <String, dynamic>{
        'text': v.text,
        'selectionBase': v.selection.baseOffset,
        'selectionExtent': v.selection.extentOffset,
        'composingBase': v.composing.start,
        'composingExtent': v.composing.end,
      });
    } catch (_) {
      // ignore platform channel errors
    }

    final bool isComposing = v.composing.isValid;

    if (!isComposing && v.text != _lastReportedText) {
      _lastReportedText = v.text;
      if (mounted) setState(() {});
    }
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
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give the preset a name.')),
      );
      return;
    }

    final List<SessionStep> steps = <SessionStep>[];
    for (final _EditableStep editable in _steps) {
      final int minutes = editable.minutes;
      if (minutes <= 0) continue;
      steps.add(
        SessionStep(
          type: editable.type,
          duration: Duration(minutes: minutes),
        ),
      );
    }

    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one step with duration.')),
      );
      return;
    }

    final SessionPreset preset = SessionPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      steps: steps,
    );

    if (!mounted) return;
    Navigator.of(context).pop<SessionPreset>(preset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New preset'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
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
                padding: const EdgeInsets.only(bottom: 12),
                children: <Widget>[
                  TextField(
              controller: _nameController,
              autocorrect: false,
              enableSuggestions: false,
              focusNode: _nameFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              cursorColor: Theme.of(context).colorScheme.primary,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'Preset name',
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
            ),
            const SizedBox(height: 8),
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
                              final int? picked =
                                  await Navigator.of(context).push<int>(
                                MaterialPageRoute<int>(
                                  builder: (BuildContext context) =>
                                      MinutePickerScreen(
                                    initialMinutes: step.minutes,
                                  ),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  step.minutes = picked;
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

