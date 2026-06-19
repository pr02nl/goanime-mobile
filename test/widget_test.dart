import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/app.dart';
import 'package:goanime/providers/theme_provider.dart';
import 'package:goanime/services/download_service.dart';
import 'package:goanime/services/locale_service.dart';

void main() {
  testWidgets('renders PauloFlix app without errors', (tester) async {
    final themeProvider = ThemeProvider();
    final localeService = LocaleService();
    final downloadService = DownloadService();

    await tester.pumpWidget(
      PauloFlixApp(
        themeProvider: themeProvider,
        localeService: localeService,
        downloadService: downloadService,
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
