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
      const platform = MethodChannel('com.pauloflix.tv_detector');
      final bool? isTV = await platform.invokeMethod('isTV');
      return isTV ?? _detectTVFallback();
    } catch (e) {
      debugPrint('[TVDetector] Platform channel failed: $e');
      return _detectTVFallback();
    }
  }

  /// Detecção fallback baseada em características do dispositivo
  static bool _detectTVFallback() {
    // Verifica se não há touchscreen como indicativo de TV
    // Em TVs Android reais, a MainActivity nativa já responde via MethodChannel.
    // Este fallback é apenas para casos extremos (ex: emuladores antigos).
    return false;
  }

  /// Força o modo TV (útil para testes ou configurações manuais)
  static void forceTVMode(bool value) {
    _isTV = value;
  }

  /// Acesso síncrono ao valor cacheado. Se `_isTV` ainda não foi
  /// inicializado (primeiro acesso), retorna `false`.
  static bool get isTVSync => _isTV ?? false;
}

/// Extensão para verificar se é TV em BuildContext
extension TVContextExtension on BuildContext {
  Future<bool> get isTV async => await TVDetector.isTV;

  /// Versão síncrona — usa o cache se já inicializado.
  bool get isTVSync => TVDetector.isTVSync;

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
