import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_key_settings_service.dart';

/// Servidor HTTP local para receber a API key do TMDB via navegador do celular.
///
/// Fluxo:
/// 1. TV inicia o servidor na porta 8080
/// 2. Exibe QR code com http://IP_LOCAL:8080
/// 3. Usuário escaneia com o celular e digita a key
/// 4. Servidor recebe via POST, salva em SharedPreferences
/// 5. TV atualiza o estado e para o servidor
class TvApiKeyServer {
  int _port = 8080;
  HttpServer? _server;
  final ApiKeySettingsService _settings = ApiKeySettingsService();

  /// Stream que emite quando uma key é recebida com sucesso.
  final _onKeyReceived = StreamController<String>.broadcast();
  Stream<String> get onKeyReceived => _onKeyReceived.stream;

  bool get isRunning => _server != null;

  /// IP local da rede (para exibir no QR code).
  String? _localIp;
  String? get localIp => _localIp;

  /// Lista de todos os IPs disponíveis (para debug e fallback).
  List<String> _allIps = [];
  List<String> get allIps => List.unmodifiable(_allIps);

  String get serverUrl => 'http://${_localIp ?? "localhost"}:$_port';

  /// Inicia o servidor e retorna a URL para o QR code.
  /// Tenta múltiplas portas se a 8080 estiver ocupada.
  Future<String> start() async {
    if (_server != null) return serverUrl;

    // Verifica se há conectividade de rede
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      if (interfaces.isEmpty) {
        throw Exception(
          'No network interfaces found. Check if WiFi or Ethernet is connected.',
        );
      }
      debugPrint(
        '[TvApiKeyServer] Found ${interfaces.length} network interfaces',
      );
    } catch (e) {
      debugPrint('[TvApiKeyServer] Error listing network interfaces: $e');
      // Continua mesmo com erro - pode ser permissão ou API não suportada
    }

    // Obtém todos os IPs disponíveis
    final ips = await _getLocalIps();
    if (ips.isEmpty) {
      throw Exception(
        'No network interface found. Check WiFi/Ethernet connection.',
      );
    }
    _allIps = ips;
    _localIp = ips.first;
    debugPrint('[TvApiKeyServer] Primary IP: $_localIp');
    if (ips.length > 1) {
      debugPrint('[TvApiKeyServer] Alternative IPs: ${ips.sublist(1)}');
    }

    // Tenta portas alternativas se a 8080 estiver ocupada
    final portsToTry = [8080, 8081, 8082, 9000, 8765];
    int? boundPort;

