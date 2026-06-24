/// Wrapper de `BaseCacheManager` que injeta automaticamente o header
/// `Authorization: Bearer *** em todas as requests HTTP feitas pelo
/// `CachedNetworkImage` (e qualquer outro consumer do cache).
///
/// **Por que existe:** o servidor PauloFlix está atrás de HTTPS+token
/// (vide Fase 6 do plano NFO enrichment). O `cached_network_image` por
/// default usa um `http.Client` global **sem** headers — então a
/// primeira requisição volta `401 Unauthorized` e a imagem mostra
/// `errorWidget` (placeholder cinza).
///
/// **Como funciona:** este wrapper **delega** para um `CacheManager`
/// interno (que faz toda a lógica de cache+download), mas **adiciona**
/// `Authorization: Bearer <token>` no mapa de headers que o caller
/// passa. O token é gerenciado por [JwtTokenManager] (reaproveita a
/// mesma instância do resto do app).
///
/// **Lifecycle:** este wrapper é **stateless** — múltiplas instâncias
/// compartilham o mesmo `CacheManager` interno. Não precisa dispose
/// (o inner já é gerenciado pelo `cached_network_image`).
///
/// **Setup no `app.dart`:** trocar `defaultCacheManager` por uma
/// instância deste wrapper no startup:
/// ```dart
/// CachedNetworkImageProvider.defaultCacheManager =
///     AuthenticatedCacheManager(JwtTokenManager());
/// ```
///
/// **Por que NÃO usar `httpHeaders` em cada `CachedNetworkImage` widget:**
/// seriam 80+ call sites para atualizar (e novos widgets no futuro
/// esqueceriam). Global é mais robusto.
///
/// Referência: `flutter-reactivity-gotchas` pitfall #18 (não inventar
/// API de pacote — verificar source real).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:file/file.dart' as file_pkg;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'jwt_token_manager.dart';

/// Cache manager que injeta `Authorization: Bearer` em toda request.
///
/// **Importante:** este wrapper **delega** para um [CacheManager]
/// interno (default do `cached_network_image`). Não duplica
/// lógica de cache — só adiciona o header de auth.
class AuthenticatedCacheManager implements BaseCacheManager {
  AuthenticatedCacheManager(this._tokenManager, {BaseCacheManager? inner})
    : _inner = inner ?? CacheManager(Config(_kCacheKey));

  /// Token manager que gera/renova JWT. Mesma instância usada pelo
  /// `AuthenticatedHttpClient` nos services de sync/enricher.
  final JwtTokenManager _tokenManager;

  /// Delegate. Pode ser injetado para reuso (ex: testes) ou criado
  /// internamente (default).
  final BaseCacheManager _inner;

  /// Cache key único para esta instância. Diferente do default
  /// `libCachedImageData` para evitar conflito se o app rodar com
  /// 2 cache managers ao mesmo tempo.
  static const String _kCacheKey = 'authenticatedCachedImageData';

  /// Retorna o mapa de headers com `Authorization` injetado.
  ///
  /// [base] pode ser `null` (sem headers do caller) ou um mapa
  /// existente. A função **adiciona** o Bearer, não substitui.
  Future<Map<String, String>?> _injectAuth(Map<String, String>? base) async {
    final token = await _tokenManager.getValidToken();
    return <String, String>{...?base, 'Authorization': 'Bearer $token'};
  }

  // ════════════════════════════════════════════════════════════════════════
  // Override dos métodos públicos para injetar o header
  // ════════════════════════════════════════════════════════════════════════

  @override
  Future<file_pkg.File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    final h = await _injectAuth(headers);
    return _inner.getSingleFile(url, key: key ?? url, headers: h ?? const {});
  }

  @override
  Future<FileInfo?> getFileFromMemory(String key) =>
      _inner.getFileFromMemory(key);

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) => _inner.getFileFromCache(key, ignoreMemCache: ignoreMemCache);

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    final h = await _injectAuth(headers);
    await for (final result in _inner.getFileStream(
      url,
      key: key,
      headers: h,
      withProgress: withProgress,
    )) {
      yield result;
    }
  }

  @override
  @Deprecated('Prefer to use the new getFileStream method')
  Stream<FileInfo> getFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async* {
    final h = await _injectAuth(headers);
    await for (final result in _inner.getFile(
      url,
      key: key ?? url,
      headers: h ?? const {},
    )) {
      yield result;
    }
  }

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) async {
    final h = await _injectAuth(authHeaders);
    return _inner.downloadFile(
      url,
      key: key ?? url,
      authHeaders: h ?? const {},
      force: force,
    );
  }

  @override
  Future<file_pkg.File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) => _inner.putFile(
    url,
    fileBytes,
    key: key,
    eTag: eTag,
    maxAge: maxAge,
    fileExtension: fileExtension,
  );

  @override
  Future<file_pkg.File> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) => _inner.putFileStream(
    url,
    source,
    key: key,
    eTag: eTag,
    maxAge: maxAge,
    fileExtension: fileExtension,
  );

  @override
  Future<void> removeFile(String key) => _inner.removeFile(key);

  @override
  Future<void> emptyCache() => _inner.emptyCache();

  @override
  Future<void> dispose() => _inner.dispose();
}
