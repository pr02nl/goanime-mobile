import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  Locale _locale = const Locale('en', 'US');
  bool _initialized = false;

  Locale get locale => _locale;
  bool get isReady => _initialized;

  LocaleService();

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_localeKey);
      if (languageCode == 'pt') {
        _locale = const Locale('pt', 'BR');
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[LocaleService] init failed: $e');
      _initialized = true;
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (e) {
      debugPrint('[LocaleService] setLocale failed: $e');
    }
  }

  Future<void> setEnglish() async {
    await setLocale(const Locale('en', 'US'));
  }

  Future<void> setPortuguese() async {
    await setLocale(const Locale('pt', 'BR'));
  }

  bool get isEnglish => _locale.languageCode == 'en';
  bool get isPortuguese => _locale.languageCode == 'pt';
}