    for (final port in portsToTry) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
        boundPort = port;
        debugPrint('[TvApiKeyServer] Server started on port $port');
        break;
      } on SocketException catch (e) {
        debugPrint('[TvApiKeyServer] Port $port unavailable: ${e.message}');
        continue;
      }
    }

    if (_server == null || boundPort == null) {
      throw Exception('Could not bind to any port. Firewall or port conflict?');
    }

    // Atualiza a URL com a porta correta
    _port = boundPort;

    _server!.listen(
      _handleRequest,
      onError: (e) => debugPrint('[TvApiKeyServer] Request error: $e'),
    );

    debugPrint('[TvApiKeyServer] Server ready at: $serverUrl');
    return serverUrl;
  }

  /// Para o servidor.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    debugPrint('[TvApiKeyServer] Server stopped');
  }

  /// Processa cada request HTTP.
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/') {
        // Página principal com formulário
        await _serveFormPage(request);
      } else if (request.method == 'POST' && request.uri.path == '/set-key') {
        // Recebe a API key
        await _handleSetKey(request);
      } else if (request.method == 'GET' && request.uri.path == '/success') {
        // Página de sucesso
        await _serveSuccessPage(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      debugPrint('[TvApiKeyServer] Error handling request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  /// Serve a página HTML com o formulário de输入 da API key.
  Future<void> _serveFormPage(HttpRequest request) async {
    final html = '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PauloFlix - Configurar API Key</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      color: #fff;
    }
    .card {
      background: rgba(255, 255, 255, 0.08);
      backdrop-filter: blur(20px);
      border-radius: 20px;
      padding: 40px;
      max-width: 440px;
      width: 100%;
      border: 1px solid rgba(255, 255, 255, 0.1);
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.4);
    }
    .logo {
      text-align: center;
      margin-bottom: 24px;
    }
    .logo-icon {
      width: 64px;
      height: 64px;
      background: linear-gradient(135deg, #e50914, #b20710);
      border-radius: 16px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      margin-bottom: 12px;
    }
    h1 {
      font-size: 24px;
      font-weight: 700;
      margin-bottom: 8px;
    }
    .subtitle {
      color: rgba(255, 255, 255, 0.6);
      font-size: 14px;
      margin-bottom: 28px;
      line-height: 1.5;
    }
    .steps {
      background: rgba(255, 255, 255, 0.05);
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 24px;
    }
    .step {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      margin-bottom: 12px;
    }
    .step:last-child { margin-bottom: 0; }
    .step-num {
      width: 24px;
      height: 24px;
      background: #e50914;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 12px;
      font-weight: 700;
      flex-shrink: 0;
    }
    .step-text {
      font-size: 13px;
      color: rgba(255, 255, 255, 0.8);
      line-height: 1.4;
    }
    .step-text a {
      color: #e50914;
      text-decoration: none;
      font-weight: 600;
    }
    .step-text a:hover { text-decoration: underline; }
    input[type="text"] {
      width: 100%;
      padding: 14px 16px;
      background: rgba(0, 0, 0, 0.3);
      border: 2px solid rgba(255, 255, 255, 0.15);
      border-radius: 12px;
      color: #fff;
      font-size: 16px;
      outline: none;
      transition: border-color 0.2s;
      margin-bottom: 16px;
    }
    input[type="text"]:focus {
      border-color: #e50914;
    }
    input[type="text"]::placeholder {
      color: rgba(255, 255, 255, 0.35);
    }
    button {
      width: 100%;
      padding: 14px;
      background: linear-gradient(135deg, #e50914, #b20710);
      border: none;
      border-radius: 12px;
      color: #fff;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      transition: transform 0.15s, box-shadow 0.15s;
    }
    button:hover {
      transform: translateY(-1px);
      box-shadow: 0 6px 20px rgba(229, 9, 20, 0.4);
    }
    button:active { transform: translateY(0); }
    .hint {
      text-align: center;
      margin-top: 16px;
      font-size: 12px;
      color: rgba(255, 255, 255, 0.4);
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">
      <div class="logo-icon">▶</div>
      <h1>PauloFlix</h1>
      <p class="subtitle">Configure a API key do TMDB na sua TV</p>
    </div>

    <div class="steps">
      <div class="step">
        <div class="step-num">1</div>
        <div class="step-text">
          Acesse <a href="https://www.themoviedb.org/settings/api" target="_blank">themoviedb.org/settings/api</a> e copie sua <strong>API Read Access Token</strong>
        </div>
      </div>
      <div class="step">
        <div class="step-num">2</div>
        <div class="step-text">Cole o token no campo abaixo</div>
      </div>
      <div class="step">
        <div class="step-num">3</div>
        <div class="step-text">Toque em <strong>Configurar</strong> — a TV será atualizada automaticamente!</div>
      </div>
    </div>

    <form method="POST" action="/set-key">
      <input
        type="text"
        name="api_key"
        placeholder="Cole sua API Read Access Token aqui..."
        autocomplete="off"
        spellcheck="false"
        required
      />
      <button type="submit">Configurar na TV</button>
    </form>

    <p class="hint">A chave é salva apenas na sua TV e não é enviada a nenhum servidor externo.</p>
  </div>
</body>
</html>''';

    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  /// Processa o POST com a API key.
  Future<void> _handleSetKey(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    // Parse application/x-www-form-urlencoded body
    final params = Uri(query: body).queryParameters;
    final apiKey = params['api_key']?.trim() ?? '';

    if (apiKey.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('API key is required');
      await request.response.close();
      return;
    }

    // Salva a key
    await _settings.setTmdbApiKey(apiKey);
    debugPrint('[TvApiKeyServer] API key saved successfully');

    // Notifica ouvintes
    _onKeyReceived.add(apiKey);

    // Redireciona para página de sucesso
    request.response.headers.add('Location', '/success');
    request.response.statusCode = HttpStatus.movedPermanently;
    await request.response.close();
  }

  /// Página de sucesso após salvar a key.
  Future<void> _serveSuccessPage(HttpRequest request) async {
    final html = '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PauloFlix - Configurado!</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      color: #fff;
    }
    .card {
      background: rgba(255, 255, 255, 0.08);
      backdrop-filter: blur(20px);
      border-radius: 20px;
      padding: 48px 40px;
      max-width: 400px;
      width: 100%;
      border: 1px solid rgba(255, 255, 255, 0.1);
      text-align: center;
    }
    .check {
      width: 80px;
      height: 80px;
      background: linear-gradient(135deg, #22c55e, #16a34a);
      border-radius: 50%;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 40px;
      margin-bottom: 20px;
      animation: pop 0.4s ease-out;
    }
    @keyframes pop {
      0% { transform: scale(0.5); opacity: 0; }
      70% { transform: scale(1.1); }
      100% { transform: scale(1); opacity: 1; }
    }
    h1 { font-size: 24px; margin-bottom: 8px; }
    p {
      color: rgba(255, 255, 255, 0.6);
      font-size: 14px;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="check">✓</div>
    <h1>Configurado!</h1>
    <p>A API key foi salva na sua TV.<br>Pode fechar esta página no celular.</p>
  </div>
</body>
</html>''';

    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  /// Detecta o IP local da rede - suporta todas as classes de rede privada.
  /// Prioridade: WiFi/Ethernet com IP privado (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
  Future<List<String>> _getLocalIps() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      debugPrint(
        '[TvApiKeyServer] Found ${interfaces.length} network interfaces:',
      );
      for (final iface in interfaces) {
        debugPrint(
          '  - ${iface.name}: ${iface.addresses.map((a) => a.address).join(', ')}',
        );
      }

      // Prioridade 1: IPs privados comuns (192.168.x.x)
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            if (!ips.contains(addr.address)) {
              ips.add(addr.address);
            }
          }
        }
      }

      // Prioridade 2: Classe A privada (10.x.x.x)
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('10.')) {
            if (!ips.contains(addr.address)) {
              ips.add(addr.address);
            }
          }
        }
      }

      // Prioridade 3: Classe B privada (172.16.x.x - 172.31.x.x)
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4 && parts[0] == '172') {
              final second = int.tryParse(parts[1]) ?? 0;
              if (second >= 16 && second <= 31) {
                if (!ips.contains(addr.address)) {
                  ips.add(addr.address);
                }
              }
            }
          }
        }
      }

      // Fallback: qualquer IP não-loopback
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !ips.contains(addr.address)) {
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('[TvApiKeyServer] Error detecting local IP: $e');
    }

    debugPrint('[TvApiKeyServer] Available IPs: $ips');
    return ips;
  }

  /// Retorna o primeiro IP disponível (compatibilidade).
  // Future<String?> _getLocalIp() async {
  //   final ips = await _getLocalIps();
  //   return ips.isNotEmpty ? ips.first : null;
  // }

  void dispose() {
    stop();
    _onKeyReceived.close();
  }
}
