// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Zazen Timer';

  @override
  String deletePresetConfirm(String presetName) {
    return '¿Eliminar \"$presetName\"? Esta acción no se puede deshacer.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get startSession => 'Iniciar sesión';

  @override
  String get now => 'Ahora';

  @override
  String get schedule => 'Programar';

  @override
  String get startTime => 'Hora de inicio';

  @override
  String get notificationPermissionMessage =>
      'Se necesita permiso de notificaciones para las sesiones.';

  @override
  String get grant => 'Conceder';

  @override
  String get goingBackStopsSession => 'Volver detendrá la sesión actual.';

  @override
  String get stop => 'Detener';

  @override
  String get tapCardToStartSession => 'Toca la tarjeta para iniciar la sesión';

  @override
  String get newPreset => 'Nueva plantilla';

  @override
  String get editPreset => 'Editar plantilla';

  @override
  String get deletePreset => 'Eliminar plantilla';

  @override
  String get addAtLeastOneStep => 'Añade al menos un paso con duración.';

  @override
  String get preStart => 'Pre-inicio';

  @override
  String get zazen => 'Zazen';

  @override
  String get kinhin => 'Kinhin';

  @override
  String get duration => 'Duración';

  @override
  String get setDuration => 'Establecer duración';

  @override
  String get addStep => 'Añadir paso';

  @override
  String get savePreset => 'Guardar plantilla';

  @override
  String get confirm => 'Confirmar';

  @override
  String get untilStart => 'Hasta el inicio';

  @override
  String minutesTotal(int count) {
    return '$count min en total';
  }

  @override
  String get session => 'Sesión';

  @override
  String presetNameWithTotal(String breakdown, int total) {
    return '$breakdown ($total min en total)';
  }
}
