// lib/data/services/auth/jwt_token_manager.dart
//
// Gera e persiste JWT Ed25519 para autenticar requests ao PauloFlix
// (migração Tailscale → HTTPS+token).
//
// ## Por que Ed25519 (e não HS256)?
//
// Ed25519 é **assimétrico**: a chave privada (32 bytes) fica embutida no
// app e a pública (32 bytes) fica na VPS. Se o nginx for comprometido,
// o atacante tem a chave pública — que serve para *verificar* tokens,
// não para *forjar*. Com HS256 (chave simétrica), comprometer o nginx
// = comprometer a chave que o app usa = game over.
//
// ## Onde fica a chave privada?
//
// O par de chaves é gerado 1x na VPS via `tools/generate_jwt_keypair.sh`.
// O script imprime o base64 da chave privada raw (32 bytes), que o dev
// cola nesta constante e recompila o app. A chave pública vai em
// `/etc/nginx/auth/pauloflix_public.pem` na VPS.
//
// ## Rotação de chave
//
// Trocar a chave = gerar novo par + atualizar constante + republicar app.
// Não tem rotação automática (cada versão do APK precisa rebuildar).
// Para produção: implementar endpoint de bootstrap que serve a chave
// via TLS pinning + rotação via signed payload do backend.
//
// ## device_id
//
// UUID v4 gerado no primeiro launch, salvo em SharedPreferences. Permite
// revogação futura via allowlist (não implementado agora, mas o hook
// fica pronto no `payload.device_id` que o validador pode logar).

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// JWT Ed25519 manager para autenticação do PauloFlix.
///
/// **IMPORTANTE:** a constante [_kPrivateKeyB64] deve ser substituída
/// pelo base64 da chave privada raw (32 bytes) gerada via
/// `tools/generate_jwt_keypair.sh` na VPS. Até lá, qualquer token
/// gerado será assinado com o placeholder e **rejeitado pelo nginx**.
///
/// O token tem payload `{device_id, iat, exp}` e TTL de 365 dias. O
/// app renova automaticamente quando faltam <7 dias para expirar.
class JwtTokenManager {
  /// Chave privada Ed25519 (32 bytes) em base64, gerada via OpenSSL.
  ///
  /// **PLACEHOLDER** — substituir pelo output real de
  /// `tools/generate_jwt_keypair.sh` na VPS antes de buildar release.
  static const String _kPrivateKeyB64 =
      '6xTZbO1u1tZp27eEMKPntloU3Aw889evKi8KHCTWSdk=';

  // SharedPreferences keys
  static const String _kTokenKey = 'pauloflix_jwt_token';
  static const String _kTokenExpKey = 'pauloflix_jwt_token_exp';
  static const String _kDeviceIdKey = 'pauloflix_device_id';

  // JWT claims
  static const int _kTokenTtlSeconds = 365 * 86400; // 365 dias
  static const int _kRenewalBufferSeconds = 7 * 86400; // renova 7 dias antes

  // Algorithm constants
  static const String _kAlg = 'EdDSA';
  static const String _kTyp = 'JWT';
  static const String _kKeyPlaceholderMarker = 'REPLACE_WITH_OUTPUT';

  final Ed25519 _algorithm = Ed25519();
  String? _deviceId;
  KeyPair? _keyPair;

