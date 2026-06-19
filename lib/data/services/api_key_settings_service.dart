import 'package:shared_preferences/shared_preferences.dart';

/// Persiste chaves de API (TMDB v3) em SharedPreferences.
class ApiKeySettingsService {
  static const String _tmdbApiKeyPref = 'tmdb_api_key';

  Future<String?> getTmdbApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_tmdbApiKeyPref);
    if (key == null || key.isEmpty) return null;
    return key;
  }

  Future<void> setTmdbApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tmdbApiKeyPref, key);
  }

  Future<void> clearTmdbApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tmdbApiKeyPref);
  }

  Future<bool> isTmdbConfigured() async {
    final key = await getTmdbApiKey();
    return key != null && key.isNotEmpty;
  }
}
