import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/database/database_helper.dart';
import 'data/services/tmdb_service.dart';
import 'services/download_service.dart';
import 'services/locale_service.dart';
import 'ui/settings/view_models/theme_viewmodel.dart';
import 'utils/performance_config.dart';

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
  final localeService = LocaleService();

  try {
    await themeViewModel.load();
  } catch (e) {
    startupError ??= 'ThemeViewModel: $e';
  }

  try {
    await localeService.init();
  } catch (e) {
    startupError ??= 'LocaleService: $e';
  }

  try {
    await TmdbService().configureFromSettings();
  } catch (e) {
    startupError ??= 'TMDB: $e';
  }

  try {
    await DatabaseHelper.initializeAll();
  } catch (e) {
    startupError ??= 'Database: $e';
  }

  runApp(
    PauloFlixApp(
      themeViewModel: themeViewModel,
      localeService: localeService,
      downloadService: downloadService,
      startupError: startupError,
    ),
  );
}
