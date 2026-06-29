import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Pré-carrega imagens em background para o cache de disco do
/// `cached_network_image`, aquecendo o cache antes que o usuário
/// role a tela e veja os cards.
///
/// Usa o `DefaultCacheManager` global (configurado em `app.dart` como
/// `AuthenticatedCacheManager`) — o mesmo que os `CachedNetworkImage`
/// widgets usam. Assim, as imagens já estão em disco quando o card
/// renderiza, eliminando o delay de download.
///
/// **Como usar:** chame `ImagePrecacheService.prefetchImages(urls)` após
/// carregar os dados da home (ex: `HomeViewModel.loadHomeData()`).
/// O método é fire-and-forget — não bloqueia a UI.
class ImagePrecacheService {
  ImagePrecacheService._();

  /// Conjunto de URLs já enviadas para prefetch (evita re-download).
  static final Set<String> _prefetched = {};

  /// Número máximo de imagens para prefetch por chamada.
  /// Limita o consumo de rede em dispositivos móveis.
  static const int _maxBatchSize = 30;

  /// Pré-carrega [urls] no cache de disco, de forma assíncrona.
  ///
  /// URLs vazias, duplicadas ou já prefetched são ignoradas.
  /// O download é fire-and-forget — erros são silenciosamente
  /// ignorados (a imagem simplesmente será baixada mais tarde
  /// quando o widget `CachedNetworkImage` renderizar).
  static void prefetchImages(Iterable<String> urls) {
    final unique = <String>{};
    for (final url in urls) {
      if (url.isEmpty || _prefetched.contains(url)) continue;
      if (unique.length >= _maxBatchSize) break;
      unique.add(url);
    }

    if (unique.isEmpty) return;

    _prefetched.addAll(unique);
    _doPrefetch(unique.toList());
  }

  /// Executa o download de uma URL em background, ignorando o resultado.
  /// Erros são logados via debugPrint mas nunca propagados.
  static void _doPrefetch(List<String> urls) {
    final cm = CachedNetworkImageProvider.defaultCacheManager;
    for (final url in urls) {
      _fetchIgnoringErrors(cm, url);
    }
  }

  /// Fire-and-forget: encadeia `.then((_) {})` para converter
  /// `Future<File>` em `Future<void>` antes do `catchError`,
  /// evitando warning de tipo de retorno (`FutureOr<File>` vs void).
  static void _fetchIgnoringErrors(BaseCacheManager cm, String url) {
    cm.getSingleFile(url).then((_) {}).catchError((Object err) {
      debugPrint('[ImagePrecache] Erro ao prefetch $url: $err');
    });
  }

  /// Limpa o registro de URLs já prefetched.
  /// Útil para testes ou quando o usuário faz forceRefresh.
  static void clearHistory() {
    _prefetched.clear();
  }
}
