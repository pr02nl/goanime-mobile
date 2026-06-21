import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/watchlist_notifier.dart';
import '../../../domain/models/watchlist_anime.dart';
import '../../../domain/repositories/watchlist_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../themes/app_colors.dart';
import 'focusable_widget.dart';

class WatchlistButton extends StatefulWidget {
  final String animeId;
  final String title;
  final String coverImage;
  final String myAnimeListUrl;

  const WatchlistButton({
    super.key,
    required this.animeId,
    required this.title,
    required this.coverImage,
    required this.myAnimeListUrl,
  });

  @override
  State<WatchlistButton> createState() => _WatchlistButtonState();
}

class _WatchlistButtonState extends State<WatchlistButton> {
  WatchlistRepository get _repository =>
      context.read<WatchlistRepository>();

  bool _isInWatchlist = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkWatchlist();
  }

  Future<void> _checkWatchlist() async {
    final isInWatchlist = await _repository.isInWatchlist(widget.animeId);
    if (mounted) {
      setState(() {
        _isInWatchlist = isInWatchlist;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleWatchlist() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    if (_isInWatchlist) {
      await _repository.remove(widget.animeId);
      if (mounted) {
        setState(() => _isInWatchlist = false);
        WatchlistNotifier().notifyWatchlistChanged();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.removedFromWatchlistShort),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      final anime = WatchlistAnime(
        animeId: widget.animeId,
        title: widget.title,
        coverImage: widget.coverImage,
        myAnimeListUrl: widget.myAnimeListUrl,
        addedAt: DateTime.now(),
      );
      await _repository.add(anime);
      if (mounted) {
        setState(() => _isInWatchlist = true);
        WatchlistNotifier().notifyWatchlistChanged();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.addedToWatchlist),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    // FocusableWidget garante:
    //  - D-pad Enter/Select aciona _toggleWatchlist em TV
    //  - Anel de foco visível no círculo do botão
    //  - Em mobile/tablet cai para GestureDetector puro
    return FocusableWidget(
      onSelect: _toggleWatchlist,
      borderRadius: 24,
      focusPadding: EdgeInsets.zero,
      focusScale: 1.05,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(
            color: _isInWatchlist
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(
          _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
          color: _isInWatchlist ? AppColors.primary : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
