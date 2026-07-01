import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/pauloflix_content.dart';
import '../domain/models/pauloflix_movie.dart';
import '../ui/downloads/widgets/downloads_screen.dart';
import '../ui/home/widgets/home_screen.dart';
import '../ui/navigation/main_navigation_screen.dart';
import '../ui/pauloflix/widgets/pauloflix_episode_list_screen.dart';
import '../ui/pauloflix/widgets/pauloflix_search_screen.dart';
import '../ui/pauloflix/widgets/pauloflix_see_all_screen.dart';
import '../ui/pauloflix_movies/widgets/pauloflix_movie_detail_screen.dart';
import '../ui/pauloflix_movies/widgets/pauloflix_movies_home_screen.dart';
import '../ui/pauloflix_movies/widgets/pauloflix_movies_search_screen.dart';
import '../ui/player/widgets/blogger_webview_screen.dart';
import '../ui/player/widgets/video_player_screen.dart';
import '../ui/search/widgets/search_screen.dart';
import '../ui/settings/widgets/settings_screen.dart';
import '../ui/watchlist/widgets/watchlist_screen.dart';
import 'route_data.dart';

GoRouter createAppRouter({String? initialError}) {
  return GoRouter(
    initialLocation: initialError != null ? '/error' : '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainNavigationScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/watchlist',
            name: 'watchlist',
            builder: (context, state) => const WatchlistScreen(),
          ),
          GoRoute(
            path: '/downloads',
            name: 'downloads',
            builder: (context, state) => const DownloadsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/pauloflix-movies',
            name: 'pauloflix-movies',
            builder: (context, state) => const PauloFlixMoviesHomeScreen(),
          ),
          GoRoute(
            path: '/pauloflix-see-all',
            name: 'pauloflix-see-all',
            builder: (context, state) => const PauloFlixSeeAllScreen(),
          ),
          GoRoute(
            path: '/error',
            name: 'error',
            builder: (context, state) =>
                _startupErrorScreen(initialError ?? 'Erro desconhecido'),
          ),
        ],
      ),
      GoRoute(
        path: '/pauloflix-search',
        name: 'pauloflix-search',
        builder: (context, state) => const PauloFlixSearchScreen(),
      ),
      GoRoute(
        path: '/pauloflix-movies/search',
        name: 'pauloflix-movies-search',
        builder: (context, state) => const PauloFlixMoviesSearchScreen(),
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        builder: (context, state) {
          final data = state.extra as PlayerRouteData;
          return ModernVideoPlayerScreen(
            episode: data.episode,
            animeTitle: data.animeTitle,
            anime: data.anime,
            isMovie: data.isMovie,
            episodeIndex: data.episodeIndex,
            contentId: data.contentId,
            movieFolderName: data.movieFolderName,
            seasonId: data.seasonId,
            seasonNumber: data.seasonNumber,
            episodeNumber: data.episodeNumber,
            tmdbId: data.tmdbId,
          );
        },
      ),
      GoRoute(
        path: '/pauloflix-episodes',
        name: 'pauloflix-episodes',
        builder: (context, state) {
          final content = state.extra as PauloFlixContent;
          return PauloFlixEpisodeListScreen(content: content);
        },
      ),
      GoRoute(
        path: '/pauloflix-movie-detail',
        name: 'pauloflix-movie-detail',
        builder: (context, state) {
          final movie = state.extra as PauloFlixMovie;
          return PauloFlixMovieDetailScreen(content: movie);
        },
      ),
      GoRoute(
        path: '/blogger-webview',
        name: 'blogger-webview',
        builder: (context, state) {
          final data = state.extra as WebViewRouteData;
          return BloggerWebViewScreen(initialUrl: data.url, title: data.title);
        },
      ),
    ],
  );
}

Widget _startupErrorScreen(String error) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
