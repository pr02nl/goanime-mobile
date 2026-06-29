import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_initializer.dart';

void main() async {
  final result = await AppInitializer.initialize();

  runApp(
    PauloFlixApp(
      themeViewModel: result.themeViewModel,
      localeViewModel: result.localeViewModel,
      downloadService: result.downloadService,
      appDatabase: result.appDatabase,
      jwtManager: result.jwtManager,
      startupError: result.startupError,
    ),
  );
}
