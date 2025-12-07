import 'package:flutter/rendering.dart';

/// Configurações de performance para o app
/// Mantém o visual atual mas otimiza por baixo dos panos
class PerformanceConfig {
  PerformanceConfig._();

  /// Inicializa configurações de performance
  static void init() {
    // Aumenta o limite de cache de imagens para 200MB
    PaintingBinding.instance.imageCache.maximumSize = 500;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200MB
  }

  /// Limpa cache de imagens se necessário (para liberar memória)
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Configurações de scroll otimizadas
  static const double scrollCacheExtent = 500.0;
  
  /// Duração padrão para animações rápidas
  static const Duration fastAnimation = Duration(milliseconds: 150);
  
  /// Duração padrão para animações médias
  static const Duration mediumAnimation = Duration(milliseconds: 250);
  
  /// Duração padrão para animações lentas
  static const Duration slowAnimation = Duration(milliseconds: 400);

  /// Configurações de imagem para diferentes contextos
  static const int thumbnailCacheMultiplier = 2;
  static const int bannerCacheMultiplier = 1; // Banners são grandes, cache menor
  
  /// Limites de memória para listas
  static const int maxVisibleCards = 10;
  static const int preloadCards = 3;
}
