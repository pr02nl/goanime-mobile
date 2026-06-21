import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/connection/connection.dart';
import 'core/database/connection/migration_v1_to_v3.dart';
import 'data/repositories/downloads_repository_impl.dart';
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
    final dbPath = await resolvePauloflixDbPath();
    final prepared = await prepareMigration(dbPath);
    appDatabase = AppDatabase();
    // Garante que as tabelas Drift foram criadas antes de migrar.
    await appDatabase.customSelect('SELECT 1').get();
    await migrateV1ToV3(target: appDatabase, legacy: prepared.legacyPaths);
    // Cria o DownloadService com o repository (Fase 3) e inicializa.
    final downloadsRepo = DownloadsRepositoryImpl(appDatabase);
    realDownloadService = DownloadService.withRepository(downloadsRepo);
    await realDownloadService.initialize();
  } catch (e) {
    startupError ??= 'AppDatabase: $e';
    rethrow;
  }

  runApp(
    PauloFlixApp(
      themeViewModel: themeViewModel,
      localeViewModel: localeViewModel,
      downloadService: realDownloadService,
      appDatabase: appDatabase,
      startupError: startupError,
    ),
  );
}
