import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logger/app_logger.dart';

class ThemeViewModel extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? true;
      notifyListeners();
    } catch (e) {
      const AppLogger('ThemeViewModel').error('load failed', e);
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      const AppLogger('ThemeViewModel').error('toggleTheme persist failed', e);
    }
  }
}
