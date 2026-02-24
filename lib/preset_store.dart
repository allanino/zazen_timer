import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class PresetStore {
  static const String _key = 'session_presets';

  Future<List<SessionPreset>> loadPresets() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null) return <SessionPreset>[];

    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map<SessionPreset>(
          (dynamic item) =>
              SessionPreset.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> savePresets(List<SessionPreset> presets) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(
      presets.map<Map<String, dynamic>>((SessionPreset p) => p.toJson()).toList(),
    );
    await prefs.setString(_key, raw);
  }
}

