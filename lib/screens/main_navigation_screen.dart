import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/content_type_selector.dart';
import '../widgets/focusable_widget.dart';
import 'home_screen.dart';
import 'pauloflix_movies_home_screen.dart';
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
  /// Usado em dois lugares:
  /// - Toggle Animes/Filmes (pushReplacement)
  /// - back físico que precisa voltar para Animes (pushReplacement)
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

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
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
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _openRootHome() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _buildRootScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // canPop só liberado quando estamos nos Animes na raiz: isso garante
    // que o back físico sempre volte para Animes primeiro (se estiver em
    // Filmes) ou então saia do app (se já estiver em Animes).
    final canExitApp = _contentType == ContentType.anime;

    return PopScope(
      canPop: canExitApp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Primeira prioridade: voltar para Animes
        if (_contentType == ContentType.movie) {
          _setRootContent(ContentType.anime);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: _buildRootScreen(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background.withValues(alpha: 0.95),
      elevation: 0,
      toolbarHeight: 64,
      // FocusableWidget: logo do AppBar volta para a root-home via d-pad
      // em TV (Enter/Select). Em mobile/tablet cai no fallback GestureDetector
      // puro (lib/widgets/focusable_widget.dart:115), preservando o tap.
      // focusScale: 1.0 evita que a box-shadow do logo seja cortada pelo
      // Transform.scale do widget (a sombra ultrapassa o container).
      title: FocusableWidget(
        onSelect: _openRootHome,
        borderRadius: 12,
        focusPadding: EdgeInsets.zero,
        focusScale: 1.0,
        child: Container(
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
          child: const Icon(
            Icons.play_circle_filled,
            color: Colors.white,
          ),
        ),
      ),
      centerTitle: false,
      actions: [
        ContentTypeSelector(
          selected: _contentType,
          onChanged: _setRootContent,
        ),
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
