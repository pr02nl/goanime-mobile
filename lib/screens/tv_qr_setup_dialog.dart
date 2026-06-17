import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/tmdb_service.dart';
import '../services/tv_api_key_server.dart';
import '../widgets/focusable_widget.dart';

/// Dialog modal que mostra QR code para configurar a API key do TMDB na TV.
///
/// O fluxo é:
/// 1. Inicia o servidor HTTP local
/// 2. Exibe o QR code com a URL do servidor
/// 3. Usuário escaneia com o celular e digita a key
/// 4. Servidor recebe a key, salva, e emite evento
/// 5. Dialog atualiza para tela de sucesso e fecha
class TvQrSetupDialog extends StatefulWidget {
  const TvQrSetupDialog({super.key});

  /// Mostra o dialog e retorna true se a key foi configurada com sucesso.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TvQrSetupDialog(),
    );
    return result ?? false;
  }

  @override
  State<TvQrSetupDialog> createState() => _TvQrSetupDialogState();
}

class _TvQrSetupDialogState extends State<TvQrSetupDialog> {
  final TvApiKeyServer _server = TvApiKeyServer();
  String? _serverUrl;
  bool _keyReceived = false;
  bool _error = false;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      final url = await _server.start();
      if (!mounted) return;
      setState(() => _serverUrl = url);

      // Escuta quando a key é recebida
      _subscription = _server.onKeyReceived.listen((key) async {
        // Configura o TmdbService com a nova key
        TmdbService().setApiKey(key);
        if (!mounted) return;
        setState(() => _keyReceived = true);

        // Fecha o dialog após 2 segundos mostrando sucesso
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              spreadRadius: 0,
            ),
          ],
        ),
        child: _error
            ? _buildError()
            : _keyReceived
            ? _buildSuccess()
            : _buildQrCode(),
      ),
    );
  }

  Widget _buildQrCode() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code_2,
                color: Color(0xFFE50914),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Configurar API Key',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildStep(1, 'Abra a câmera do celular'),
              const SizedBox(height: 8),
              _buildStep(2, 'Escaneie o QR code ao lado'),
              const SizedBox(height: 8),
              _buildStep(3, 'Digite a API key no celular'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // QR Code
        if (_serverUrl != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: _serverUrl!,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1A1A2E),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1A1A2E),
              ),
            ),
          )
        else
          const SizedBox(
            width: 200,
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            ),
          ),
        const SizedBox(height: 16),

        // Server URL
        if (_serverUrl != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _serverUrl!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Debug info - Alternative IPs (TV debugging)
        if (_server.allIps.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.network_check,
                      size: 14,
                      color: Colors.amber.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Redes detectadas:',
                      style: TextStyle(
                        color: Colors.amber.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ..._server.allIps
                    .skip(1)
                    .map(
                      (ip) => Padding(
                        padding: const EdgeInsets.only(left: 20, top: 2),
                        child: Text(
                          '• http://$ip:${_server.localIp == ip ? 8080 : "[porta]"}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Waiting indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFFE50914).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Aguardando configuração no celular...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 20),
        const Text(
          'Configurado!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A API key foi salva com sucesso.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        ),
        const SizedBox(height: 20),
        const Text(
          'Erro ao iniciar servidor',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Verifique:\n• TV conectada ao Wi-Fi/Ethernet\n• Celular na mesma rede\n• Firewall não bloqueia portas 8080-9000',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FocusableWidget(
          onSelect: () => Navigator.of(context).pop(false),
          borderRadius: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Fechar',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStep(int num, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFE50914),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$num',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
