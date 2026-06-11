import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utilitário para detectar se o aplicativo está rodando em uma TV
class TVDetector {
  static bool? _isTV;

  /// Verifica se o dispositivo é uma TV baseado em vários critérios
  static bool get isTV {
    if (_isTV != null) return _isTV!;

    // Verifica se é Android TV (Leanback)
    if (Platform.isAndroid) {
      // Verifica UI mode
      // Em uma TV real, podemos verificar via platform channel
      // Por enquanto, usamos heurísticas
      _isTV = _detectTVHeuristically();
    } else {
      _isTV = false;
    }

    return _isTV!;
  }

  /// Detecção heurística baseada em características do dispositivo
  static bool _detectTVHeuristically() {
    // TVs geralmente têm telas grandes e densidade baixa
    // Esta é uma detecção simplificada
    return false; // Retorna false por padrão, pode ser sobrescrito via settings
  }

  /// Força o modo TV (útil para testes ou configurações manuais)
  static void forceTVMode(bool value) {
    _isTV = value;
  }
}

/// Extensão para verificar se é TV em BuildContext
extension TVContextExtension on BuildContext {
  bool get isTV => TVDetector.isTV;

  /// Retorna o padding adequado para TV ou mobile
  EdgeInsets get adaptivePadding {
    if (isTV) {
      return const EdgeInsets.all(24.0);
    }
    return const EdgeInsets.all(16.0);
  }

  /// Retorna o tamanho de fonte escalado para TV
  double get adaptiveFontScale => isTV ? 1.3 : 1.0;

  /// Retorna o tamanho do card escalado para TV
  double get adaptiveCardScale => isTV ? 1.4 : 1.0;
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
