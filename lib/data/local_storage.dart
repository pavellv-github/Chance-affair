import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';
import '../domain/user_profile.dart';

/// Хранит профиль и настройки локально на устройстве.
class LocalStorage {
  LocalStorage(this._prefs);

  static const _profileKey = 'user_profile_v1';
  static const _settingsKey = 'app_settings_v1';

  final SharedPreferences _prefs;

  UserProfile loadProfile() =>
      _read(_profileKey, UserProfile.fromJson) ?? UserProfile.empty;

  Future<void> saveProfile(UserProfile profile) =>
      _prefs.setString(_profileKey, jsonEncode(profile.toJson()));

  AppSettings loadSettings() =>
      _read(_settingsKey, AppSettings.fromJson) ?? AppSettings.defaults;

  Future<void> saveSettings(AppSettings settings) =>
      _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

  T? _read<T>(String key, T Function(Map<String, Object?>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      // Повреждённые данные не должны ронять приложение.
      return null;
    }
  }
}
