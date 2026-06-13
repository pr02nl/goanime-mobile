import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'helpers/database_helper.dart';
import 'l10n/app_localizations.dart';
import 'providers/pauloflix_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'services/download_service.dart';
import 'services/locale_service.dart';
import 'theme/app_theme.dart';
import 'utils/performance_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit
  MediaKit.ensureInitialized();

  // Inicializa configurações de performance
  PerformanceConfig.init();

  // Initialize download service
  final downloadService = DownloadService();
  await downloadService.initialize();

  // Cria instância do ThemeProvider para uso global
  final themeProvider = ThemeProvider();

  // Inicializar banco de dados
  await DatabaseHelper.initializeAll();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => LocaleService()),
        ChangeNotifierProvider.value(value: downloadService),
        ChangeNotifierProvider(create: (_) => PauloFlixProvider()),
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
  @override
  Widget build(BuildContext context) {
    final localeService = Provider.of<LocaleService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ListenableBuilder(
      listenable: themeProvider,
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
          // Use unified AppTheme (Netflix-style with GoAnime colors)
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}
