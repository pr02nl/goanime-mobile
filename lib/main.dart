import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'data/repositories/downloads_repository_impl.dart';
import 'data/services/auth/authenticated_http_client.dart';
import 'data/services/auth/jwt_token_manager.dart';
import 'data/services/download_service.dart';
import 'data/services/pauloflix_movies_service.dart';
import 'data/services/pauloflix_service.dart';
import 'data/services/tmdb_service.dart';
import 'ui/core/utils/performance_config.dart';
import 'ui/core/view_models/locale_viewmodel.dart';
import 'ui/settings/view_models/theme_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;

  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    startupError = 'MediaKit: $e';
  }

  try {
    PerformanceConfig.init();
  } catch (e) {
    startupError ??= 'PerformanceConfig: $e';
  }

  final themeViewModel = ThemeViewModel();
  final localeViewModel = LocaleViewModel();

  try {
    await themeViewModel.load();
  } catch (e) {
    startupError ??= 'ThemeViewModel: $e';
  }

  try {
    await localeViewModel.load();
  } catch (e) {
    startupError ??= 'LocaleViewModel: $e';
  }

  try {
    await TmdbService().configureFromSettings();
  } catch (e) {
    startupError ??= 'TMDB: $e';
  }

  // FASE 3 — Drift AppDatabase:
  // 1. Resolve o path do banco unificado (pauloflix.db).
  // 2. Renomeia o banco legado (se existir) para liberar o path.
  // 3. Cria AppDatabase e roda a migration v1→v3 (popula o Drift com
  //    dados dos 4 bancos legados).
  // 4. Usa `prepared.legacyPaths` (retorno do prepareMigration) que
  //    já contém os paths corretos pós-rename — ver bugfix Fase 4.
  late final AppDatabase appDatabase;
  late final DownloadService realDownloadService;
  try {
    // final dbPath = await resolvePauloflixDbPath();
    appDatabase = AppDatabase();
    // Garante que as tabelas Drift foram criadas antes de migrar.
    await appDatabase.customSelect('SELECT 1').get();
    // Cria o DownloadService com o repository (Fase 3) e inicializa.
    final downloadsRepo = DownloadsRepositoryImpl(appDatabase);
    realDownloadService = DownloadService.withRepository(downloadsRepo);
    await realDownloadService.initialize();
  } catch (e) {
    startupError ??= 'AppDatabase: $e';
    rethrow;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Migração Tailscale → HTTPS+token: inicializa o JWT manager e
  // configura o AuthenticatedHttpClient nos services PauloFlix.
  // O initialize() pode falhar se a chave privada ainda for placeholder
  // (proteção contra build acidental). Em produção real, o base64
  // já está embutido no APK.
  // ═══════════════════════════════════════════════════════════════════════
  final jwtManager = JwtTokenManager();
  // ignore: avoid_print
  print('[PauloFlixAuth] ▶ Inicializando JWT manager...');
  try {
    await jwtManager.initialize();
    // ignore: avoid_print
    print(
      '[PauloFlixAuth] ✓ JWT manager OK. device_id=${jwtManager.deviceId}',
    );
    final authClient = AuthenticatedHttpClient(
      tokenManager: jwtManager,
      inner: http.Client(),
    );
    // Injeta o client nos services estáticos PauloFlix.
    // Nota: o PauloFlixEpisodeSyncService já aceita client via ctor
    // (criado em app.dart) e não precisa de configure.
    PauloFlixService.configure(authClient);
    PauloFlixMoviesService.configure(authClient);
    // ignore: avoid_print
    print('[PauloFlixAuth] ✓ Auth client configurado nos services PauloFlix.');
  } catch (e) {
    // Se falhar (placeholder), os services usam http.Client() default
    // e os requests vão dar 401. Loga mas não bloqueia o app.
    // ignore: avoid_print
    print('[PauloFlixAuth] ✗ Falha ao inicializar: $e');
  }

  runApp(
    PauloFlixApp(
      themeViewModel: themeViewModel,
      localeViewModel: localeViewModel,
      downloadService: realDownloadService,
      appDatabase: appDatabase,
      jwtManager: jwtManager,
      startupError: startupError,
    ),
  );
}
