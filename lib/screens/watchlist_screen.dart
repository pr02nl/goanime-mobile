import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/watchlist_anime.dart';
import '../services/watchlist_notifier.dart';
import '../services/watchlist_service.dart';
import '../theme/app_colors.dart';
import '../theme/netflix_theme.dart';
import '../widgets/focusable_widget.dart';
import '../widgets/netflix_card.dart';
import 'source_selection_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with AutomaticKeepAliveClientMixin {
  final WatchlistService _watchlistService = WatchlistService();
  final WatchlistNotifier _watchlistNotifier = WatchlistNotifier();
  List<WatchlistAnime> _watchlist = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();

    // Escuta mudanças na watchlist
    _watchlistNotifier.addListener(_onWatchlistChanged);
  }

  @override
  void dispose() {
    _watchlistNotifier.removeListener(_onWatchlistChanged);
    super.dispose();
  }

  void _onWatchlistChanged() {
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() => _isLoading = true);
    final watchlist = await _watchlistService.getWatchlist();
    if (mounted) {
      setState(() {
        _watchlist = watchlist;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromWatchlist(WatchlistAnime anime) async {
    final success = await _watchlistService.removeFromWatchlist(anime.animeId);
    if (success && mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.removedFromWatchlist(anime.title)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadWatchlist();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.bookmark, color: AppColors.primary, size: 28),
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
          if (_watchlist.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              tooltip: l10n.clearWatchlist,
              onPressed: () => _showClearDialog(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _watchlist.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadWatchlist,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _watchlist.length,
                itemBuilder: (context, index) {
                  final anime = _watchlist[index];
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
            child: GestureDetector(
              onTap: () => _removeFromWatchlist(anime),
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
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              await _watchlistService.clearWatchlist();
              _loadWatchlist();
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
            child: Text(l10n.clear, style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
