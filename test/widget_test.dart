import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/app.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/services/download_service.dart';
import 'package:goanime/ui/core/view_models/locale_viewmodel.dart';
import 'package:goanime/ui/settings/view_models/theme_viewmodel.dart';

void main() {
  testWidgets('renders PauloFlix app without errors', (tester) async {
    final themeViewModel = ThemeViewModel();
    final localeViewModel = LocaleViewModel();
    final downloadService = DownloadService();
    // :memory: em teste de widget — não toca em disco nem depende
    // de path_provider.
    final appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(appDatabase.close);

    await tester.pumpWidget(
      PauloFlixApp(
        themeViewModel: themeViewModel,
        localeViewModel: localeViewModel,
        downloadService: downloadService,
        appDatabase: appDatabase,
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
