// test/data/services/auth/authenticated_http_client_test.dart
//
// Testes do AuthenticatedHttpClient. Valida:
// - Injeção do header `Authorization: Bearer <token>` em toda request
// - Headers existentes são preservados
// - Propriedades da request (URI, method) são mantidas
// - 401 dispara forceRenew() + retry com token novo
// - 401 no retry propaga o erro (sem loop infinito)
// - Non-401 passa direto sem retry
// - kPauloFlixHostPattern casa os hosts corretos
// - close() delega para o inner client
//
// ## Estratégia de teste
//
// Usamos `_TestHttpClient` (custom http.Client) em vez de MockClient
// para evitar que `finalize()` seja chamado no request, o que impediria
// o retry em caso de 401. O `JwtTokenManager` é mockado manualmente
// para retornar tokens previsíveis sem depender de crypto real.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:goanime/data/services/auth/authenticated_http_client.dart';
import 'package:goanime/data/services/auth/jwt_token_manager.dart';

/// Handler type for [_TestHttpClient]: receives the request and returns
/// a status code + body.
typedef _RequestHandler = Future<_Response> Function(http.BaseRequest request);

/// Simple response for [_TestHttpClient].
class _Response {
  _Response(this.body, this.statusCode);
  final String body;
  final int statusCode;
}

/// Custom http.Client that does NOT call `finalize()` on the request,
/// avoiding issues with retry (where the same request is sent twice).
class _TestHttpClient extends http.BaseClient {
  _TestHttpClient(this.handler);

  final _RequestHandler handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      contentLength: response.body.length,
      headers: const {},
      request: request,
    );
  }

  @override
  void close() {}
}

