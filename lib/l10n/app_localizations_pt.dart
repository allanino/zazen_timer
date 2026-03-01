// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Zazen Timer';

  @override
  String deletePresetConfirm(String presetName) {
    return 'Excluir \"$presetName\"? Isso não pode ser desfeito.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get startSession => 'Iniciar sessão';

  @override
  String get now => 'Agora';

  @override
  String get schedule => 'Agendar';

  @override
  String get startTime => 'Horário de início';

  @override
  String get notificationPermissionMessage =>
      'É necessária permissão de notificação para as sessões.';

  @override
  String get grant => 'Conceder';

  @override
  String get goingBackStopsSession => 'Voltar encerrará a sessão atual.';

  @override
  String get stop => 'Encerrar';

  @override
  String get tapCardToStartSession => 'Toque no cartão para iniciar a sessão';

  @override
  String get newPreset => 'Novo preset';

  @override
  String get editPreset => 'Editar preset';

  @override
  String get deletePreset => 'Excluir preset';

  @override
  String get addAtLeastOneStep => 'Adicione pelo menos uma etapa com duração.';

  @override
  String get preStart => 'Pré-início';

  @override
  String get zazen => 'Zazen';

  @override
  String get kinhin => 'Kinhin';

  @override
  String get duration => 'Duração';

  @override
  String get setDuration => 'Definir duração';

  @override
  String get addStep => 'Adicionar etapa';

  @override
  String get savePreset => 'Salvar preset';

  @override
  String get confirm => 'Confirmar';

  @override
  String get untilStart => 'Até começar';

  @override
  String minutesTotal(int count) {
    return '$count min no total';
  }

  @override
  String get session => 'Sessão';

  @override
  String presetNameWithTotal(String breakdown, int total) {
    return '$breakdown ($total min no total)';
  }
}
