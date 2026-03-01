import 'l10n/app_localizations.dart';
import 'models.dart';

/// Returns the localized label for [type] when shown on the timer (e.g. "Until start").
String stepTypeLabel(StepType type, AppLocalizations l10n) {
  switch (type) {
    case StepType.preStart:
      return l10n.untilStart;
    case StepType.zazen:
      return l10n.zazen;
    case StepType.kinhin:
      return l10n.kinhin;
  }
}

/// Returns the localized label for [type] when shown in the preset editor dropdown (e.g. "Pre-start").
String stepTypeDropdownLabel(StepType type, AppLocalizations l10n) {
  switch (type) {
    case StepType.preStart:
      return l10n.preStart;
    case StepType.zazen:
      return l10n.zazen;
    case StepType.kinhin:
      return l10n.kinhin;
  }
}
