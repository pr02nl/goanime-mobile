import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleViewModel extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  Locale _locale = const Locale('pt', 'BR');
  bool _initialized = false;

  Locale get locale => _locale;
  bool get isReady => _initialized;

  Future<void> load() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_localeKey);
      if (languageCode == 'pt') {
        _locale = const Locale('pt', 'BR');
      } else if (languageCode == 'en') {
        _locale = const Locale('en', 'US');
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[LocaleViewModel] load failed: $e');
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
      debugPrint('[LocaleViewModel] setLocale failed: $e');
    }
  }

  Future<void> setEnglish() async => setLocale(const Locale('en', 'US'));
  Future<void> setPortuguese() async => setLocale(const Locale('pt', 'BR'));

  bool get isEnglish => _locale.languageCode == 'en';
  bool get isPortuguese => _locale.languageCode == 'pt';
}
