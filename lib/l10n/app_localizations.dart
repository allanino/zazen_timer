import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Zazen Timer'**
  String get appTitle;

  /// No description provided for @deletePresetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{presetName}\"? This cannot be undone.'**
  String deletePresetConfirm(String presetName);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @startSession.
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get startSession;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @notificationPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is needed for sessions.'**
  String get notificationPermissionMessage;

  /// No description provided for @grant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get grant;

  /// No description provided for @goingBackStopsSession.
  ///
  /// In en, this message translates to:
  /// **'Going back will stop the current session.'**
  String get goingBackStopsSession;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @tapCardToStartSession.
  ///
  /// In en, this message translates to:
  /// **'Tap card to start session'**
  String get tapCardToStartSession;

  /// No description provided for @newPreset.
  ///
  /// In en, this message translates to:
  /// **'New preset'**
  String get newPreset;

  /// No description provided for @editPreset.
  ///
  /// In en, this message translates to:
  /// **'Edit preset'**
  String get editPreset;

  /// No description provided for @deletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete preset'**
  String get deletePreset;

  /// No description provided for @addAtLeastOneStep.
  ///
  /// In en, this message translates to:
  /// **'Add at least one step with duration.'**
  String get addAtLeastOneStep;

  /// No description provided for @preStart.
  ///
  /// In en, this message translates to:
  /// **'Pre-start'**
  String get preStart;

  /// No description provided for @zazen.
  ///
  /// In en, this message translates to:
  /// **'Zazen'**
  String get zazen;

  /// No description provided for @kinhin.
  ///
  /// In en, this message translates to:
  /// **'Kinhin'**
  String get kinhin;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @setDuration.
  ///
  /// In en, this message translates to:
  /// **'Set duration'**
  String get setDuration;

  /// No description provided for @addStep.
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get addStep;

  /// No description provided for @savePreset.
  ///
  /// In en, this message translates to:
  /// **'Save preset'**
  String get savePreset;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @untilStart.
  ///
  /// In en, this message translates to:
  /// **'Until start'**
  String get untilStart;

  /// No description provided for @minutesTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} min total'**
  String minutesTotal(int count);

  /// No description provided for @session.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get session;

  /// No description provided for @presetNameWithTotal.
  ///
  /// In en, this message translates to:
  /// **'{breakdown} ({total} min total)'**
  String presetNameWithTotal(String breakdown, int total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
