import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/app.dart';
import 'package:goanime/data/services/download_service.dart';
import 'package:goanime/data/services/locale_service.dart';
import 'package:goanime/ui/settings/view_models/theme_viewmodel.dart';

void main() {
  testWidgets('renders PauloFlix app without errors', (tester) async {
    final themeViewModel = ThemeViewModel();
    final localeService = LocaleService();
    final downloadService = DownloadService();

    await tester.pumpWidget(
      PauloFlixApp(
        themeViewModel: themeViewModel,
        localeService: localeService,
        downloadService: downloadService,
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
