import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'core/database/app_database.dart';
import 'data/repositories/downloads_repository_impl.dart';
import 'data/repositories/home_repository_impl.dart';
import 'data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'data/repositories/paulo_flix_movie_progress_repository_impl.dart';
import 'data/repositories/pauloflix_movies_repository_impl.dart';
import 'data/repositories/pauloflix_repository_impl.dart';
import 'data/repositories/watchlist_repository_impl.dart';
import 'data/services/auth/authenticated_cache_manager.dart';
import 'data/services/auth/authenticated_http_client.dart';
import 'data/services/auth/jwt_token_manager.dart';
import 'data/services/download_service.dart';
import 'data/services/kodi/pauloflix_nfo_enricher.dart';
import 'data/services/paulo_flix_episode_sync_service.dart';
import 'domain/repositories/downloads_repository.dart';
import 'domain/repositories/home_repository.dart';
import 'domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'domain/repositories/paulo_flix_movie_progress_repository.dart';
import 'domain/repositories/pauloflix_movies_repository.dart';
import 'domain/repositories/pauloflix_repository.dart';
import 'domain/repositories/watchlist_repository.dart';
import 'l10n/app_localizations.dart';
import 'routing/app_router.dart';
import 'ui/core/themes/app_theme.dart';
import 'ui/core/view_models/locale_viewmodel.dart';
import 'ui/home/view_models/home_viewmodel.dart';
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

  const PauloFlixApp({
    super.key,
    required this.themeViewModel,
    required this.localeViewModel,
    required this.downloadService,
    required this.appDatabase,
    required this.jwtManager,
    this.startupError,
  });

  @override
  Widget build(BuildContext context) {
    final router = createAppRouter(initialError: startupError);

    // Configura o cache manager global do `cached_network_image` para
    // injetar `Authorization: Bearer` em TODA request de imagem.
    // O servidor PauloFlix exige token em todos os endpoints
    // (mesmo os de imagem) desde a migração Tailscale → HTTPS+token.
    // Sem isto, ~80 call sites de `CachedNetworkImage` mostravam
    // placeholder cinza (401 Unauthorized).
    //
    // Por que `defaultCacheManager` e não `httpHeaders` em cada
    // widget: 1 linha cobre todos os usos atuais E futuros
    // (qualquer widget novo herda o auth automaticamente).
    CachedNetworkImageProvider.defaultCacheManager = AuthenticatedCacheManager(
      jwtManager,
    );

    return MultiProvider(
      providers: [
        // AppDatabase (singleton de processo) — FASE 3.
        Provider<AppDatabase>.value(value: appDatabase),
        // Repositories — FASE 3.
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
        // Fase 4 — providers do plano de progresso PauloFlix.
        Provider<PauloFlixEpisodeProgressRepository>(
          create: (_) => PauloFlixEpisodeProgressRepositoryImpl(appDatabase),
        ),
        // P1 — progresso de filmes PauloFlix Movies.
        Provider<PauloFlixMovieProgressRepository>(
          create: (_) => PauloFlixMovieProgressRepositoryImpl(appDatabase),
        ),
        // O `PauloFlixEpisodeSyncService` é usado em 2 lugares:
        // 1. `PauloFlixEpisodeProgressViewModel` (sync on-demand ao
        //    abrir a tela de episodes).
        // 2. `ModernVideoPlayerScreen` (não precisa — o player lê do
        //    banco via repo, não faz sync).
        // Injetado via `http.Client()` real (não mockado em produção).
        //
        // IMPORTANTE: NÃO usar `create: (_) => context.read<Repo>(...)`
        // aqui — o `create:` callback de providers dentro de um
        // `MultiProvider` recebe um `context` que é ANCESTRAL de
        // todos os providers declarados no mesmo list. Isso causa
        // `ProviderNotFoundException` em runtime. Use o ctor
        // `fromDatabase(appDatabase)` que constrói o repo internamente.
        // O `appDatabase` está disponível como field da `PauloFlixApp`.
        // IMPORTANTE: ordem importa — `PauloFlixEpisodeSyncService` precisa
        // do `jwtManager` (criado em main.dart), então construímos o
        // `AuthenticatedHttpClient` inline no `create:` em vez de via
        // Provider separado (gotcha #9: dependência circular em
        // MultiProvider).
        Provider<PauloFlixEpisodeSyncService>(
          create: (_) => PauloFlixEpisodeSyncService.fromDatabase(
            appDatabase,
            httpClient: AuthenticatedHttpClient(
              tokenManager: jwtManager,
              inner: http.Client(),
            ),
          ),
        ),
        // Auth: JwtTokenManager (gera/renova tokens) + AuthenticatedHttpClient
        // (wrapper que injeta Authorization em toda request).
        // O JwtTokenManager foi inicializado em main.dart; aqui só o
        // expomos via Provider para que outros lugares (player, sync) possam
        // recriar o client autenticado se necessário.
        Provider<JwtTokenManager>.value(value: jwtManager),
        // NOTA: AuthenticatedHttpClient JÁ foi criado acima (no
        // PauloFlixEpisodeSyncService) e no NfoEnricherProvider abaixo.
        // Não criamos um Provider<AuthenticatedHttpClient> aqui para
        // evitar múltiplas instâncias — cada service que precisa de
        // auth cria o seu via construtor. Se quiser um único compartilhado,
        // seria preciso reordenar os providers pra colocar o auth
        // primeiro (gotcha #9).
        // NFO Enricher (Fase 3 do plano NFO enrichment) — orquestrador
        // HTTP que faz GET de `tvshow.nfo` / `movie.nfo` / `episode thumbs`
        // do servidor PauloFlix. Usa o `AuthenticatedHttpClient` injetado
        // para reaproveitar o JWT manager.
        //
        // IMPORTANTE (pitfall #9 do flutter-reactivity-gotchas):
        // `ProviderNotFoundException` em `create:` callback de
        // `MultiProvider` se este provider for declarado **depois** de
        // quem fizer `ctx.read<PauloFlixNfoEnricher>()` no `create:`.
        // Deve estar **antes** de qualquer consumer (atualmente o
        // `PauloFlixService` em `PauloFlixProvider.withRepositories`).
        // Também é seguro injetar `dispose` para fechar o `inner`
        // `http.Client` (gotcha: BaseClient sem dispose vaza socket).
        Provider<PauloFlixNfoEnricher>(
          create: (_) => PauloFlixNfoEnricher(
            client: AuthenticatedHttpClient(
              tokenManager: jwtManager,
              inner: http.Client(),
            ),
          ),
          dispose: (_, enricher) => enricher.dispose(),
        ),
        // Services e viewmodels legados.
        ChangeNotifierProvider.value(value: themeViewModel),
        ChangeNotifierProvider.value(value: localeViewModel),
        ChangeNotifierProvider.value(value: downloadService),
        ChangeNotifierProvider(
          create: (ctx) => PauloFlixProvider.withRepositories(
            repository: ctx.read<PauloFlixRepository>(),
            episodeSyncService: ctx.read<PauloFlixEpisodeSyncService>(),
            episodeProgressRepository: ctx
                .read<PauloFlixEpisodeProgressRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => PauloFlixMoviesProvider.withServices(
            repository: ctx.read<PauloFlixMoviesRepository>(),
            // Fase 4 (NFO enrichment) — injeta o enricher. Provider
            // declarado **antes** deste na lista (acima), portanto
            // `ctx.read<PauloFlixNfoEnricher>()` está disponível sem
            // `ProviderNotFoundException` (mesmo pitfall #9 do
            // `PauloFlixProvider`).
            nfoEnricher: ctx.read<PauloFlixNfoEnricher>(),
          ),
        ),
        Provider<HomeRepository>(create: (_) => HomeRepositoryImpl()),
        ChangeNotifierProvider(
          create: (ctx) =>
              HomeViewModel(repository: ctx.read<HomeRepository>())
                ..loadHomeData(),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              WatchlistViewModel(repository: ctx.read<WatchlistRepository>())
                ..loadWatchlist(),
        ),
      ],
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
    );
  }
}
