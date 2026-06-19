import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/tmdb_models.dart';
import 'api_key_settings_service.dart';

/// Cache entry com TTL.
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  _CacheEntry(this.data) : timestamp = DateTime.now();
  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 30;
}

/// Cliente para The Movie Database API v3.
///
/// Segue as recomendações oficiais em
/// https://developer.themoviedb.org/reference/intro/getting-started :
///
/// - Autenticação via Bearer Token (Read Access Token) ou api_key v3.
/// - Headers obrigatórios: `accept: application/json`.
/// - Tratamento granular de erros (401 vs 429 vs outros).
/// - Respeita rate limit: 50 req/s oficial → throttling para 25 req/s.
///
/// Bearer Token é recomendado pela TMDB como método preferencial.
/// api_key v3 também é suportado (legado).
///
/// Esta classe cobre apenas os endpoints usados pela feature PauloFlix
/// Movies. Para feature completa da API, extenda com métodos adicionais.
class TmdbService {
  /// Base URL oficial da API v3 (referenciada pela doc oficial).
  static const String baseUrl = 'https://api.themoviedb.org/3';

  /// ISO 3166-1 alpha-2 do Brasil — região padrão para priorizar resultados.
  static const String regionBR = 'BR';

  static final TmdbService _instance = TmdbService._internal();
  factory TmdbService() => _instance;
  TmdbService._internal();

  final ApiKeySettingsService _settings = ApiKeySettingsService();

  // Caches separados por endpoint para evitar colisões.
  final Map<String, _CacheEntry<TmdbSearchResponse>> _searchCache = {};
  final Map<int, _CacheEntry<TmdbMovie>> _detailsCache = {};
  static const int _maxCacheSize = 100;

