import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_colors.dart';
import 'models.dart';
import 'session_service.dart';
import 'preset_edit_screen.dart';
import 'preset_store.dart';
import 'time_picker_screen.dart';
import 'widgets/circular_timer.dart';

void main() {
  // Log errors in release so they appear in logcat (e.g. adb logcat) when the app closes.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      debugPrint('FlutterError: ${details.exception}');
      debugPrint(details.stack?.toString() ?? '');
    }
  };
  runZonedGuarded<Future<void>>(
    () async {
      runApp(const ZazenTimerApp());
    },
    (Object error, StackTrace stack) {
      debugPrint('Uncaught error: $error');
      debugPrint(stack.toString());
    },
  );
}

class ZazenTimerApp extends StatelessWidget {
  const ZazenTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zazen Timer',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark().copyWith(
          primary: kAccentColor,
          secondary: kAccentColor,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return kAccentColor;
              }
              // Darker, more muted thumb when off.
              return const Color(0xFF7A828C);
            },
          ),
          trackColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return kAccentColor.withOpacity(0.5);
              }
              // Darker background when off to increase contrast
              // between off and on states.
              return const Color(0xFF282D34);
            },
          ),
          trackOutlineColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              // Remove the bright/white outline in all states so
              // the thumb doesn't appear to have a separate margin.
              return Colors.transparent;
            },
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kAccentColor,
          foregroundColor: Colors.black,
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
  static const String _keyHasStartedSession = 'has_started_first_session';

  final PresetStore _store = PresetStore();
  List<SessionPreset> _presets = <SessionPreset>[];
  bool _loading = true;
  bool _hasStartedSession = false;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final List<SessionPreset> loaded = await _store.loadPresets();
      if (loaded.isEmpty) {
        _presets = _defaultPresets;
        try {
          await _store.savePresets(_presets);
        } catch (_) {
          // Ignore save failure; we still have in-memory defaults.
        }
      } else {
        _presets = loaded;
      }
    } catch (e, stack) {
      debugPrint('Preset load failed (using defaults): $e');
      debugPrint(stack.toString());
      _presets = _defaultPresets;
      try {
        await _store.savePresets(_presets);
      } catch (_) {}
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _hasStartedSession = prefs.getBool(_keyHasStartedSession) ?? false;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _markSessionStarted() async {
    if (_hasStartedSession) return;
    _hasStartedSession = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasStartedSession, true);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  static const List<SessionPreset> _defaultPresets = <SessionPreset>[
    SessionPreset(
      id: 'short-default',
      name: 'Short',
      steps: <SessionStep>[
        SessionStep(type: StepType.preStart, duration: Duration(minutes: 1)),
        SessionStep(type: StepType.zazen, duration: Duration(minutes: 20)),
        SessionStep(type: StepType.kinhin, duration: Duration(minutes: 10)),
        SessionStep(type: StepType.zazen, duration: Duration(minutes: 20)),
      ],
    ),
  ];

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
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Delete "${preset.breakdownLabel}"? This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _presets = _presets.where((SessionPreset p) => p.id != preset.id).toList();
      });
      await _store.savePresets(_presets);
    }
  }

  Future<void> _startPreset(SessionPreset preset) async {
    final String? choice = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Start session',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('now'),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Now'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop('time'),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Schedule', softWrap: false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    SessionPreset effective = preset;

    if (choice == 'time') {
      final DateTime now = DateTime.now();
      final TimeOfDay initial =
          TimeOfDay(hour: now.hour, minute: now.minute);
      final (int, int, int)? result =
          await Navigator.of(context).push<(int, int, int)>(
        MaterialPageRoute<(int, int, int)>(
          builder: (BuildContext context) => TimePickerScreen(
            title: 'Start time',
            initialHour: initial.hour,
            initialMinute: initial.minute,
            initialSecond: 0,
          ),
        ),
      );
      if (!mounted || result == null) return;
      final int secondsOfDay =
          result.$1 * 3600 + result.$2 * 60 + result.$3;
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

    await _markSessionStarted();
    if (!mounted) return;

    final PermissionStatus status = await Permission.notification.status;
    if (!status.isGranted) {
      final PermissionStatus result = await Permission.notification.request();
      if (!result.isGranted) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.85),
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Notification permission is needed for sessions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          TextButton(
                            onPressed: () {
                              openAppSettings();
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Grant'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        return;
      }
    }
    if (!mounted) return;
    try {
      await SessionService.startSession(preset: effective);
    } catch (_) {
      return;
    }
    if (!mounted) return;
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
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  24,
                  16,
                  MediaQuery.of(context).padding.bottom + 12.0,
                ),
                itemCount: (_presets.length <= 2 ? 1 : 0) + _presets.length + 1,
                itemBuilder: (BuildContext context, int index) {
                  final bool hasLeadingSpacer = _presets.length <= 2;
                  if (hasLeadingSpacer && index == 0) {
                    return const SizedBox(height: 8);
                  }
                  final int contentIndex = index - (hasLeadingSpacer ? 1 : 0);
                  if (contentIndex < _presets.length) {
                    final SessionPreset preset = _presets[contentIndex];
                    const double listHorizontalPadding = 32; // 16 + 16 from ListView padding
                    final double cardWidth = (MediaQuery.sizeOf(context).width - listHorizontalPadding).clamp(0.0, double.infinity);
                    final Widget card = SizedBox(
                      width: cardWidth,
                      child: _PresetListItem(
                        key: ValueKey<String>(preset.id),
                        preset: preset,
                        onStart: () => _startPreset(preset),
                        onEdit: () => _editPreset(preset),
                        onDelete: () => _deletePreset(preset),
                      ),
                    );
                    final bool showTapHint =
                        contentIndex == 0 && !_hasStartedSession;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: showTapHint
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Tap card to start session',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                card,
                              ],
                            )
                          : card,
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
      ),
      // FAB removed — button is rendered inline as the last list element
    );
  }
}

