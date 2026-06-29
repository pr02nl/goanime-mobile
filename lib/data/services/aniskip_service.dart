import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/aniskip_models.dart';

class AniSkipService {
  static const String baseUrl = ApiConstants.aniskipBaseUrl;

  // ─── Cache LRU ───────────────────────────────────────────────────

  /// Limite máximo de episódios com skip times cacheados.
  static const int _maxCacheEntries = 50;

  /// TTL do cache de skip times: 60 minutos.
  /// Os metadados de skip (intro/outro) são estáveis e não mudam entre
  /// sessões — TTL longo evita chamadas HTTP desnecessárias.
  static const Duration _cacheTtl = Duration(minutes: 60);

  /// Cache de skip times por chave composta `malId|anilistId|epNumber`.
  static final Map<String, SkipTimes> _skipTimesCache = {};

  /// Timestamps de quando cada entrada foi criada.
  static final Map<String, DateTime> _cacheTimestamps = {};

  /// Ordem de acesso LRU (mais antigo no início).
  static final List<String> _cacheOrder = [];

  /// `true` se a entrada do cache para [key] expirou (TTL).
  static bool _isCacheExpired(String key) {
    final cachedAt = _cacheTimestamps[key];
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt) > _cacheTtl;
  }

  /// Move a chave para o fim da ordem LRU.
  static void _touchCache(String key) {
    _cacheOrder.remove(key);
    _cacheOrder.add(key);
  }

  /// Remove a entrada mais antiga se exceder o limite.
  static void _evictOldest() {
    while (_skipTimesCache.length > _maxCacheEntries &&
        _cacheOrder.isNotEmpty) {
      final oldest = _cacheOrder.removeAt(0);
      _skipTimesCache.remove(oldest);
      _cacheTimestamps.remove(oldest);
    }
  }

  /// Constrói a chave de cache composta.
  static String _buildCacheKey({
    int? malId,
    int? anilistId,
    required int episodeNumber,
  }) => '${malId ?? ''}|${anilistId ?? ''}|$episodeNumber';

  /// Limpa todo o cache de skip times.
  static void clearSkipTimesCache() {
    _skipTimesCache.clear();
    _cacheTimestamps.clear();
    _cacheOrder.clear();
  }

  /// Verifica se o cache tem uma entrada válida para esta combinação
  /// de IDs + episódio. Retorna o valor cacheado ou `null`.
  static SkipTimes? _getFromCache({
    int? malId,
    int? anilistId,
    required int episodeNumber,
  }) {
    // Tenta com malId primeiro (se existir), depois com anilistId.
    for (final id in [malId, anilistId]) {
      if (id == null) continue;
      final key = _buildCacheKey(
        malId: malId == id ? malId : null,
        anilistId: anilistId == id ? anilistId : null,
        episodeNumber: episodeNumber,
      );
      if (_skipTimesCache.containsKey(key)) {
        if (_isCacheExpired(key)) {
          _skipTimesCache.remove(key);
          _cacheTimestamps.remove(key);
          _cacheOrder.remove(key);
          return null;
        }
        _touchCache(key);
        return _skipTimesCache[key];
      }
    }
    return null;
  }

  /// Armazena o resultado no cache LRU.
  static void _storeInCache({
    int? malId,
    int? anilistId,
    required int episodeNumber,
    required SkipTimes skipTimes,
  }) {
    // Escolhe o ID que foi usado para a consulta bem-sucedida.
    // Se ambos foram tentados, prefere malId.
    final id = malId ?? anilistId;
    if (id == null) return;

    final key = _buildCacheKey(
      malId: malId,
      anilistId: anilistId,
      episodeNumber: episodeNumber,
    );
    _skipTimesCache[key] = skipTimes;
    _cacheTimestamps[key] = DateTime.now();
    _touchCache(key);
    _evictOldest();
  }

  /// Fetches skip times data trying multiple strategies
  /// 1. Try with MAL ID if available
  /// 2. Try with AniList ID if MAL ID fails
  static Future<SkipTimes> getSkipTimesMultiStrategy({
    int? malId,
    int? anilistId,
    required int episodeNumber,
    int? episodeLengthSeconds,
  }) async {
    if (episodeLengthSeconds == null || episodeLengthSeconds <= 0) {
      debugPrint(
        '[AniSkip] ⚠️  Invalid episode length provided to service: '
        '$episodeLengthSeconds. Skipping API call.',
      );
      return SkipTimes.empty();
    }

    // Cache check: verifica se já temos skip times para este episódio.
    final cached = _getFromCache(
      malId: malId,
      anilistId: anilistId,
      episodeNumber: episodeNumber,
    );
    if (cached != null) {
      debugPrint(
        '[AniSkip] ✅ Cache hit for episode $episodeNumber'
        ' (${cached.hasSkipTimes ? 'with skip times' : 'no skip times'})',
      );
      return cached;
    }

    // Strategy 1: Try MAL ID first
    if (malId != null) {
      debugPrint('[AniSkip] 🎯 Strategy 1: Trying with MAL ID: $malId');
      final result = await _fetchSkipTimes(
        animeId: malId,
        episodeNumber: episodeNumber,
        idType: 'MAL',
        episodeLengthSeconds: episodeLengthSeconds,
      );
      if (result.hasSkipTimes) {
        _storeInCache(
          malId: malId,
          anilistId: anilistId,
          episodeNumber: episodeNumber,
          skipTimes: result,
        );
        return result;
      }
    }

    // Strategy 2: Try AniList ID
    if (anilistId != null) {
      debugPrint('[AniSkip] 🎯 Strategy 2: Trying with AniList ID: $anilistId');
      final result = await _fetchSkipTimes(
        animeId: anilistId,
        episodeNumber: episodeNumber,
        idType: 'AniList',
        episodeLengthSeconds: episodeLengthSeconds,
      );
      if (result.hasSkipTimes) {
        _storeInCache(
          malId: malId,
          anilistId: anilistId,
          episodeNumber: episodeNumber,
          skipTimes: result,
        );
        return result;
      }
    }

    debugPrint('[AniSkip] ❌ No skip times found with any strategy');
    // Cache também o resultado vazio para evitar re-consultas.
    _storeInCache(
      malId: malId,
      anilistId: anilistId,
      episodeNumber: episodeNumber,
      skipTimes: SkipTimes.empty(),
    );
    return SkipTimes.empty();
  }

  /// Fetches skip times data for a given anime ID and episode number
  static Future<SkipTimes> _fetchSkipTimes({
    required int animeId,
    required int episodeNumber,
    required String idType,
    required int episodeLengthSeconds,
  }) async {
    try {
      // Build URL - AniSkip API expects types as array parameters
      // Format: ?types[]=op&types[]=ed
      final uri = Uri.https(
        'api.aniskip.com',
        '/v2/skip-times/$animeId/$episodeNumber',
        {
          'types[]': ['op', 'ed'],
          'episodeLength': episodeLengthSeconds.toString(),
        },
      );

      debugPrint('[AniSkip API] 🌐 Request ($idType): $uri');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[AniSkip API] ⏱️  Request timeout after 10s');
              throw Exception('Request timeout');
            },
          );

      debugPrint('[AniSkip API] 📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('[AniSkip API] 📄 Response body: ${response.body}');
        final jsonData = json.decode(response.body);
        final skipResponse = SkipTimesResponse.fromJson(jsonData);

        if (skipResponse.found) {
          debugPrint(
            '[AniSkip API] ✅ Found ${skipResponse.results.length} skip time(s) using $idType ID',
          );
          return skipResponse.toSkipTimes();
        } else {
          debugPrint(
            '[AniSkip API] ℹ️  API returned found=false for $idType ID',
          );
        }
      } else if (response.statusCode == 404) {
        debugPrint(
          '[AniSkip API] 404 - No skip times found for $idType ID: $animeId',
        );
        return SkipTimes.empty();
      } else {
        debugPrint(
          '[AniSkip API] ❌ Request failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[AniSkip API] ❌ Exception with $idType ID: $e');
    }

    return SkipTimes.empty();
  }

  /// Rounds a time value to the specified precision
  static double roundTime(double timeValue, int precision) {
    final multiplier = 1.0 * (10 ^ precision);
    return (timeValue * multiplier).round() / multiplier;
  }
}
