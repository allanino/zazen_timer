import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_colors.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'session_service.dart';
import 'preset_edit_screen.dart';
import 'preset_store.dart';
import 'time_picker_screen.dart';
import 'widgets/circular_timer.dart';

/// SharedPreferences key for the preset of the currently running session (restore SessionScreen when app is reopened).
const String _kOngoingSessionPresetKey = 'ongoing_session_preset';

/// Wraps dialog content with a short entrance animation: fade + scale 0.95 → 1.0.
class _AnimatedDialogContent extends StatelessWidget {
  const _AnimatedDialogContent({required this.child});

  final Widget child;

  static const Duration _duration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeOut,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.75 + 0.25 * value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

class _PresetListScreenState extends State<PresetListScreen>
    with WidgetsBindingObserver {
  static const String _keyHasStartedSession = 'has_started_first_session';

  final PresetStore _store = PresetStore();
  List<SessionPreset> _presets = <SessionPreset>[];
  bool _loading = true;
  bool _hasStartedSession = false;
  SessionPreset? _pendingPresetAfterExactAlarm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPresets();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSessionIfRunning());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final SessionPreset? pending = _pendingPresetAfterExactAlarm;
    if (pending != null) {
      SessionService.canScheduleExactAlarms().then((bool granted) {
        if (!mounted) return;
        if (!granted) return; // Keep pending so next resume (after user grants in settings) can start
        setState(() => _pendingPresetAfterExactAlarm = null);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _runSessionFlow(pending);
        });
      });
    } else {
      _restoreSessionIfRunning();
    }
  }

  Future<void> _saveOngoingSessionPreset(SessionPreset preset) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOngoingSessionPresetKey, jsonEncode(preset.toJson()));
    } catch (_) {}
  }

  Future<void> _restoreSessionIfRunning() async {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final SessionState? state = await SessionService.getSessionState();
    if (!mounted || state == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? json = prefs.getString(_kOngoingSessionPresetKey);
      if (json == null) return;
      final SessionPreset preset = SessionPreset.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => SessionScreen(preset: preset),
        ),
      );
    } catch (_) {}
  }

  /// Runs the session flow (start dialog, optional time picker, save, start, push)
  /// assuming permissions are already granted.
  Future<void> _runSessionFlow(SessionPreset preset) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? choice = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width,
                maxHeight: MediaQuery.sizeOf(context).height - 64,
              ),
              child: _AnimatedDialogContent(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height - 64,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 32, bottom: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              l10n.startSession,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                final spacing = constraints.maxWidth < 300 ? 16.0 : 28.0;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    SizedBox(height: spacing),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 0,
                                      alignment: WrapAlignment.center,
                                      children: <Widget>[
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop('now'),
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shape: const StadiumBorder(),
                                          ),
                                          child: Text(l10n.now),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop('time'),
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shape: const StadiumBorder(),
                                          ),
                                          child: Text(l10n.schedule, softWrap: false),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
            title: l10n.startTime,
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

    await _saveOngoingSessionPreset(effective);
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width,
                maxHeight: MediaQuery.sizeOf(context).height - 64,
              ),
              child: _AnimatedDialogContent(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height - 64,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 32, bottom: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              l10n.deletePresetConfirm(preset.breakdownLabel),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            final spacing = constraints.maxWidth < 300 ? 16.0 : 28.0;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                SizedBox(height: spacing),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 0,
                                  alignment: WrapAlignment.center,
                                  children: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Text(l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: kDeleteColor,
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
    // Request permissions before showing the start session dialog.
    final PermissionStatus status = await Permission.notification.status;
    if (!status.isGranted) {
      if (!mounted) return;
      final AppLocalizations permL10n = AppLocalizations.of(context)!;
      final bool? notificationGranted = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.9),
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width,
                  maxHeight: MediaQuery.sizeOf(context).height - 64,
                ),
                child: _AnimatedDialogContent(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.sizeOf(context).height - 64,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                permL10n.notificationPermissionMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              LayoutBuilder(
                                builder: (BuildContext context, BoxConstraints constraints) {
                                  final spacing = constraints.maxWidth < 300 ? 16.0 : 28.0;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      SizedBox(height: spacing),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 0,
                                        alignment: WrapAlignment.center,
                                        children: <Widget>[
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            style: TextButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shape: const StadiumBorder(),
                                            ),
                                            child: Text(permL10n.cancel),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              final PermissionStatus result =
                                                  await Permission.notification.request();
                                              if (!context.mounted) return;
                                              Navigator.of(context).pop(result.isGranted);
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shape: const StadiumBorder(),
                                            ),
                                            child: Text(permL10n.grant),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      if (notificationGranted != true) return;
    }
    if (!mounted) return;

    final bool canExactAlarms = await SessionService.canScheduleExactAlarms();
    if (!canExactAlarms) {
      if (!mounted) return;
      setState(() => _pendingPresetAfterExactAlarm = preset);
      final AppLocalizations permL10n = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.9),
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width,
                  maxHeight: MediaQuery.sizeOf(context).height - 64,
                ),
                child: _AnimatedDialogContent(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.sizeOf(context).height - 64,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                permL10n.exactAlarmPermissionMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              LayoutBuilder(
                                builder: (BuildContext context, BoxConstraints constraints) {
                                  final spacing = constraints.maxWidth < 300 ? 16.0 : 28.0;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      SizedBox(height: spacing),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 0,
                                        alignment: WrapAlignment.center,
                                        children: <Widget>[
                                          TextButton(
                                            onPressed: () {
                                              setState(() => _pendingPresetAfterExactAlarm = null);
                                              Navigator.of(context).pop();
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shape: const StadiumBorder(),
                                            ),
                                            child: Text(permL10n.cancel),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              SessionService.openExactAlarmSettings();
                                              Navigator.of(context).pop();
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shape: const StadiumBorder(),
                                            ),
                                            child: Text(permL10n.grant),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      return;
    }
    if (!mounted) return;

    await _runSessionFlow(preset);
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
                  28,
                  24,
                  28,
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
                    const double listHorizontalPadding = 56; // 28 + 28 from ListView padding
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
                                    AppLocalizations.of(context)!.tapCardToStartSession,
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
                          label: Text(AppLocalizations.of(context)!.newPreset),
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
  static const double _actionWidth = 84;
  static const double _gap = 3;
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
                    label: AppLocalizations.of(context)!.editPreset,
                    child: _ActionButton(
                      backgroundColor: const Color(0xFF262B32),
                      iconColor: kAccentColor,
                      icon: Icons.edit,
                      onTap: _handleEditTap,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  )
                ),
                SizedBox(
                  width: 2,
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final double h = constraints.maxHeight * 0.8;
                      return Container(
                        color: const Color(0xFF262B32), // same as pill background
                        alignment: Alignment.center,
                        child: Container(
                          width: 1,
                          height: h,
                          color: const Color.fromARGB(255, 30, 34, 40),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: AppLocalizations.of(context)!.deletePreset,
                    child: _ActionButton(
                      backgroundColor: const Color(0xFF262B32),
                      iconColor: kDeleteColor,
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
                              AppLocalizations.of(context)!.minutesTotal(widget.preset.displayMinutesTotal),
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
  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _ActionButton({
    required this.backgroundColor,
    required this.iconColor,
    required this.icon,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Center(
          child: Icon(icon, size: 22, color: iconColor),
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

class _SessionScreenState extends State<SessionScreen>
    with WidgetsBindingObserver {
  SessionState? _state;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _poll();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _poll();
      _startPolling();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _poll();
    });
  }

  Future<void> _poll() async {
    final SessionState? state = await SessionService.getSessionState();
    if (!mounted) return;
    if (state == null) {
      _pollTimer?.cancel();
      _pollTimer = null;
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kOngoingSessionPresetKey);
      } catch (_) {}
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _state = state;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _onBackPressed() async {
    final bool? stop = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width,
                maxHeight: MediaQuery.sizeOf(context).height - 64,
              ),
              child: _AnimatedDialogContent(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height - 64,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 32, bottom: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              AppLocalizations.of(context)!.goingBackStopsSession,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            final spacing = constraints.maxWidth < 300 ? 16.0 : 28.0;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                SizedBox(height: spacing),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 0,
                                  alignment: WrapAlignment.center,
                                  children: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Text(AppLocalizations.of(context)!.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Text(AppLocalizations.of(context)!.stop),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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

