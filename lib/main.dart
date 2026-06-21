import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/connection/connection.dart';
import 'core/database/connection/migration_v1_to_v3.dart';
import 'data/services/download_service.dart';
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

  late final DownloadService downloadService;
  try {
    downloadService = DownloadService();
    await downloadService.initialize();
  } catch (e) {
    downloadService = DownloadService();
    startupError ??= 'DownloadService: $e';
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
  late final AppDatabase appDatabase;
  try {
    final dbPath = await resolvePauloflixDbPath();
    await prepareMigration(dbPath);
    appDatabase = AppDatabase();
    // Garante que as tabelas Drift foram criadas antes de migrar.
    // (Drift faz isso em onCreate na primeira abertura, mas aqui
    // disparamos via customSelect que lazy-inicializa a conexão.)
    await appDatabase.customSelect('SELECT 1').get();
    final legacyPaths = resolveLegacyDatabasePaths(dbPath);
    await migrateV1ToV3(target: appDatabase, legacy: legacyPaths);
  } catch (e) {
    startupError ??= 'AppDatabase: $e';
    // Fallback: rethrow no startup para evitar rodar app quebrado.
    rethrow;
  }

  runApp(
    PauloFlixApp(
      themeViewModel: themeViewModel,
      localeViewModel: localeViewModel,
      downloadService: downloadService,
      appDatabase: appDatabase,
      startupError: startupError,
    ),
  );
}
