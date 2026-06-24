// lib/data/services/auth/authenticated_http_client.dart
//
// Wrapper sobre `http.Client` que injeta `Authorization: Bearer *** em
// toda request e trata 401 com retry 1x após regenerar o token.
//
// ## Por que este wrapper e não um interceptor do dio?
//
// O projeto usa **dois** clientes HTTP paralelos:
// - `package:http` (HttpClient, usado pelo PauloFlixService, scraping,
//   AnimeFire) — vanilla, sem interceptors
// - `package:dio` (Dio, com interceptors) — usado em partes específicas
//
// Adicionar interceptor no dio não cobre o `http.Client`. O wrapper
// `http.BaseClient` cobre 100% dos calls de `http` e ainda é compatível
// com qualquer código que aceite um `http.Client` genérico.

import 'package:http/http.dart' as http;

import 'jwt_token_manager.dart';

/// Regex case-insensitive que casa os hosts do PauloFlix.
///
/// Exposto como constant top-level (não dentro da classe) pra que
/// outros lugares (ex: o player) possam usar sem precisar instanciar
/// um `AuthenticatedHttpClient`.
final RegExp kPauloFlixHostPattern = RegExp(
  r'^(?:.+\.)?media\.oliveira\.braga\.nom\.br$',
  caseSensitive: false,
);

/// `http.Client` que adiciona `Authorization: Bearer *** automaticamente
/// a cada request, e regenera o token + retry 1x em caso de 401.
///
/// Use este cliente no lugar de `http.Client()` em todo código que
/// fala com a VPS PauloFlix (sync, scraping, range requests do player).
///
/// ## Exemplo
///
/// ```dart
/// final client = AuthenticatedHttpClient(
///   tokenManager: JwtTokenManager(),
///   inner: http.Client(),
/// );
/// final response = await client.get(Uri.parse(
///   'https://media.oliveira.braga.nom.br/tvshows/list.html',
/// ));
/// ```
class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient({
    required JwtTokenManager tokenManager,
    required http.Client inner,
  })  : _tokenManager = tokenManager,
        _inner = inner;

  final JwtTokenManager _tokenManager;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _tokenManager.getValidToken();
    request.headers['Authorization'] = 'Bearer $token';
    final firstAttempt = await _inner.send(request);

    // 401 = token rejeitado. Possíveis causas:
    // 1. Chave pública na VPS foi rotacionada (raro)
    // 2. Token expirou no relógio do servidor (drift de tempo)
    // 3. device_id foi revogado (não implementado, mas reservado)
    //
    // Em qualquer caso, regeneramos o token e tentamos 1x.
    // Se o segundo attempt também der 401, é problema de configuração
    // (chave errada, token mal formado) — propaga o erro pro caller.
    if (firstAttempt.statusCode == 401) {
      final freshToken = await _tokenManager.forceRenew();
      request.headers['Authorization'] = 'Bearer $freshToken';
      return _inner.send(request);
    }

    return firstAttempt;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
