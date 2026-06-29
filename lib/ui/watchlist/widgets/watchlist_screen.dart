import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/watchlist_anime.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/netflix_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/netflix_card.dart';
import '../../search/widgets/source_selection_screen.dart';
import '../view_models/watchlist_viewmodel.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Carrega inicial (o stream do repository também atualiza).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WatchlistViewModel>().loadWatchlist();
    });
  }

  Future<void> _removeFromWatchlist(WatchlistAnime anime) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await context.read<WatchlistViewModel>().removeFromWatchlist(anime.animeId);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.removedFromWatchlist(anime.title)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.of(context);
    final watchlist = context.select<WatchlistViewModel, List<WatchlistAnime>>(
      (vm) => vm.animes,
    );
    final isLoading = context.select<WatchlistViewModel, bool>(
      (vm) => vm.isLoading,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bookmark, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              l10n.watchlist,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (watchlist.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              tooltip: l10n.clearWatchlist,
              onPressed: () => _showClearDialog(),
            ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : watchlist.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () =>
                  context.read<WatchlistViewModel>().loadWatchlist(),
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: GridView.builder(
                    padding: EdgeInsets.all(
                      Responsive.getHorizontalPadding(context),
                    ),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.getGridColumnCount(context),
                      childAspectRatio: 0.7,
                      crossAxisSpacing: Responsive.getCardSpacing(context),
                      mainAxisSpacing: Responsive.getCardSpacing(context),
                    ),
                    itemCount: watchlist.length,
                    itemBuilder: (context, index) {
                      final anime = watchlist[index];
                      return _buildAnimeCard(anime);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 120,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.watchlistEmpty,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.addAnimesToWatchLater,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeCard(WatchlistAnime anime) {
    return FocusableWidget(
      onSelect: () => _navigateToSource(anime),
      borderRadius: NetflixTheme.radiusMd,
      focusPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          NetflixCard(
            imageUrl: anime.coverImage,
            title: anime.title,
            width: double.infinity,
            height: double.infinity,
            showRating: false,
            onTap: () => _navigateToSource(anime),
          ),
          // Botão de remover
          Positioned(
            top: NetflixTheme.sm,
            right: NetflixTheme.sm,
            // FocusableWidget: nó de foco independente para o d-pad alternar
            // entre o card (navegar para o anime) e o botão X (remover da watchlist).
            // O FocusableWidget injeta splash nativo via Material+InkWell.
            child: FocusableWidget(
              onSelect: () => _removeFromWatchlist(anime),
              borderRadius: 24,
              focusPadding: EdgeInsets.zero,
              focusScale: 1.05,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NetflixTheme.background.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: NetflixTheme.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSource(WatchlistAnime anime) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SourceSelectionScreen(
          animeTitle: anime.title,
          imageUrl: anime.coverImage,
          myAnimeListUrl: anime.myAnimeListUrl,
        ),
      ),
    );
  }

  void _showClearDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          l10n.clearWatchlistQuestion,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.clearWatchlistConfirmation,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              await context.read<WatchlistViewModel>().refresh();
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.watchlistCleared),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              l10n.clear,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
