import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:media_kit/media_kit.dart';

import 'database/app_database.dart';
import '../data/repositories/downloads_repository_impl.dart';
import '../data/services/auth/authenticated_http_client.dart';
import '../data/services/auth/jwt_token_manager.dart';
import '../data/services/download_service.dart';
import '../data/services/pauloflix_movies_service.dart';
import '../data/services/pauloflix_service.dart';
import '../ui/core/utils/performance_config.dart';
import '../ui/core/utils/tv_detector.dart';
import 'logger/app_logger.dart';
import '../ui/core/view_models/locale_viewmodel.dart';
import '../ui/settings/view_models/theme_viewmodel.dart';

/// Resultado da inicialização — todos os objetos necessários para o app.
class InitializationResult {
  final ThemeViewModel themeViewModel;
  final LocaleViewModel localeViewModel;
  final DownloadService downloadService;
  final AppDatabase appDatabase;
  final JwtTokenManager jwtManager;
  final String? startupError;

  /// Mensagem de aviso se o JWT falhou (auth não disponível).
  /// Quando não-nulo, a UI deve exibir um snackbar informando que
  /// downloads e sync podem não funcionar.
  final String? jwtWarning;

  InitializationResult({
    required this.themeViewModel,
    required this.localeViewModel,
    required this.downloadService,
    required this.appDatabase,
    required this.jwtManager,
    this.startupError,
    this.jwtWarning,
  });
}

/// Inicializador modular do app.
///
/// Extraído do antigo `main.dart` para separar responsabilidades:
/// cada etapa de inicialização é um método privado que pode falhar
/// individualmente sem abortar todo o processo.
class AppInitializer {
  /// Executa todas as etapas de inicialização e retorna os objetos prontos.
  static Future<InitializationResult> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    final errors = <String>[];
    String? firstError;

    const log = AppLogger('AppInitializer');

    /// Loga o erro e o acumula na lista de falhas.
    /// [e] é a exceção lançada, [st] é o stack trace (opcional).
    void captureError(String label, Object e, [StackTrace? st]) {
      log.error(label, e, st);
      final msg = '$label: $e';
      errors.add(msg);
      firstError ??= msg;
    }

    // ── 1. MediaKit ──────────────────────────────────────────────
    try {
      MediaKit.ensureInitialized();
      log.info('✓ MediaKit');
    } catch (e, st) {
      captureError('MediaKit', e, st);
    }

    // ── 2. PerformanceConfig ─────────────────────────────────────
    try {
      PerformanceConfig.init();
      log.info('✓ PerformanceConfig');
    } catch (e, st) {
      captureError('PerformanceConfig', e, st);
    }

    // ── 3. TVDetector (cache eager) ──────────────────────────────
    try {
      final isTv = await TVDetector.isTV;
      log.info(
        '✓ TVDetector (${isTv ? "TV" : "mobile"})',
      );
    } catch (e) {
      log.warning('⚠ TVDetector', e);
    }

    // ── 4. ThemeViewModel ────────────────────────────────────────
    final themeViewModel = ThemeViewModel();
    try {
      await themeViewModel.load();
      log.info('✓ ThemeViewModel');
    } catch (e, st) {
      captureError('ThemeViewModel', e, st);
    }

    // ── 5. LocaleViewModel ───────────────────────────────────────
    final localeViewModel = LocaleViewModel();
    try {
      await localeViewModel.load();
      log.info('✓ LocaleViewModel');
    } catch (e, st) {
      captureError('LocaleViewModel', e, st);
    }

    // ══════════════════════════════════════════════════════════════
    // 6. JWT manager — DEVE rodar ANTES dos services que o usam
    // (DownloadService, PauloFlixService, PauloFlixMoviesService).
    // ══════════════════════════════════════════════════════════════
    String? jwtWarning;
    final jwtManager = JwtTokenManager();
    log.debug('▶ Inicializando JWT manager...');
    http.Client? authClient;
    try {
      await jwtManager.initialize();
      log.info(
        '✓ JWT manager OK. device_id=${jwtManager.deviceId}',
      );
      late final http.Client innerClient;
      if (kDebugMode) {
        final httpClient = HttpClient()
          ..badCertificateCallback = (_, _, _) => true;
        innerClient = IOClient(httpClient);
      } else {
        innerClient = http.Client();
      }
      authClient = AuthenticatedHttpClient(
        tokenManager: jwtManager,
        inner: innerClient,
      );
    } catch (e) {
      jwtWarning =
          'Falha ao autenticar com o servidor. '
          'Downloads e sincronização podem não funcionar. ($e)';
      log.error('✗ JWT manager', e);
    }

    // ── 7. AppDatabase + DownloadService ─────────────────────────
    late final AppDatabase appDatabase;
    late final DownloadService downloadService;

    try {
      appDatabase = AppDatabase();
      await appDatabase.customSelect('SELECT 1').get();

      final downloadsRepo = DownloadsRepositoryImpl(appDatabase);
      downloadService = DownloadService.withRepository(
        downloadsRepo,
        httpClient: authClient,
      );
      await downloadService.initialize();
      log.info('✓ AppDatabase + DownloadService');
    } catch (e, st) {
      captureError('AppDatabase', e, st);
      rethrow;
    }

    // ── 8. Configurar auth client nos services PauloFlix ────────
    if (authClient != null) {
      PauloFlixService.configure(authClient);
      PauloFlixMoviesService.configure(authClient);
      log.info(
        '✓ Auth client configurado em services PauloFlix.',
      );
    } else {
      log.warning(
        '⚠ Sem authClient — services usam http.Client() default.',
      );
    }

    if (errors.isNotEmpty) {
      log.warning(
        '⚠ Inicialização concluída com ${errors.length} erro(s).',
      );
    }

    return InitializationResult(
      themeViewModel: themeViewModel,
      localeViewModel: localeViewModel,
      downloadService: downloadService,
      appDatabase: appDatabase,
      jwtManager: jwtManager,
      startupError: firstError,
      jwtWarning: jwtWarning,
    );
  }
}
