import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/database/app_database.dart';
import 'core/logger/app_logger.dart';
import 'data/repositories/downloads_repository_impl.dart';
import 'data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'data/repositories/paulo_flix_movie_progress_repository_impl.dart';
import 'data/repositories/pauloflix_movies_repository_impl.dart';
import 'data/repositories/pauloflix_repository_impl.dart';
import 'data/repositories/watchlist_repository_impl.dart';
import 'data/services/auth/authenticated_cache_manager.dart';
import 'data/services/auth/jwt_token_manager.dart';
import 'data/services/download_service.dart';
import 'domain/repositories/downloads_repository.dart';
import 'domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'domain/repositories/paulo_flix_movie_progress_repository.dart';
import 'domain/repositories/pauloflix_movies_repository.dart';
import 'domain/repositories/pauloflix_repository.dart';
import 'domain/repositories/watchlist_repository.dart';
import 'l10n/app_localizations.dart';
import 'routing/app_router.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/core/view_models/locale_viewmodel.dart';
import 'ui/pauloflix/view_models/pauloflix_provider.dart';
import 'ui/pauloflix_movies/view_models/pauloflix_movies_provider.dart';
import 'ui/settings/view_models/theme_viewmodel.dart';
import 'ui/watchlist/view_models/watchlist_viewmodel.dart';

class PauloFlixApp extends StatelessWidget {
  final ThemeViewModel themeViewModel;
  final LocaleViewModel localeViewModel;
  final DownloadService downloadService;
  final AppDatabase appDatabase;
  final JwtTokenManager jwtManager;
  final String? startupError;
  final String? jwtWarning;

  const PauloFlixApp({
    super.key,
    required this.themeViewModel,
    required this.localeViewModel,
    required this.downloadService,
    required this.appDatabase,
    required this.jwtManager,
    this.startupError,
    this.jwtWarning,
  });

  @override
  Widget build(BuildContext context) {
    final router = createAppRouter(initialError: startupError);

    // Configura o cache manager global do `cached_network_image` para
    // injetar `Authorization: Bearer` em TODA request de imagem.
    CachedNetworkImageProvider.defaultCacheManager = AuthenticatedCacheManager(
      jwtManager,
    );

    return MultiProvider(
      providers: [
        // AppDatabase (singleton de processo).
        Provider<AppDatabase>.value(value: appDatabase),
        // Repositories.
        Provider<WatchlistRepository>(
          create: (_) => WatchlistRepositoryImpl(appDatabase),
        ),
        Provider<PauloFlixRepository>(
          create: (_) => PauloFlixRepositoryImpl(appDatabase),
        ),
        Provider<PauloFlixMoviesRepository>(
          create: (_) => PauloFlixMoviesRepositoryImpl(appDatabase),
        ),
        Provider<DownloadsRepository>(
          create: (_) => DownloadsRepositoryImpl(appDatabase),
        ),
        Provider<PauloFlixEpisodeProgressRepository>(
          create: (_) => PauloFlixEpisodeProgressRepositoryImpl(appDatabase),
        ),
        Provider<PauloFlixMovieProgressRepository>(
          create: (_) => PauloFlixMovieProgressRepositoryImpl(appDatabase),
        ),
        // Auth: JwtTokenManager.
        Provider<JwtTokenManager>.value(value: jwtManager),
        // Aviso de JWT (exibido como snackbar no HomeScreen).
        if (jwtWarning != null) Provider<String>.value(value: jwtWarning!),
        // Services e viewmodels.
        ChangeNotifierProvider.value(value: themeViewModel),
        ChangeNotifierProvider.value(value: localeViewModel),
        ChangeNotifierProvider.value(value: downloadService),
        ChangeNotifierProvider(
          create: (ctx) => PauloFlixProvider.withRepository(
            repository: ctx.read<PauloFlixRepository>(),
            episodeProgressRepository: ctx
                .read<PauloFlixEpisodeProgressRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => PauloFlixMoviesProvider.withServices(
            repository: ctx.read<PauloFlixMoviesRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              WatchlistViewModel(repository: ctx.read<WatchlistRepository>()),
        ),
      ],
      child: _BackgroundSyncWrapper(
        child: ListenableBuilder(
          listenable: themeViewModel,
          builder: (context, _) {
            return MaterialApp.router(
              title: 'PauloFlix',
              debugShowCheckedModeBanner: false,
              routerConfig: router,
              locale: localeViewModel.locale,
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
      ),
    );
  }
}

/// Wrapper que dispara sync em background a cada 30 minutos.
///
/// Colocado dentro do `MultiProvider` para ter acesso aos providers
/// de conteúdo. O timer é cancelado no dispose. Cada tick chama
/// `syncContent()` em ambos os providers — os services internamente
/// verificam o `updated_at` do JSON index e pulam se nada mudou.
class _BackgroundSyncWrapper extends StatefulWidget {
  final Widget child;
  const _BackgroundSyncWrapper({required this.child});

  @override
  State<_BackgroundSyncWrapper> createState() => _BackgroundSyncWrapperState();
}

class _BackgroundSyncWrapperState extends State<_BackgroundSyncWrapper> {
  @override
  void initState() {
    super.initState();
    // Dispara o primeiro sync assim que a árvore estiver montada.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncNow());
  }

  void _syncNow() {
    try {
      context.read<PauloFlixProvider>().syncContent();
    } catch (e, st) {
      const AppLogger('BackgroundSync').error('Erro no sync de animes', e, st);
    }
    try {
      context.read<PauloFlixMoviesProvider>().syncContent();
    } catch (e, st) {
      const AppLogger('BackgroundSync').error('Erro no sync de filmes', e, st);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
