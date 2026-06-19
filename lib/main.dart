import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'helpers/database_helper.dart';
import 'l10n/app_localizations.dart';
import 'providers/pauloflix_movies_provider.dart';
import 'providers/pauloflix_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'services/download_service.dart';
import 'services/locale_service.dart';
import 'services/tmdb_service.dart';
import 'theme/app_theme.dart';
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

  final themeProvider = ThemeProvider();
  final localeService = LocaleService();

  try {
    await themeProvider.load();
  } catch (e) {
    startupError ??= 'ThemeProvider: $e';
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
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: localeService),
        ChangeNotifierProvider.value(value: downloadService),
        ChangeNotifierProvider(create: (_) => PauloFlixProvider()),
        ChangeNotifierProvider(create: (_) => PauloFlixMoviesProvider()),
      ],
      child: MyApp(startupError: startupError),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String? startupError;
  const MyApp({super.key, this.startupError});

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
          title: 'PauloFlix',
          debugShowCheckedModeBanner: false,
          locale: localeService.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: widget.startupError != null
              ? _StartupErrorScreen(widget.startupError!)
              : const MainNavigationScreen(),
        );
      },
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final String error;
  const _StartupErrorScreen(this.error);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFE94560), size: 64),
              const SizedBox(height: 24),
              const Text(
                'Falha ao iniciar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh),
                label: const Text('Reinicie o aplicativo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE94560),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
