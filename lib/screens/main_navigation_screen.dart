import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/content_type_selector.dart';
import 'home_screen.dart';
import 'pauloflix_movies_home_screen.dart';
import 'pauloflix_movies_search_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';

/// Tela raiz do app após o splash.
///
/// Após a modernização para incluir PauloFlix Movies, esta tela abandonou o
/// padrão antigo de [IndexedStack] + `_currentIndex` que misturava dois sistemas
/// de navegação conflitantes com o [Navigator.push] usado pelo resto do AppBar.
///
/// Agora a única fonte de verdade é o [Navigator]:
/// - O body mostra a tela raiz conforme o [_contentType] ativo
/// - Sempre que o usuário alterna Animes/Filmes, substituímos a tela raiz
///   substituindo o widget raiz do Navigator via [Navigator.pushReplacement]
/// - Botões do AppBar continuam usando [Navigator.push] como sempre fizeram
///
/// Benefícios:
/// - Memória: só 1 tela pesada montada por vez (em vez de 5 no IndexedStack)
/// - Back button previsível: volta para a tela raiz não-Filmes quando aplicável
/// - Sem estado morto (`_currentIndex` removido)
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  /// Tipo de conteúdo ativo: animes ou filmes.
  ContentType _contentType = ContentType.anime;

  // Gera uma Key por conteúdo para forçar remontagem quando o usuário
  // alterna entre Animes e Filmes (necessário porque uma vez que a tela
  // raiz foi empurrada via push* ela permanece).
  Key _rootKey = UniqueKey();

  /// Substitui a tela raiz do Navigator pela Home/Movies conforme [type].
  void _setRootContent(ContentType type) {
    if (_contentType == type) return;
    setState(() {
      _contentType = type;
      _rootKey = UniqueKey();
    });
  }

  Widget _buildRootScreen() {
    return KeyedSubtree(
      key: _rootKey,
      child: _contentType == ContentType.anime
          ? const HomeScreen()
          : const PauloFlixMoviesHomeScreen(),
    );
  }

  /// Roteia para a tela de busca adequada conforme o [_contentType] ativo.
  void _openSearch() {
    final Widget target = _contentType == ContentType.movie
        ? const PauloFlixMoviesSearchScreen()
        : const SearchScreen();
    Navigator.push(context, MaterialPageRoute(builder: (context) => target));
  }

  void _openWatchlist() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WatchlistScreen()),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canExitApp = _contentType == ContentType.anime;

    return PopScope(
      canPop: canExitApp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_contentType == ContentType.movie) {
          _setRootContent(ContentType.anime);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        // extendBodyBehindAppBar removido: o HomeScreen já tem seu próprio
        // Scaffold com extendBodyBehindAppBar:true para o hero funcionar.
        // Colocar aqui causava o AppBar transparente flutuar sobre todas
        // as telas, incluindo filmes e busca que não têm hero.
        appBar: _buildAppBar(),
        body: _buildRootScreen(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // AppBar sólida mas discreta — fundo quase preto com leve elevação
      // visual. O HomeScreen usa extendBodyBehindAppBar próprio + hero
      // que começa diretamente abaixo da AppBar.
      backgroundColor: AppColors.background.withValues(alpha: 0.97),
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      title: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
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
        child: const Icon(Icons.play_circle_filled, color: Colors.white),
      ),
      centerTitle: false,
      actions: [
        ContentTypeSelector(selected: _contentType, onChanged: _setRootContent),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
          tooltip: 'Search',
          onPressed: _openSearch,
        ),
        IconButton(
          icon: const Icon(Icons.bookmark, color: Colors.white, size: 24),
          tooltip: 'Bookmarks',
          onPressed: _openWatchlist,
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Settings',
          onPressed: _openSettings,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
