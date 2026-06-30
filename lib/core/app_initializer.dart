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

  InitializationResult({
    required this.themeViewModel,
    required this.localeViewModel,
    required this.downloadService,
    required this.appDatabase,
    required this.jwtManager,
    this.startupError,
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

    void captureError(String label, Object e) {
      final msg = '$label: $e';
      debugPrint('[AppInitializer] ✗ $msg');
      errors.add(msg);
      firstError ??= msg;
    }

    // ── 1. MediaKit ──────────────────────────────────────────────
    try {
      MediaKit.ensureInitialized();
      debugPrint('[AppInitializer] ✓ MediaKit');
    } catch (e) {
      captureError('MediaKit', e);
    }

    // ── 2. PerformanceConfig ─────────────────────────────────────
    try {
      PerformanceConfig.init();
      debugPrint('[AppInitializer] ✓ PerformanceConfig');
    } catch (e) {
      captureError('PerformanceConfig', e);
    }

    // ── 3. TVDetector (cache eager) ──────────────────────────────
    // Dispara a detecção de TV logo no startup para que o cache
    // esteja pronto quando a UI perguntar. A primeira chamada em
    // TV Android faz uma invocação via platform channel (~100ms);
    // as subsequentes retornam imediatamente do cache.
    try {
      final isTv = await TVDetector.isTV;
      debugPrint(
        '[AppInitializer] ✓ TVDetector (${isTv ? "TV" : "mobile"})',
      );
    } catch (e) {
      debugPrint('[AppInitializer] ⚠ TVDetector: $e');
    }

    // ── 4. ThemeViewModel ────────────────────────────────────────
    final themeViewModel = ThemeViewModel();
    try {
      await themeViewModel.load();
      debugPrint('[AppInitializer] ✓ ThemeViewModel');
    } catch (e) {
      captureError('ThemeViewModel', e);
    }

    // ── 5. LocaleViewModel ───────────────────────────────────────
    final localeViewModel = LocaleViewModel();
    try {
      await localeViewModel.load();
      debugPrint('[AppInitializer] ✓ LocaleViewModel');
    } catch (e) {
      captureError('LocaleViewModel', e);
    }

    // ══════════════════════════════════════════════════════════════
    // 6. JWT manager — DEVE rodar ANTES dos services que o usam
    // (DownloadService, PauloFlixService, PauloFlixMoviesService).
    // Em produção o base64 da chave privada está embutido no APK;
    // em dev com placeholder, falha e os services usam fallback.
    // ══════════════════════════════════════════════════════════════
    final jwtManager = JwtTokenManager();
    debugPrint('[AppInitializer] ▶ Inicializando JWT manager...');
    http.Client? authClient;
    try {
      await jwtManager.initialize();
      debugPrint(
        '[AppInitializer] ✓ JWT manager OK. device_id=${jwtManager.deviceId}',
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
      debugPrint('[AppInitializer] ✗ JWT manager: $e');
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
      debugPrint('[AppInitializer] ✓ AppDatabase + DownloadService');
    } catch (e) {
      captureError('AppDatabase', e);
      rethrow;
    }

    // ── 8. Configurar auth client nos services PauloFlix ────────
    if (authClient != null) {
      PauloFlixService.configure(authClient);
      PauloFlixMoviesService.configure(authClient);
      debugPrint(
        '[AppInitializer] ✓ Auth client configurado em services PauloFlix.',
      );
    } else {
      debugPrint(
        '[AppInitializer] ⚠ Sem authClient — services usam http.Client() default.',
      );
    }

    if (errors.isNotEmpty) {
      debugPrint(
        '[AppInitializer] ⚠ Inicialização concluída com ${errors.length} erro(s).',
      );
    }

    return InitializationResult(
      themeViewModel: themeViewModel,
      localeViewModel: localeViewModel,
      downloadService: downloadService,
      appDatabase: appDatabase,
      jwtManager: jwtManager,
      startupError: firstError,
    );
  }
}
