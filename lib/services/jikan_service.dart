import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/jikan_models.dart';

/// Cache entry com timestamp para expiração
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 30;
}

/// Resultado do carregamento da Home com todos os dados
class HomeData {
  final List<JikanAnime> seasonAnimes;
  final List<JikanAnime> topAnimes;
  final List<JikanAnime> actionAnimes;
  final List<JikanAnime> romanceAnimes;
  final List<JikanAnime> comedyAnimes;
  final List<JikanAnime> fantasyAnimes;
  final DateTime loadedAt;

  HomeData({
    required this.seasonAnimes,
    required this.topAnimes,
    required this.actionAnimes,
    required this.romanceAnimes,
    required this.comedyAnimes,
    required this.fantasyAnimes,
  }) : loadedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(loadedAt).inMinutes > 30;

  /// Serializa para JSON para persistência
  Map<String, dynamic> toJson() => {
    'seasonAnimes': seasonAnimes.map((a) => a.toJson()).toList(),
    'topAnimes': topAnimes.map((a) => a.toJson()).toList(),
    'actionAnimes': actionAnimes.map((a) => a.toJson()).toList(),
    'romanceAnimes': romanceAnimes.map((a) => a.toJson()).toList(),
    'comedyAnimes': comedyAnimes.map((a) => a.toJson()).toList(),
    'fantasyAnimes': fantasyAnimes.map((a) => a.toJson()).toList(),
    'loadedAt': loadedAt.toIso8601String(),
  };

  /// Deserializa do JSON
  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      seasonAnimes: (json['seasonAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      topAnimes: (json['topAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      actionAnimes: (json['actionAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      romanceAnimes: (json['romanceAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      comedyAnimes: (json['comedyAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
      fantasyAnimes: (json['fantasyAnimes'] as List? ?? [])
          .map((j) => JikanAnime.fromJson(j))
          .toList(),
    );
  }
}

class JikanService {
  static const String baseUrl = 'https://api.jikan.moe/v4';
  static const String _homeDataCacheKey = 'jikan_home_data_cache';

  // Cache em memória singleton para toda a app
  static HomeData? _homeDataCache;
  static final Map<String, _CacheEntry<List<JikanAnime>>> _cache = {};
  static const int _maxCacheSize = 50;
  static bool _isLoadingHome = false;

  /// Limpa cache expirado
  static void _cleanExpiredCache() {
    _cache.removeWhere((key, entry) => entry.isExpired);
    if (_cache.length > _maxCacheSize) {
      final keysToRemove = _cache.keys
          .take(_cache.length - _maxCacheSize)
          .toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }
  }

  /// Obtém do cache se disponível e não expirado
  List<JikanAnime>? _getFromCache(String key) {
    _cleanExpiredCache();
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      debugPrint('[JikanService] Cache hit: $key');
      return entry.data;
    }
    return null;
  }

  /// Salva no cache
  void _saveToCache(String key, List<JikanAnime> data) {
    _cache[key] = _CacheEntry(data);
  }

  /// Carrega cache persistente do SharedPreferences
  Future<HomeData?> _loadPersistedHomeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_homeDataCacheKey);
      if (jsonStr != null) {
        final data = HomeData.fromJson(json.decode(jsonStr));
        if (!data.isExpired) {
          debugPrint('[JikanService] Loaded home data from persistent cache');
          return data;
        }
      }
    } catch (e) {
      debugPrint('[JikanService] Error loading persisted cache: $e');
    }
    return null;
  }

