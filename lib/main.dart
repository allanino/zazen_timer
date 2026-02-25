import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
        const SessionPreset(
          id: 'evening-default',
          name: 'Evening zazen',
          steps: <SessionStep>[
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

  Future<void> _editPreset(SessionPreset preset) async {
    final SessionPreset? edited = await Navigator.of(context).push<SessionPreset>(
      MaterialPageRoute<SessionPreset>(
        builder: (BuildContext context) => PresetEditScreen(preset: preset),
      ),
    );

    if (edited != null) {
      setState(() {
        _presets = _presets.map((SessionPreset p) => p.id == edited.id ? edited : p).toList();
      });
      await _store.savePresets(_presets);
    }
  }

  Future<void> _deletePreset(SessionPreset preset) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: const Text('Delete preset'),
        content: SingleChildScrollView(
          child: Text('Delete "${preset.name}"? This cannot be undone.'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _presets = _presets.where((SessionPreset p) => p.id != preset.id).toList();
      });
      await _store.savePresets(_presets);
    }
  }

  Future<void> _startPreset(SessionPreset preset) async {
    final _StartOptions? options = await showDialog<_StartOptions>(
      context: context,
      builder: (BuildContext context) {
        bool noDisplay = false;
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
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
                            onPressed: () => Navigator.of(context).pop(
                              _StartOptions(
                                choice: 'now',
                                noDisplay: noDisplay,
                              ),
                            ),
                            child: const Text('Now'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(
                              _StartOptions(
                                choice: 'time',
                                noDisplay: noDisplay,
                              ),
                            ),
                            child: const Text('Pick time'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const <Widget>[
                              Text(
                                'No display',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Keep the screen black while the session runs, using vibrations only.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Switch(
                          value: noDisplay,
                          onChanged: (bool value) {
                            setState(() {
                              noDisplay = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || options == null) return;

    final String choice = options.choice;
    final bool noDisplay = options.noDisplay;

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
      if (!mounted || secondsOfDay == null) return;
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
        builder: (BuildContext context) => SessionScreen(
          preset: effective,
          noDisplay: noDisplay,
        ),
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
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 12.0,
              ),
              itemCount: _presets.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index < _presets.length) {
                  final SessionPreset preset = _presets[index];
                  const double listHorizontalPadding = 32; // 16 + 16 from ListView padding
                  final double cardWidth = MediaQuery.of(context).size.width - listHorizontalPadding;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: cardWidth,
                      child: Slidable(
                            key: ValueKey(preset.id),
                            endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: <Widget>[
                          CustomSlidableAction(
                            onPressed: (BuildContext context) => _editPreset(preset),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            child: const Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              children: <Widget>[
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(Icons.edit),
                                    SizedBox(height: 4),
                                    Text('Edit', overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          CustomSlidableAction(
                            onPressed: (BuildContext context) => _deletePreset(preset),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            child: const Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              children: <Widget>[
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(Icons.delete),
                                    SizedBox(height: 4),
                                    Text('Delete', overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      child: Material(
                        color: const Color(0xFF262B32),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _startPreset(preset),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                Text(
                                  preset.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFEEEEEE),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total: ${preset.totalDuration.inMinutes} min',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ),
                  );
                }

                // Footer: centered button that appears as the last list element
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
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

class _StartOptions {
  final String choice; // 'now' or 'time'
  final bool noDisplay;

  const _StartOptions({
    required this.choice,
    required this.noDisplay,
  });
}

class SessionScreen extends StatefulWidget {
  final SessionPreset preset;
  final bool? noDisplay;

  const SessionScreen({
    super.key,
    required this.preset,
    this.noDisplay,
  });

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

  Future<void> _onBackPressed() async {
    final bool? stop = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: const Text('Stop session?'),
        content: const SingleChildScrollView(
          child: Text(
            'Going back will stop the current session. Are you sure?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (stop == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: (widget.noDisplay ?? false)
            ? const ColoredBox(
                color: Colors.black,
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularTimer(
                    remaining: _remaining,
                    total: _currentTotal,
                    step: _currentStep,
                  ),
                ),
              ),
      ),
    );
  }
}

