import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/main.dart';
import 'package:goanime/providers/theme_provider.dart';
import 'package:goanime/services/download_service.dart';
import 'package:goanime/services/locale_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('renders GoAnime app without errors', (tester) async {
    // Cria instâncias dos serviços para o teste
    final themeProvider = ThemeProvider();
    final localeService = LocaleService();
    final downloadService = DownloadService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: localeService),
          ChangeNotifierProvider.value(value: downloadService),
        ],
        child: const MyApp(),
      ),
    );

    // Verifica se o MaterialApp foi renderizado
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Verifica se o widget MyApp foi renderizado
    expect(find.byType(MyApp), findsOneWidget);
  });
}