  /// Salva cache persistente no SharedPreferences
  Future<void> _persistHomeData(HomeData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_homeDataCacheKey, json.encode(data.toJson()));
      debugPrint('[JikanService] Home data persisted to cache');
    } catch (e) {
      debugPrint('[JikanService] Error persisting cache: $e');
    }
  }

  /// MÉTODO PRINCIPAL: Carrega TODOS os dados da Home de uma vez
  /// Usa paralelo controlado para buscar tudo rapidamente
  /// Retorna cache se disponível, senão busca da API
  Future<HomeData> loadHomeData({bool forceRefresh = false}) async {
    // Retorna cache em memória se disponível
    if (!forceRefresh && _homeDataCache != null && !_homeDataCache!.isExpired) {
      debugPrint('[JikanService] Returning memory cached home data');
      return _homeDataCache!;
    }

    // Evita múltiplas requisições simultâneas
    if (_isLoadingHome) {
      debugPrint('[JikanService] Already loading, waiting...');
      // Espera o carregamento terminar
      while (_isLoadingHome) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_homeDataCache != null) return _homeDataCache!;
    }

    // Tenta carregar do cache persistente primeiro
    if (!forceRefresh) {
      final persisted = await _loadPersistedHomeData();
      if (persisted != null) {
        _homeDataCache = persisted;
        return persisted;
      }
    }

    _isLoadingHome = true;
    debugPrint('[JikanService] Loading all home data in parallel...');

    try {
      // Busca todos os dados em PARALELO (máximo 3 por segundo da API)
      // Dividimos em 2 batches para respeitar rate limit
      final stopwatch = Stopwatch()..start();

      // Batch 1: Season + Top + Action (3 requisições)
      final batch1 = await Future.wait([
        _fetchWithRetry('$baseUrl/seasons/now?limit=15'),
        _fetchWithRetry('$baseUrl/top/anime?limit=15'),
        _fetchWithRetry(
          '$baseUrl/anime?genres=${JikanGenreIds.action}&limit=15&order_by=score&sort=desc',
        ),
      ]);

      // Pequena pausa para rate limit
      await Future.delayed(const Duration(milliseconds: 400));

      // Batch 2: Romance + Comedy + Fantasy (3 requisições)
      final batch2 = await Future.wait([
        _fetchWithRetry(
          '$baseUrl/anime?genres=${JikanGenreIds.romance}&limit=15&order_by=score&sort=desc',
        ),
        _fetchWithRetry(
          '$baseUrl/anime?genres=${JikanGenreIds.comedy}&limit=15&order_by=score&sort=desc',
        ),
        _fetchWithRetry(
          '$baseUrl/anime?genres=${JikanGenreIds.fantasy}&limit=15&order_by=score&sort=desc',
        ),
      ]);

      stopwatch.stop();
      debugPrint(
        '[JikanService] All data loaded in ${stopwatch.elapsedMilliseconds}ms',
      );

      final homeData = HomeData(
        seasonAnimes: _parseAnimeList(batch1[0]),
        topAnimes: _parseAnimeList(batch1[1]),
        actionAnimes: _parseAnimeList(batch1[2]),
        romanceAnimes: _parseAnimeList(batch2[0]),
        comedyAnimes: _parseAnimeList(batch2[1]),
        fantasyAnimes: _parseAnimeList(batch2[2]),
      );

      // Salva em memória e persistente
      _homeDataCache = homeData;
      _persistHomeData(homeData);

      return homeData;
    } catch (e) {
      debugPrint('[JikanService] Error loading home data: $e');
      // Retorna dados vazios em caso de erro
      return HomeData(
        seasonAnimes: [],
        topAnimes: [],
        actionAnimes: [],
        romanceAnimes: [],
        comedyAnimes: [],
        fantasyAnimes: [],
      );
    } finally {
      _isLoadingHome = false;
    }
  }

  /// Faz requisição HTTP com retry automático
  Future<http.Response> _fetchWithRetry(
    String url, {
    int maxRetries = 2,
  }) async {
    for (int i = 0; i <= maxRetries; i++) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          return response;
        } else if (response.statusCode == 429 && i < maxRetries) {
          // Rate limited, espera e tenta novamente
          debugPrint('[JikanService] Rate limited, retrying in 1s...');
          await Future.delayed(const Duration(seconds: 1));
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (i == maxRetries) rethrow;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    throw Exception('Max retries exceeded');
  }

  /// Parse da lista de animes de uma resposta HTTP
  List<JikanAnime> _parseAnimeList(http.Response response) {
    try {
      final jsonData = json.decode(response.body);
      final jikanResponse = JikanResponse<JikanAnime>.fromJson(
        jsonData,
        (json) => JikanAnime.fromJson(json),
      );
      return jikanResponse.data;
    } catch (e) {
      debugPrint('[JikanService] Error parsing anime list: $e');
      return [];
    }
  }

  // Rate limiting para métodos individuais
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 400);

  /// Aguarda o intervalo mínimo entre requisições
  Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Métodos individuais (usados pela SearchScreen e outras telas)

  /// Busca os top animes
  Future<List<JikanAnime>> getTopAnimes({int page = 1, int limit = 20}) async {
    final cacheKey = 'top_${page}_$limit';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/top/anime?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final result = _parseAnimeList(response);
        _saveToCache(cacheKey, result);
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching top animes: $e');
      return [];
    }
  }

  /// Busca animes da temporada atual
  Future<List<JikanAnime>> getCurrentSeasonAnimes({
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = 'season_${page}_$limit';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/seasons/now?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final result = _parseAnimeList(response);
        _saveToCache(cacheKey, result);
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching current season animes: $e');
      return [];
    }
  }

  /// Busca animes por gênero
  /// Gêneros disponíveis:
  /// - Action: 1
  /// - Adventure: 2
  /// - Comedy: 4
  /// - Drama: 8
  /// - Fantasy: 10
  /// - Horror: 14
  /// - Mystery: 7
  /// - Romance: 22
  /// - Sci-Fi: 24
  /// - Slice of Life: 36
  /// - Sports: 30
  /// - Supernatural: 37
  Future<List<JikanAnime>> getAnimesByGenre(
    int genreId, {
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = 'genre_${genreId}_${page}_$limit';
    final cached = _getFromCache(cacheKey);
    if (cached != null) return cached;

    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/anime?genres=$genreId&page=$page&limit=$limit&order_by=score&sort=desc',
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        _saveToCache(cacheKey, jikanResponse.data);
        return jikanResponse.data;
      } else {
        throw Exception(
          'Failed to load animes by genre: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching animes by genre: $e');
      return [];
    }
  }

  /// Busca animes populares (ordenados por membros)
  Future<List<JikanAnime>> getPopularAnimes({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/anime?order_by=members&sort=desc&page=$page&limit=$limit',
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception(
          'Failed to load popular animes: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching popular animes: $e');
      return [];
    }
  }

  /// Busca animes em exibição
  Future<List<JikanAnime>> getAiringAnimes({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/anime?status=airing&order_by=score&sort=desc&page=$page&limit=$limit',
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception('Failed to load airing animes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching airing animes: $e');
      return [];
    }
  }

  /// Busca recomendações de animes
  Future<List<JikanAnime>> getRecommendedAnimes({int page = 1}) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/recommendations/anime?page=$page'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> data = jsonData['data'] ?? [];

        // Extrai animes das recomendações
        final List<JikanAnime> animes = [];
        for (var item in data.take(20)) {
          if (item['entry'] != null && item['entry'].isNotEmpty) {
            for (var entry in item['entry']) {
              try {
                animes.add(JikanAnime.fromJson(entry));
              } catch (e) {
                debugPrint('Error parsing recommendation entry: $e');
              }
            }
          }
        }

        // Remove duplicatas
        final uniqueAnimes = <int, JikanAnime>{};
        for (var anime in animes) {
          uniqueAnimes[anime.malId] = anime;
        }

        return uniqueAnimes.values.toList();
      } else {
        throw Exception(
          'Failed to load recommended animes: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching recommended animes: $e');
      return [];
    }
  }

  /// Busca anime por ID
  Future<JikanAnime?> getAnimeById(int malId) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(Uri.parse('$baseUrl/anime/$malId'));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return JikanAnime.fromJson(jsonData['data']);
      } else {
        throw Exception('Failed to load anime: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching anime by id: $e');
      return null;
    }
  }

  /// Busca animes por termo de pesquisa
  Future<List<JikanAnime>> searchAnimes(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse(
          '$baseUrl/anime?q=${Uri.encodeComponent(query)}&page=$page&limit=$limit',
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception('Failed to search animes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching animes: $e');
      return [];
    }
  }
}

// IDs de gêneros mais populares
class JikanGenreIds {
  static const int action = 1;
  static const int adventure = 2;
  static const int comedy = 4;
  static const int drama = 8;
  static const int fantasy = 10;
  static const int horror = 14;
  static const int mystery = 7;
  static const int romance = 22;
  static const int sciFi = 24;
  static const int sliceOfLife = 36;
  static const int sports = 30;
  static const int supernatural = 37;
}
