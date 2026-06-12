import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utilitário para detectar se o aplicativo está rodando em uma TV
class TVDetector {
  static bool? _isTV;

  /// Verifica se o dispositivo é uma TV baseado em vários critérios
  static Future<bool> get isTV async {
    if (_isTV != null) return _isTV!;

    // Verifica se é Android TV (Leanback)
    if (Platform.isAndroid) {
      // Verifica UI mode via platform channel
      _isTV = await _detectTVMode();
    } else {
      _isTV = false;
    }

    return _isTV!;
  }

  /// Detecta modo TV usando platform channel do Android
  static Future<bool> _detectTVMode() async {
    try {
      // Verifica se o UI_MODE é TV (UI_MODE_TYPE_TELEVISION = 0x04)
      const platform = MethodChannel('com.goanime.tv_detector');
      final bool? isTV = await platform.invokeMethod('isTV');
      return isTV ?? _detectTVFallback();
    } catch (e) {
      return _detectTVFallback();
    }
  }

  /// Detecção fallback baseada em características do dispositivo
  static bool _detectTVFallback() {
    // Verifica se está rodando em emulador de TV
    // Emuladores de TV geralmente têm "tv" no model ou no device
    try {
      final deviceInfo = Platform.environment['ANDROID_MODEL'] ?? '';
      final product = Platform.environment['ANDROID_PRODUCT'] ?? '';

      return deviceInfo.toLowerCase().contains('tv') ||
          product.toLowerCase().contains('tv') ||
          product.toLowerCase().contains('atv'); // Android TV
    } catch (e) {
      return false;
    }
  }

  /// Força o modo TV (útil para testes ou configurações manuais)
  static void forceTVMode(bool value) {
    _isTV = value;
  }
}

/// Extensão para verificar se é TV em BuildContext
extension TVContextExtension on BuildContext {
  Future<bool> get isTV async => await TVDetector.isTV;

  /// Retorna o padding adequado para TV ou mobile
  Future<EdgeInsets> get adaptivePadding async {
    if (await isTV) {
      return const EdgeInsets.all(24.0);
    }
    return const EdgeInsets.all(16.0);
  }

  /// Retorna o tamanho de fonte escalado para TV
  Future<double> get adaptiveFontScale async => (await isTV) ? 1.3 : 1.0;

  /// Retorna o tamanho do card escalado para TV
  Future<double> get adaptiveCardScale async => (await isTV) ? 1.4 : 1.0;
}

/// Mapeamento de teclas para navegação na TV
class TVNavigationKeys {
  static const LogicalKeyboardKey up = LogicalKeyboardKey.arrowUp;
  static const LogicalKeyboardKey down = LogicalKeyboardKey.arrowDown;
  static const LogicalKeyboardKey left = LogicalKeyboardKey.arrowLeft;
  static const LogicalKeyboardKey right = LogicalKeyboardKey.arrowRight;
  static const LogicalKeyboardKey select = LogicalKeyboardKey.select;
  static const LogicalKeyboardKey enter = LogicalKeyboardKey.enter;
  static const LogicalKeyboardKey back = LogicalKeyboardKey.escape;
  static const LogicalKeyboardKey menu = LogicalKeyboardKey.contextMenu;

  /// Verifica se uma tecla é de navegação
  static bool isNavigationKey(LogicalKeyboardKey key) {
    return key == up ||
        key == down ||
        key == left ||
        key == right ||
        key == select ||
        key == enter ||
        key == back ||
        key == menu;
  }
}
