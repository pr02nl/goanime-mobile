import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/app.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/services/auth/jwt_token_manager.dart';
import 'package:goanime/data/repositories/downloads_repository_impl.dart';
import 'package:goanime/data/services/download_service.dart';
import 'package:goanime/ui/core/view_models/locale_viewmodel.dart';
import 'package:goanime/ui/settings/view_models/theme_viewmodel.dart';

void main() {
  testWidgets('renders PauloFlix app without errors', (tester) async {
    final themeViewModel = ThemeViewModel();
    final localeViewModel = LocaleViewModel();
    // :memory: em teste de widget — não toca em disco nem depende
    // de path_provider.
    final appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(appDatabase.close);
    final downloadService = DownloadService.withRepository(
      DownloadsRepositoryImpl(appDatabase),
    );

    // JwtTokenManager com chave placeholder. Em widget test, o manager
    // não é invocado (app não faz request PauloFlix), então o StateError
    // do placeholder não é disparado.
    final jwtManager = JwtTokenManager();

    await tester.pumpWidget(
      PauloFlixApp(
        themeViewModel: themeViewModel,
        localeViewModel: localeViewModel,
        downloadService: downloadService,
        appDatabase: appDatabase,
        jwtManager: jwtManager,
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
