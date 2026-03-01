// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zazen Timer';

  @override
  String deletePresetConfirm(String presetName) {
    return 'Delete \"$presetName\"? This cannot be undone.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get startSession => 'Start session';

  @override
  String get now => 'Now';

  @override
  String get schedule => 'Schedule';

  @override
  String get startTime => 'Start time';

  @override
  String get notificationPermissionMessage =>
      'Notification permission is needed for sessions.';

  @override
  String get exactAlarmPermissionMessage =>
      'For precision with the screen off, allow “Alarms & reminders”.';

  @override
  String get grant => 'Grant';

  @override
  String get goingBackStopsSession =>
      'Going back will stop the current session.';

  @override
  String get stop => 'Stop';

  @override
  String get tapCardToStartSession => 'Tap card to start session';

  @override
  String get newPreset => 'New preset';

  @override
  String get editPreset => 'Edit preset';

  @override
  String get deletePreset => 'Delete preset';

  @override
  String get addAtLeastOneStep => 'Add at least one step with duration.';

  @override
  String get preStart => 'Pre-start';

  @override
  String get zazen => 'Zazen';

  @override
  String get kinhin => 'Kinhin';

  @override
  String get duration => 'Duration';

  @override
  String get setDuration => 'Set duration';

  @override
  String get addStep => 'Add step';

  @override
  String get savePreset => 'Save preset';

  @override
  String get confirm => 'Confirm';

  @override
  String get untilStart => 'Until start';

  @override
  String minutesTotal(int count) {
    return '$count min total';
  }

  @override
  String get session => 'Session';

  @override
  String presetNameWithTotal(String breakdown, int total) {
    return '$breakdown ($total min total)';
  }
}
