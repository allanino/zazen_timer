import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'haptics.dart';
import 'models.dart';
import 'preset_edit_screen.dart';
import 'preset_store.dart';
import 'session_engine.dart';
import 'start_time_picker_screen.dart';
import 'widgets/circular_timer.dart';

void main() {
  runApp(const ZazenTimerApp());
}

class ZazenTimerApp extends StatelessWidget {
  const ZazenTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zazen Timer',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.teal,
        ),
      ),
      home: const PresetListScreen(),
    );
  }
}

class PresetListScreen extends StatefulWidget {
  const PresetListScreen({super.key});

  @override
  State<PresetListScreen> createState() => _PresetListScreenState();
}

class _PresetListScreenState extends State<PresetListScreen> {
  final PresetStore _store = PresetStore();
  List<SessionPreset> _presets = <SessionPreset>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final List<SessionPreset> loaded = await _store.loadPresets();
    if (loaded.isEmpty) {
      // Provide a sensible default based on your description.
      _presets = <SessionPreset>[
        SessionPreset(
          id: 'evening-default',
          name: 'Evening zazen',
          steps: const <SessionStep>[
            SessionStep(type: StepType.preStart, duration: Duration(minutes: 5)),
            SessionStep(type: StepType.zazen, duration: Duration(minutes: 40)),
            SessionStep(type: StepType.kinhin, duration: Duration(minutes: 10)),
            SessionStep(type: StepType.zazen, duration: Duration(minutes: 40)),
          ],
        ),
      ];
      await _store.savePresets(_presets);
    } else {
      _presets = loaded;
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _createPreset() async {
    final SessionPreset? created =
        await Navigator.of(context).push<SessionPreset>(
      MaterialPageRoute<SessionPreset>(
        builder: (BuildContext context) => const PresetEditScreen(),
      ),
    );

    if (created != null) {
      setState(() {
        _presets = <SessionPreset>[..._presets, created];
      });
      await _store.savePresets(_presets);
    }
  }

  Future<void> _startPreset(SessionPreset preset) async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Start now or at a specific time?', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop('now'),
                        child: const Text('Now'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop('time'),
                        child: const Text('Pick time'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    SessionPreset effective = preset;

    if (choice == 'time') {
      final DateTime now = DateTime.now();
      final TimeOfDay initial =
          TimeOfDay(hour: now.hour, minute: now.minute);
      final int? secondsOfDay =
          await Navigator.of(context).push<int>(
        MaterialPageRoute<int>(
          builder: (BuildContext context) =>
              StartTimePickerScreen(initialTime: initial),
        ),
      );
      if (secondsOfDay == null) return;
      final int nowSeconds =
          now.hour * 3600 + now.minute * 60 + now.second;
      int diffSeconds = secondsOfDay - nowSeconds;
      if (diffSeconds < 0) diffSeconds += 24 * 3600;

      final List<SessionStep> steps = <SessionStep>[...preset.steps];
      final Duration preStartDuration = Duration(seconds: diffSeconds);

      if (steps.isNotEmpty && steps.first.type == StepType.preStart) {
        steps[0] = SessionStep(
          type: StepType.preStart,
          duration: preStartDuration,
        );
      } else {
        steps.insert(
          0,
          SessionStep(
            type: StepType.preStart,
            duration: preStartDuration,
          ),
        );
      }

      effective = SessionPreset(
        id: preset.id,
        name: preset.name,
        steps: steps,
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SessionScreen(preset: effective),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presets'),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12.0,
              ),
              itemCount: _presets.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index < _presets.length) {
                  final SessionPreset preset = _presets[index];
                  return ListTile(
                    title: Text(preset.name),
                    subtitle: Text(
                      'Total: ${preset.totalDuration.inMinutes} min',
                    ),
                    onTap: () => _startPreset(preset),
                  );
                }

                // Footer: centered button that appears as the last list element
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: GestureDetector(
                      onTap: _createPreset,
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _createPreset,
                          icon: const Icon(Icons.add),
                          label: const Text('New preset'),
                          style: ElevatedButton.styleFrom(
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // FAB removed — button is rendered inline as the last list element
    );
  }
}

class SessionScreen extends StatefulWidget {
  final SessionPreset preset;

  const SessionScreen({super.key, required this.preset});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late SessionEngine _engine;
  late SessionStep _currentStep;
  late Duration _remaining;
  late Duration _currentTotal;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.preset.steps.first;
    _remaining = _currentStep.duration;
    _currentTotal = _currentStep.duration;

    _engine = SessionEngine(
      preset: widget.preset,
      onTick: (SessionStep step, Duration remaining) {
        setState(() {
          _currentStep = step;
          _remaining = remaining;
          _currentTotal = step.duration;
        });
      },
      onTransition: (SessionStep? finished, SessionStep? next) {
        if (finished?.type == StepType.preStart &&
            next?.type == StepType.zazen) {
          Haptics.threeMedium();
        } else if (finished?.type == StepType.zazen &&
            next?.type == StepType.kinhin) {
          Haptics.twoMedium();
        } else if (finished?.type == StepType.kinhin &&
            next?.type == StepType.zazen) {
          Haptics.threeMedium();
        }
      },
      onSessionEnd: () {
        Haptics.oneLong();
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );

    WakelockPlus.enable();
    _engine.start();
  }

  @override
  void dispose() {
    _engine.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CircularTimer(
            remaining: _remaining,
            total: _currentTotal,
            step: _currentStep,
          ),
        ),
      ),
    );
  }
}

