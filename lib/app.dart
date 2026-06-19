import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'providers/pauloflix_movies_provider.dart';
import 'providers/pauloflix_provider.dart';
import 'providers/theme_provider.dart';
import 'routing/app_router.dart';
import 'services/download_service.dart';
import 'services/locale_service.dart';
import 'theme/app_theme.dart';

class PauloFlixApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final LocaleService localeService;
  final DownloadService downloadService;
  final String? startupError;

  const PauloFlixApp({
    super.key,
    required this.themeProvider,
    required this.localeService,
    required this.downloadService,
    this.startupError,
  });

  @override
  Widget build(BuildContext context) {
    final router = createAppRouter(initialError: startupError);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: localeService),
        ChangeNotifierProvider.value(value: downloadService),
        ChangeNotifierProvider(create: (_) => PauloFlixProvider()),
        ChangeNotifierProvider(create: (_) => PauloFlixMoviesProvider()),
      ],
      child: ListenableBuilder(
        listenable: themeProvider,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'PauloFlix',
            debugShowCheckedModeBanner: false,
            routerConfig: router,
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
          );
        },
      ),
    );
  }
}
