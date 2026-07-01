import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/introdb_models.dart';

/// Service de consulta à API pública do TheIntroDB.
///
/// **Não requer API Key para leitura** (`GET /v1/media`). A API retorna
/// timestamps de segmentos (intro, créditos, recap, preview) para filmes
/// e episódios de TV identificados por `tmdbId`.
///
/// ## Uso
///
/// ```dart
/// final segments = await IntroDbService.getMedia(
///   tmdbId: 12345,
/// );
/// ```
///
/// Para TV:
/// ```dart
/// final segments = await IntroDbService.getMedia(
///   tmdbId: 67890,
///   season: 1,
///   episode: 3,
/// );
/// ```
///
/// ## Cache LRU
///
/// Cacheia respostas por 60 minutos (TTL). Limite de 100 entradas.
/// Os timestamps de intro/outro são estáveis e não mudam entre sessões.
class IntroDbService {
  static const String baseUrl = ApiConstants.introdbBaseUrl;

  // ─── Cache LRU ───────────────────────────────────────────────────

  /// Limite máximo de medias com segmentos cacheados.
  static const int _maxCacheEntries = 100;

  /// TTL do cache: 60 minutos.
  static const Duration _cacheTtl = Duration(minutes: 60);

  /// Cache de segmentos por chave composta `tmdbId|season|episode`.
  static final Map<String, IntroDbResponse> _cache = {};

  /// Timestamps de quando cada entrada foi criada.
  static final Map<String, DateTime> _cacheTimestamps = {};

  /// Ordem de acesso LRU (mais antigo no início).
  static final List<String> _cacheOrder = [];

  static bool _isCacheExpired(String key) {
    final cachedAt = _cacheTimestamps[key];
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt) > _cacheTtl;
  }

  static void _touchCache(String key) {
    _cacheOrder.remove(key);
    _cacheOrder.add(key);
  }

  static void _evictOldest() {
    while (_cache.length > _maxCacheEntries && _cacheOrder.isNotEmpty) {
      final oldest = _cacheOrder.removeAt(0);
      _cache.remove(oldest);
      _cacheTimestamps.remove(oldest);
    }
  }

  /// Limpa todo o cache.
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    _cacheOrder.clear();
  }

  /// Constrói a chave de cache composta.
  static String _buildCacheKey({
    required int tmdbId,
    int? season,
    int? episode,
  }) => '$tmdbId|${season ?? ''}|${episode ?? ''}';

  // ─── API pública ─────────────────────────────────────────────────

  /// Busca segmentos de intro/outro para um media.
  ///
  /// [tmdbId] é obrigatório (TMDB ID do filme ou série).
  /// [season] e [episode] são opcionais — quando ambos fornecidos, a
  /// consulta é para um episódio específico de série. Quando omitidos,
  /// a consulta é para um filme.
  ///
  /// Retorna um [IntroDbResponse] ou `null` se a API retornar erro/404.
  static Future<IntroDbResponse?> getMedia({
    required int tmdbId,
    int? season,
    int? episode,
  }) async {
    final cacheKey = _buildCacheKey(
      tmdbId: tmdbId,
      season: season,
      episode: episode,
    );

    // Cache hit?
    if (_cache.containsKey(cacheKey)) {
      if (_isCacheExpired(cacheKey)) {
        _cache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
        _cacheOrder.remove(cacheKey);
      } else {
        _touchCache(cacheKey);
        debugPrint(
          '[IntroDb] ✅ Cache hit for tmdbId=$tmdbId '
          'season=$season episode=$episode',
        );
        return _cache[cacheKey];
      }
    }

    // Cache miss → HTTP request
    try {
      final queryParams = <String, String>{'tmdb_id': tmdbId.toString()};
      if (season != null) queryParams['season'] = season.toString();
      if (episode != null) queryParams['episode'] = episode.toString();

      final uri = Uri.https('api.theintrodb.org', '/v3/media', queryParams);

      debugPrint('[IntroDb] 🌐 GET $uri');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[IntroDb] ⏱️ Request timeout after 10s');
              throw TimeoutException('IntroDB request timeout');
            },
          );

      debugPrint('[IntroDb] 📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final result = IntroDbResponse.fromJson(jsonData);

        // Armazena no cache (mesmo que vazio — evita re-consultas).
        _cache[cacheKey] = result;
        _cacheTimestamps[cacheKey] = DateTime.now();
        _touchCache(cacheKey);
        _evictOldest();

        debugPrint(
          '[IntroDb] ✅ Loaded: intro=${result.intro.length}, '
          'credits=${result.credits.length}',
        );
        return result;
      } else if (response.statusCode == 404) {
        debugPrint('[IntroDb] 404 - No segments for tmdbId=$tmdbId');
        // Cache o resultado vazio.
        final empty = IntroDbResponse(
          intro: [],
          credits: [],
          recap: [],
          preview: [],
        );
        _cache[cacheKey] = empty;
        _cacheTimestamps[cacheKey] = DateTime.now();
        _touchCache(cacheKey);
        _evictOldest();
        return empty;
      } else {
        debugPrint('[IntroDb] ❌ HTTP ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      // Timeout já logado acima.
    } catch (e) {
      debugPrint('[IntroDb] ❌ Exception: $e');
    }

    return null;
  }
}