void main() {
  group('AuthenticatedHttpClient', () {
    const testToken = 'test.jwt.token';
    const renewedToken = 'renewed.jwt.token';
    const pauloflixUrl = 'https://media.oliveira.braga.nom.br/tvshows/';

    late _MockTokenManager tokenManager;
    late _TestHttpClient innerClient;
    late AuthenticatedHttpClient client;

    setUp(() {
      tokenManager = _MockTokenManager();
      tokenManager.mockToken = testToken;
      tokenManager.mockRenewedToken = renewedToken;
      // Default inner: 200 vazio. Cada teste pode substituir.
      innerClient = _TestHttpClient((_) async => _Response('ok', 200));
      client = AuthenticatedHttpClient(
        tokenManager: tokenManager,
        inner: innerClient,
      );
    });

    group('Authorization header injection', () {
      test('adiciona Authorization: Bearer em toda request', () async {
        http.BaseRequest? captured;
        innerClient = _TestHttpClient((request) async {
          captured = request;
          return _Response('ok', 200);
        });
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        await client.get(Uri.parse(pauloflixUrl));

        final req = captured;
        expect(req, isNotNull);
        expect(
          req!.headers['Authorization'],
          equals('Bearer $testToken'),
        );
      });

      test('preserva headers existentes da request', () async {
        http.BaseRequest? captured;
        innerClient = _TestHttpClient((request) async {
          captured = request;
          return _Response('ok', 200);
        });
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        await client.post(
          Uri.parse(pauloflixUrl),
          headers: {'Content-Type': 'application/json', 'X-Custom': 'value'},
        );

        final req = captured;
        expect(req, isNotNull);
        expect(
          req!.headers['Authorization'],
          equals('Bearer $testToken'),
        );
        expect(
          req.headers['Content-Type'],
          equals('application/json'),
        );
        expect(req.headers['X-Custom'], equals('value'));
      });

      test('preserva URI e method da request', () async {
        http.BaseRequest? captured;
        innerClient = _TestHttpClient((request) async {
          captured = request;
          return _Response('ok', 200);
        });
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        await client.get(Uri.parse('$pauloflixUrl?page=1'));

        final req = captured;
        expect(req, isNotNull);
        expect(req!.method, equals('GET'));
        expect(
          req.url.toString(),
          equals('$pauloflixUrl?page=1'),
        );
      });

      test('usa o token retornado por getValidToken()', () async {
        http.BaseRequest? captured;
        innerClient = _TestHttpClient((request) async {
          captured = request;
          return _Response('ok', 200);
        });
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        await client.get(Uri.parse(pauloflixUrl));

        final req = captured;
        expect(req, isNotNull);
        expect(tokenManager.getValidTokenCallCount, equals(1));
        expect(
          req!.headers['Authorization'],
          equals('Bearer $testToken'),
        );
      });
    });

    group('401 handling', () {
      test('401 dispara forceRenew() e retry com token novo', () async {
        int callCount = 0;
        String? firstAuth;
        String? secondAuth;
        innerClient = _TestHttpClient((request) async {
          callCount++;
          // Captura o valor do header no momento da request, antes que
          // o AuthenticatedHttpClient possa sobrescrevê-lo na retry.
          if (callCount == 1) {
            firstAuth = request.headers['Authorization'];
            return _Response('unauthorized', 401);
          }
          secondAuth = request.headers['Authorization'];
          return _Response('ok', 200);
        });
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        final response = await client.get(Uri.parse(pauloflixUrl));

        expect(response.statusCode, equals(200));
        expect(callCount, equals(2));
        expect(tokenManager.forceRenewCallCount, equals(1));
        // Primeira tentativa: token original
        expect(
          firstAuth,
          equals('Bearer $testToken'),
        );
        // Segunda tentativa: token renovado
        expect(
          secondAuth,
          equals('Bearer $renewedToken'),
        );
      });

      test('401 no retry propaga o erro (sem loop infinito)', () async {
        innerClient = _TestHttpClient(
          (_) async => _Response('unauthorized', 401),
        );
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        final response = await client.get(Uri.parse(pauloflixUrl));

        expect(response.statusCode, equals(401));
        // Apenas 1 forceRenew (não entra em loop)
        expect(tokenManager.forceRenewCallCount, equals(1));
      });

      test('non-401 não dispara forceRenew()', () async {
        innerClient = _TestHttpClient(
          (_) async => _Response('ok', 200),
        );
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        await client.get(Uri.parse(pauloflixUrl));

        expect(tokenManager.forceRenewCallCount, equals(0));
      });

      test('403 não dispara forceRenew()', () async {
        innerClient = _TestHttpClient(
          (_) async => _Response('forbidden', 403),
        );
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        await client.get(Uri.parse(pauloflixUrl));

        expect(tokenManager.forceRenewCallCount, equals(0));
      });
    });

    group('convenience methods (get, post, head)', () {
      test('get() injeta Authorization header', () async {
        http.BaseRequest? captured;
        innerClient = _TestHttpClient((request) async {
          captured = request;
          return _Response('ok', 200);
        });
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        await client.get(Uri.parse(pauloflixUrl));

        final req = captured;
        expect(req, isNotNull);
        expect(
          req!.headers['Authorization'],
          equals('Bearer $testToken'),
        );
      });

      test('post() injeta Authorization header', () async {
        http.BaseRequest? captured;
        innerClient = _TestHttpClient((request) async {
          captured = request;
          return _Response('ok', 200);
        });
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        await client.post(Uri.parse(pauloflixUrl));

        final req = captured;
        expect(req, isNotNull);
        expect(
          req!.headers['Authorization'],
          equals('Bearer $testToken'),
        );
      });

      test('head() injeta Authorization header', () async {
        http.BaseRequest? captured;
        innerClient = _TestHttpClient((request) async {
          captured = request;
          return _Response('ok', 200);
        });
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: innerClient,
        );

        await client.head(Uri.parse(pauloflixUrl));

        final req = captured;
        expect(req, isNotNull);
        expect(
          req!.headers['Authorization'],
          equals('Bearer $testToken'),
        );
      });
    });

    group('kPauloFlixHostPattern', () {
      test('casa media.oliveira.braga.nom.br', () {
        expect(
          kPauloFlixHostPattern.hasMatch('media.oliveira.braga.nom.br'),
          isTrue,
        );
      });

      test('casa subdominio.media.oliveira.braga.nom.br', () {
        expect(
          kPauloFlixHostPattern.hasMatch(
            'player.media.oliveira.braga.nom.br',
          ),
          isTrue,
        );
      });

      test('não casa example.com', () {
        expect(kPauloFlixHostPattern.hasMatch('example.com'), isFalse);
      });

      test('não casa media.example.com', () {
        expect(
          kPauloFlixHostPattern.hasMatch('media.example.com'),
          isFalse,
        );
      });
    });

    group('close()', () {
      test('close() delega para inner client', () async {
        bool closed = false;
        final trackingClient = _CloseTrackingClient();
        trackingClient.onClose = () {
          closed = true;
        };
        innerClient = _TestHttpClient(
          (_) async => _Response('ok', 200),
        );
        client = AuthenticatedHttpClient(
          tokenManager: tokenManager,
          inner: trackingClient,
        );

        client.close();

        expect(closed, isTrue);
      });
    });

    test('múltiplas requests usam o mesmo token (getValidToken cache)', () async {
      int requestCount = 0;
      innerClient = _TestHttpClient((request) async {
        requestCount++;
        return _Response('ok', 200);
      });
      client = AuthenticatedHttpClient(
        tokenManager: tokenManager,
        inner: innerClient,
      );

      await client.get(Uri.parse(pauloflixUrl));
      await client.get(Uri.parse(pauloflixUrl));
      await client.get(Uri.parse(pauloflixUrl));

      // getValidToken foi chamado 3 vezes (uma por request)
      expect(tokenManager.getValidTokenCallCount, equals(3));
      // forceRenew NUNCA foi chamado (sem 401)
      expect(tokenManager.forceRenewCallCount, equals(0));
      expect(requestCount, equals(3));
    });
  });
}

// ════════════════════════════════════════════════════════════════════════
// Mocks
// ════════════════════════════════════════════════════════════════════════

class _MockTokenManager implements JwtTokenManager {
  String mockToken = 'default.mock.token';
  String mockRenewedToken = 'default.renewed.token';
  int getValidTokenCallCount = 0;
  int forceRenewCallCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<String> getValidToken() async {
    getValidTokenCallCount++;
    return mockToken;
  }

  @override
  Future<String> forceRenew() async {
    forceRenewCallCount++;
    return mockRenewedToken;
  }

  @override
  String get deviceId => 'mock-device-id-0000-0000-000000000000';
}

/// Wrapper que detecta se close() foi chamado.
class _CloseTrackingClient extends http.BaseClient {
  void Function()? onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError('Not used in tests');
  }

  @override
  void close() {
    onClose?.call();
    super.close();
  }
}
