import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/theme_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'services/download_service.dart';
import 'services/locale_service.dart';
import 'theme/tv_theme.dart';
import 'utils/performance_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa configurações de performance
  PerformanceConfig.init();

  // Initialize download service
  final downloadService = DownloadService();
  await downloadService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleService()),
        ChangeNotifierProvider.value(value: downloadService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    final localeService = Provider.of<LocaleService>(context);

    return AnimatedBuilder(
      animation: _themeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'GoAnime',
          debugShowCheckedModeBanner: false,
          locale: localeService.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: TVTheme.lightTheme,
          darkTheme: TVTheme.darkTheme,
          themeMode: _themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}
