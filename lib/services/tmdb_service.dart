import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/tmdb_models.dart';
import 'api_key_settings_service.dart';

/// Cache entry simples com expiração.
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 30;
}

/// Cliente para a API v3 do The Movie Database.
///
/// - `apiKey` carregado via [setApiKey] (em memória) ou [configureFromSettings]
///   (persiste no boot usando [ApiKeySettingsService]).
/// - Cache em memória (30 min) por query.
/// - Throttle de 25 req/s (limite TMDB é 50 req/s, deixamos margem).
class TmdbService {
  static const String baseUrl = 'https://api.themoviedb.org/3';

  static final TmdbService _instance = TmdbService._internal();
  factory TmdbService() => _instance;
  TmdbService._internal();

  final ApiKeySettingsService _settings = ApiKeySettingsService();
  final Map<String, _CacheEntry<List<TmdbMovie>>> _searchCache = {};
  final Map<int, _CacheEntry<TmdbMovie>> _detailsCache = {};
  static const int _maxCacheSize = 100;

  String? _apiKey;
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 40);

  String? get apiKey => _apiKey;
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Define a chave de API direto (em memória).
  void setApiKey(String? key) {
    _apiKey = (key != null && key.isNotEmpty) ? key : null;
    debugPrint('[TmdbService] API key ${isConfigured ? 'configured' : 'cleared'}');
  }

  /// Carrega a chave persistida em SharedPreferences no boot do app.
  Future<void> configureFromSettings() async {
    final key = await _settings.getTmdbApiKey();
    setApiKey(key);
  }

  /// Faz match preferencial (exato > contains > primeiro) em uma lista de resultados.
  TmdbMovie? matchInResults(List<TmdbMovie> results, String query) {
    if (results.isEmpty) return null;
    final lower = query.toLowerCase();

    final exact = results.where(
      (m) =>
          m.title.toLowerCase() == lower ||
          (m.originalTitle?.toLowerCase() == lower),
    );
    if (exact.isNotEmpty) return exact.first;

    final contains = results.where(
      (m) =>
          m.title.toLowerCase().contains(lower) ||
          (m.originalTitle?.toLowerCase().contains(lower) ?? false),
    );
    if (contains.isNotEmpty) return contains.first;

    return results.first;
  }

  Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  void _cleanCache() {
    _searchCache.removeWhere((key, entry) => entry.isExpired);
    _detailsCache.removeWhere((key, entry) => entry.isExpired);
    if (_searchCache.length > _maxCacheSize) {
      final keysToRemove = _searchCache.keys
          .take(_searchCache.length - _maxCacheSize)
          .toList();
      for (final key in keysToRemove) {
        _searchCache.remove(key);
      }
    }
  }

  /// Busca filmes pelo título com suporte a filtro de ano.
  Future<List<TmdbMovie>> searchMovies(
    String query, {
    int? year,
    int limit = 5,
  }) async {
    if (!isConfigured) {
      throw Exception(
        'TMDB não configurado. Configure a chave em Configurações.',
      );
    }
    if (query.trim().isEmpty) return [];

    final cacheKey = 'search:${query.toLowerCase()}_${year ?? ''}';
    _cleanCache();
    final cached = _searchCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[TmdbService] Cache hit: $cacheKey');
      return cached.data.take(limit).toList();
    }

    try {
      await _waitForRateLimit();
      final params = <String, String>{
        'api_key': _apiKey!,
        'query': query,
        'language': 'pt-BR',
        'include_adult': 'false',
      };
      if (year != null) {
        params['year'] = year.toString();
      }
      final uri = Uri.parse('$baseUrl/search/movie')
          .replace(queryParameters: params);

      debugPrint('[TmdbService] GET $uri');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        debugPrint('[TmdbService] 401 Unauthorized');
        throw Exception(
          'Chave da API do TMDB inválida. Reconfigure em Configurações.',
        );
      }
      if (response.statusCode != 200) {
        debugPrint(
          '[TmdbService] Error ${response.statusCode}: ${response.body}',
        );
        throw Exception('TMDB retornou ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = TmdbSearchResponse.fromJson(body);
      _searchCache[cacheKey] = _CacheEntry(parsed.results);
      return parsed.results.take(limit).toList();
    } catch (e) {
      debugPrint('[TmdbService] searchMovies error: $e');
      rethrow;
    }
  }

  /// Detalhes de um filme específico por TMDB ID.
  Future<TmdbMovie?> getMovieDetails(int tmdbId) async {
    if (!isConfigured) return null;

    _cleanCache();
    final cached = _detailsCache[tmdbId];
    if (cached != null && !cached.isExpired) {
      debugPrint('[TmdbService] Cache hit details: $tmdbId');
      return cached.data;
    }

    try {
      await _waitForRateLimit();
      final uri = Uri.parse('$baseUrl/movie/$tmdbId').replace(queryParameters: {
        'api_key': _apiKey!,
        'language': 'pt-BR',
      });

      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        throw Exception('API key inválida');
      }
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final movie = TmdbMovie.fromJson(body);
      _detailsCache[tmdbId] = _CacheEntry(movie);
      return movie;
    } catch (e) {
      debugPrint('[TmdbService] getMovieDetails error: $e');
      return null;
    }
  }
}
