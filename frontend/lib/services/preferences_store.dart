import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

/// Persists the user's preferences locally so onboarding only happens once
/// and settings survive an app restart.
class PreferencesStore {
  static const _key = 'user_preferences_v1';

  static Future<UserPreferences?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return UserPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(preferences.toJson()));
  }
}