  /// Inicializa o manager: carrega ou gera device_id, prepara keypair.
  ///
  /// Idempotente — múltiplas chamadas são no-op após a primeira.
  ///
  /// Lança [StateError] se a chave privada ainda é o placeholder
  /// (proteção contra build acidental com chave errada).
  Future<void> initialize() async {
    if (_keyPair != null) return;

    if (_kPrivateKeyB64.startsWith(_kKeyPlaceholderMarker)) {
      throw StateError(
        'JwtTokenManager: chave privada Ed25519 ainda é placeholder. '
        'Rode tools/generate_jwt_keypair.sh na VPS e substitua '
        '_kPrivateKeyB64 em jwt_token_manager.dart.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_kDeviceIdKey) ?? _generateDeviceId(prefs);

    final seed = base64Decode(_kPrivateKeyB64);
    if (seed.length != 32) {
      throw StateError(
        'JwtTokenManager: chave privada deve ter 32 bytes, tem ${seed.length}. '
        'Verifique o output de tools/generate_jwt_keypair.sh.',
      );
    }

    _keyPair = await _algorithm.newKeyPairFromSeed(seed);
  }

  /// Retorna um token válido. Reutiliza cache se ainda tem >7 dias de vida;
  /// caso contrário, gera novo e persiste.
  Future<String> getValidToken() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kTokenKey);
    final exp = prefs.getInt(_kTokenExpKey) ?? 0;
    final now = _nowSeconds();

    if (stored != null && exp > now + _kRenewalBufferSeconds) {
      return stored;
    }

    final newExp = now + _kTokenTtlSeconds;
    final token = await _signToken(iat: now, exp: newExp);
    await prefs.setString(_kTokenKey, token);
    await prefs.setInt(_kTokenExpKey, newExp);
    return token;
  }

  /// Força regeneração do token (cache invalidado). Usado pelo
  /// `AuthenticatedHttpClient` em caso de 401 — pode ser que o
  /// servidor tenha sido reconfigurado com nova chave pública.
  Future<String> forceRenew() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final now = _nowSeconds();
    final newExp = now + _kTokenTtlSeconds;
    final token = await _signToken(iat: now, exp: newExp);
    await prefs.setString(_kTokenKey, token);
    await prefs.setInt(_kTokenExpKey, newExp);
    return token;
  }

  /// Retorna o device_id (UUID v4 persistido). Gera novo se primeira vez.
  String get deviceId {
    final id = _deviceId;
    if (id == null) {
      throw StateError(
        'JwtTokenManager: chame initialize() antes de acessar deviceId.',
      );
    }
    return id;
  }

  // --- Internals ---

  String _generateDeviceId(SharedPreferences prefs) {
    final id = const Uuid().v4();
    // Fire-and-forget: SharedPreferences.setString é async mas não precisamos
    // esperar — o ID em memória já está válido para esta sessão.
    prefs.setString(_kDeviceIdKey, id);
    return id;
  }

  Future<String> _signToken({required int iat, required int exp}) async {
    final header = <String, String>{'alg': _kAlg, 'typ': _kTyp};
    final payload = <String, dynamic>{
      'device_id': deviceId,
      'iat': iat,
      'exp': exp,
      'jti': _generateJti(), // unique token id (impede token reuse)
    };

    final headerB64 = _b64UrlEncode(utf8.encode(jsonEncode(header)));
    final payloadB64 = _b64UrlEncode(utf8.encode(jsonEncode(payload)));
    final signingInput = '$headerB64.$payloadB64';

    final keyPair = _keyPair;
    if (keyPair == null) {
      throw StateError('JwtTokenManager: _keyPair não inicializado.');
    }

    final signature = await _algorithm.sign(
      utf8.encode(signingInput),
      keyPair: keyPair,
    );

    final sigB64 = _b64UrlEncode(signature.bytes);
    return '$signingInput.$sigB64';
  }

  static String _b64UrlEncode(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// JWT ID (RFC 7519 §4.1.7). Aleatório por token, garante unicidade
  /// mesmo se iat/exp forem iguais (dois tokens gerados no mesmo segundo).
  /// Não precisa ser cryptographically strong — só precisa ser único.
  static String _generateJti() {
    final r = DateTime.now().microsecondsSinceEpoch;
    return r.toRadixString(36);
  }
}

/// Helper para testes: gera bytes aleatórios para uso como seed de teste.
/// **NÃO usar em produção** — produção usa a chave embutida [_kPrivateKeyB64].
@visibleForTesting
Uint8List generateTestSeed() {
  final seed = Uint8List(32);
  // Determinístico para reprodutibilidade dos testes.
  for (var i = 0; i < 32; i++) {
    seed[i] = (i * 7 + 13) & 0xff;
  }
  return seed;
}
