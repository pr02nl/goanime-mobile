import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/repositories/home_repository_impl.dart';
import 'data/services/download_service.dart';
import 'data/services/locale_service.dart';
import 'domain/repositories/home_repository.dart';
import 'l10n/app_localizations.dart';
import 'routing/app_router.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/home/view_models/home_viewmodel.dart';
import 'ui/pauloflix/view_models/pauloflix_provider.dart';
import 'ui/pauloflix_movies/view_models/pauloflix_movies_provider.dart';
import 'ui/settings/view_models/theme_viewmodel.dart';
import 'ui/watchlist/view_models/watchlist_viewmodel.dart';

class PauloFlixApp extends StatelessWidget {
  final ThemeViewModel themeViewModel;
  final LocaleService localeService;
  final DownloadService downloadService;
  final String? startupError;

  const PauloFlixApp({
    super.key,
    required this.themeViewModel,
    required this.localeService,
    required this.downloadService,
    this.startupError,
  });

  @override
  Widget build(BuildContext context) {
    final router = createAppRouter(initialError: startupError);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeViewModel),
        ChangeNotifierProvider.value(value: localeService),
        ChangeNotifierProvider.value(value: downloadService),
        ChangeNotifierProvider(create: (_) => PauloFlixProvider()),
        ChangeNotifierProvider(create: (_) => PauloFlixMoviesProvider()),
        Provider<HomeRepository>(create: (_) => HomeRepositoryImpl()),
        ChangeNotifierProvider(
          create: (ctx) =>
              HomeViewModel(repository: ctx.read<HomeRepository>())
                ..loadHomeData(),
        ),
        ChangeNotifierProvider(
          create: (_) => WatchlistViewModel()..loadWatchlist(),
        ),
      ],
      child: ListenableBuilder(
        listenable: themeViewModel,
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
            themeMode: themeViewModel.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
          );
        },
      ),
    );
  }
}