class _PresetListItem extends StatefulWidget {
  final SessionPreset preset;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PresetListItem({
    super.key,
    required this.preset,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PresetListItem> createState() => _PresetListItemState();
}

class _PresetListItemState extends State<_PresetListItem> {
  static const double _actionWidth = 112;
  static const double _gap = 6;
  static const double _maxReveal = _actionWidth + _gap;
  double _dragOffset = 0;
  double _dragStartOffset = 0;

  void _handleHorizontalDragStart(DragStartDetails details) {
    _dragStartOffset = _dragOffset;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx)
          .clamp(-_maxReveal, 0.0);
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final double velocity = details.velocity.pixelsPerSecond.dx;
    const double flingVelocity = 250; // Logical px/s threshold for a fling
    const double fractionThreshold = 0.5; // 50% of reveal for snap decision

    setState(() {
      if (velocity > flingVelocity) {
        // Fast swipe to the right → close.
        _dragOffset = 0;
      } else if (velocity < -flingVelocity) {
        // Fast swipe to the left → fully open.
        _dragOffset = -_maxReveal;
      } else if (_dragStartOffset <= -_maxReveal + 0.01 &&
          _dragOffset > _dragStartOffset) {
        // Drag started from fully open and moved right at least a bit → close,
        // even if it didn't cross the distance threshold.
        _dragOffset = 0;
      } else if (_dragOffset.abs() < _maxReveal * fractionThreshold) {
        // Closer to closed → snap closed.
        _dragOffset = 0;
      } else {
        // Closer to open → snap fully open.
        _dragOffset = -_maxReveal;
      }
    });
  }

  void _handleTap() {
    if (_dragOffset != 0) {
      setState(() {
        _dragOffset = 0;
      });
    } else {
      widget.onStart();
    }
  }
    void _handleEditTap() {
    setState(() {
      _dragOffset = 0;
    });
    widget.onEdit();
  }

  void _handleDeleteTap() {
    setState(() {
      _dragOffset = 0;
    });
    widget.onDelete();
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _handleHorizontalDragStart,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      onTap: _handleTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: <Widget>[
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: _actionWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Edit preset',
                    child: _ActionButton(
                      color: const Color(0xFF4C7A96),
                      icon: Icons.edit,
                      onTap: _handleEditTap,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  )
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Delete preset',
                    child: _ActionButton(
                      color: const Color(0xFFB05A5A),
                      icon: Icons.delete,
                      onTap: _handleDeleteTap,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                  )
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF262B32),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _dragOffset == 0
                  ? const <BoxShadow>[]
                  : <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _handleTap,
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
                              widget.preset.breakdownLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEEEEEE),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.preset.totalLabel,
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
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _ActionButton({
    required this.color,
    required this.icon,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Center(
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

class SessionScreen extends StatefulWidget {
  final SessionPreset preset;

  const SessionScreen({
    super.key,
    required this.preset,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  SessionState? _state;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _poll();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      _poll();
    });
  }

  Future<void> _poll() async {
    final SessionState? state = await SessionService.getSessionState();
    if (!mounted) return;
    if (state == null) {
      _pollTimer?.cancel();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _state = state;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _onBackPressed() async {
    final bool? stop = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Going back will stop the current session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (stop == true && mounted) {
      _pollTimer?.cancel();
      _pollTimer = null;
      await SessionService.stopSession();
      if (mounted) {
        Navigator.of(context).pop();
      }
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
        body: _state == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularTimer(
                    remaining: _state!.remaining,
                    total: _state!.stepTotal,
                    step: _state!.toSessionStep(),
                  ),
                ),
              ),
      ),
    );
  }
}