  // Rate limiting: TMDB permite até 50 req/s, usamos 25 req/s por margem.
  String? _apiKey;
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 40);

  // Timeout de uma request — doc não especifica, 10s é razoável.
  static const Duration _requestTimeout = Duration(seconds: 10);

  String? get apiKey => _apiKey;
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Configuração
  // ---------------------------------------------------------------------------

  void setApiKey(String? key) {
    _apiKey = (key != null && key.isNotEmpty) ? key : null;
    debugPrint('[Tmdb] API key ${isConfigured ? 'configured' : 'cleared'}');
  }

  Future<void> configureFromSettings() async {
    final key = await _settings.getTmdbApiKey();
    setApiKey(key);
  }

  Future<void> clear() async {
    _searchCache.clear();
    _detailsCache.clear();
    setApiKey(null);
  }

  // ---------------------------------------------------------------------------
  // Headers padrão conforme doc oficial
  // ---------------------------------------------------------------------------

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'accept': 'application/json',
      'content-type': 'application/json',
    };
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      // Bearer Token é o método recomendado pela doc oficial atual.
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    return headers;
  }

  // ---------------------------------------------------------------------------
  // Rate limiting
  // ---------------------------------------------------------------------------

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

  /// Requisição HTTP centralizada — único ponto que conhece a TMDB.
  /// Lança [TmdbException] específicas conforme o status code.
  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    if (!isConfigured) {
      throw const TmdbNotConfiguredException();
    }

    await _waitForRateLimit();

    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParameters);
    debugPrint('[Tmdb] GET $uri');

    final http.Response response;
    try {
      response = await http
          .get(uri, headers: _buildHeaders())
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const TmdbRequestException('Timeout na chamada TMDB');
    } catch (e) {
      throw TmdbRequestException('Erro de rede: $e');
    }

    switch (response.statusCode) {
      case 200:
        final body = jsonDecode(response.body);
        if (body is! Map<String, dynamic>) {
          throw const TmdbRequestException('Resposta TMDB inválida');
        }
        return body;
      case 401:
        // Doc oficial: 401 = Unauthorized (api key inválida ou Bearer
        // Token expirado). Invalida o cache da chave para forçar
        // reconfiguração pelo usuário.
        _apiKey = null;
        debugPrint('[Tmdb] 401 Unauthorized — chave invalidada');
        throw const TmdbAuthException(
          'Chave da API TMDB inválida. Reconfigure em Configurações.',
        );
      case 429:
        // Rate limit. Doc recomenda retry com backoff — aqui apenas
        // sinalizamos o caller.
        debugPrint('[Tmdb] 429 Too Many Requests');
        throw const TmdbRateLimitException(
          'Rate limit do TMDB atingido. Aguarde e tente novamente.',
        );
      default:
        debugPrint('[Tmdb] ${response.statusCode} ${response.body}');
        throw TmdbRequestException(
          'TMDB retornou ${response.statusCode}',
          statusCode: response.statusCode,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // /search/movie
  // ---------------------------------------------------------------------------

  /// Busca filmes pelo título.
  ///
  /// Parâmetros compatíveis com a doc oficial:
  /// - [query]: termo de busca (obrigatório).
  /// - [year]: filtra por ano de lançamento (mais permissivo).
  /// - [primaryReleaseYear]: filtra por `primary_release_date` (mais estrito).
  /// - [region]: ISO 3166-1 (e.g. "BR") para priorizar resultados locais.
  /// - [page]: índice da paginação (default 1).
  /// - [limit]: quantos resultados devolver (cliente, não servidor).
  Future<List<TmdbMovie>> searchMovies(
    String query, {
    int? year,
    int? primaryReleaseYear,
    String? region,
    int page = 1,
    int limit = 5,
  }) async {
    final cleanedQuery = query.trim();
    if (cleanedQuery.isEmpty) return [];

    final cacheKey =
        'search:${cleanedQuery.toLowerCase()}_${year ?? ''}_${primaryReleaseYear ?? ''}_${region ?? ''}_$page';
    _cleanCache();
    final cached = _searchCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[Tmdb] Cache hit: $cacheKey');
      return cached.data.results.take(limit).toList();
    }

    final params = <String, String>{
      'query': cleanedQuery,
      'language': 'pt-BR',
      'include_adult': 'false',
      'page': page.toString(),
    };
    if (year != null) params['year'] = year.toString();
    if (primaryReleaseYear != null) {
      params['primary_release_year'] = primaryReleaseYear.toString();
    }
    if (region != null) params['region'] = region;

    try {
      final body = await _request('/search/movie', queryParameters: params);
      final parsed = TmdbSearchResponse.fromJson(body);
      _searchCache[cacheKey] = _CacheEntry(parsed);
      return parsed.results.take(limit).toList();
    } on TmdbException {
      rethrow;
    } catch (e) {
      throw TmdbRequestException('Falha em searchMovies: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // /movie/{id}
  // ---------------------------------------------------------------------------

  /// Detalhes completos de um filme por TMDB ID.
  ///
  /// Suporta `append_to_response` para minimizar requests (até 20
  /// sub-endpoints em uma única chamada — doc oficial).
  /// Exemplo:
  /// ```dart
  /// getMovieDetails(id, appendToResponse: ['credits', 'videos'])
  /// ```
  /// Documentação: https://developer.themoviedb.org/reference/movie-details
  Future<TmdbMovie?> getMovieDetails(
    int tmdbId, {
    List<String> appendToResponse = const [],
  }) async {
    _cleanCache();
    final cached = _detailsCache[tmdbId];
    if (cached != null && !cached.isExpired) {
      debugPrint('[Tmdb] Cache hit details: $tmdbId');
      return cached.data;
    }

    final params = <String, String>{'language': 'pt-BR'};
    if (appendToResponse.isNotEmpty) {
      // Doc oficial: comma separated list, 20 items max.
      params['append_to_response'] = appendToResponse.take(20).join(',');
    }

    try {
      final body = await _request('/movie/$tmdbId', queryParameters: params);
      final movie = TmdbMovie.fromJson(body);
      _detailsCache[tmdbId] = _CacheEntry(movie);
      return movie;
    } on TmdbAuthException {
      // 401 = chave inválida. Propaga.
      rethrow;
    } on TmdbRateLimitException {
      // 429 = rate-limit. Propaga.
      rethrow;
    } on TmdbException {
      // Outros erros: devolve null sem derrubar tudo.
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Match heuristic para nomes bagunçados
  // ---------------------------------------------------------------------------

  /// Escolhe o melhor match numa lista de resultados.
  ///
  /// Preferência:
  /// 1. Match exato (case-insensitive) em `title` ou `originalTitle`.
  /// 2. Match parcial (contains).
  /// 3. Primeiro resultado como fallback.
  TmdbMovie? matchInResults(List<TmdbMovie> results, String query) {
    if (results.isEmpty) return null;
    final lower = query.toLowerCase().trim();

    Iterable<TmdbMovie> filter = results.where(
      (m) =>
          m.title.toLowerCase() == lower ||
          (m.originalTitle?.toLowerCase() == lower),
    );
    if (filter.isNotEmpty) return filter.first;

    filter = results.where(
      (m) =>
          m.title.toLowerCase().contains(lower) ||
          (m.originalTitle?.toLowerCase().contains(lower) ?? false),
    );
    if (filter.isNotEmpty) return filter.first;

    return results.first;
  }
}
