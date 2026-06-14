import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/content_type_selector.dart';
import 'downloads_screen.dart';
import 'home_screen.dart';
import 'pauloflix_movies_home_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final double _headerOpacity = 1.0;

  // Tipo de conteúdo ativo: animes ou filmes.
  // Animes = HomeScreen atual; Filmes = PauloFlixMoviesHomeScreen.
  ContentType _contentType = ContentType.anime;

  // FocusNodes for each nav item so TV d-pad can move between them.
  // Mantidos como campos da classe para que o dispose os limpe,
  // mas só as primeiras 4 entradas são usadas para a tab inferior real.
  final List<FocusNode> _navFocusNodes = List.generate(5, (_) => FocusNode());

  @override
  void dispose() {
    for (final node in _navFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _navigateToHome() {
    setState(() {
      _currentIndex = 0;
    });
  }

  void _onContentTypeChanged(ContentType type) {
    if (_contentType == type) return;
    setState(() {
      _contentType = type;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Construímos a lista em todo build. O `IndexedStack` mantém o estado
    // dos filhos pelo índice, então não há perda de scroll/state ao trocar
    // o tipo de conteúdo.
    final screens = <Widget>[
      _contentType == ContentType.anime
          ? const HomeScreen()
          : const PauloFlixMoviesHomeScreen(),
      const SearchScreen(),
      const WatchlistScreen(),
      const DownloadsScreen(),
      SettingsScreen(onBackPressed: _navigateToHome),
    ];

    return PopScope(
      canPop: _currentIndex == 0 && _contentType == ContentType.anime,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Primeira prioridade: voltar para Animes
          if (_contentType == ContentType.movie) {
            setState(() {
              _contentType = ContentType.anime;
              _currentIndex = 0;
            });
            return;
          }
          // Depois: voltar para Home
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: IndexedStack(index: _currentIndex, children: screens),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _headerOpacity > 0
          ? AppColors.background.withValues(alpha: 0.95)
          : Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      flexibleSpace: _headerOpacity > 0
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
            )
          : null,
      title: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _contentType == ContentType.anime
                  ? const HomeScreen()
                  : const PauloFlixMoviesHomeScreen(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.play_circle_filled,
            color: Colors.white,
          ),
        ),
      ),
      centerTitle: false,
      actions: [
        // Toggle entre Animes e Filmes
        ContentTypeSelector(
          selected: _contentType,
          onChanged: _onContentTypeChanged,
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
          tooltip: 'Search',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.bookmark, color: Colors.white, size: 24),
          tooltip: 'Bookmarks',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WatchlistScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
