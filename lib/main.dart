import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_initializer.dart';

void main() async {
  if (kDebugMode) {
    HttpOverrides.global = _DebugHttpOverrides();
  }

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

class _DebugHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, _, _) => true;
  }
}
