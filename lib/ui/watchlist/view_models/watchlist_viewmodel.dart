import 'package:flutter/foundation.dart';

import '../../../models/watchlist_anime.dart';
import '../../../services/watchlist_notifier.dart';
import '../../../services/watchlist_service.dart';

class WatchlistViewModel extends ChangeNotifier {
  final WatchlistService _service = WatchlistService();
  final WatchlistNotifier _notifier = WatchlistNotifier();

  List<WatchlistAnime> _animes = [];
  List<WatchlistAnime> get animes => _animes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadWatchlist() async {
    _isLoading = true;
    notifyListeners();
    try {
      _animes = await _service.getWatchlist();
    } catch (e) {
      debugPrint('[WatchlistViewModel] load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeFromWatchlist(String animeId) async {
    final result = await _service.removeFromWatchlist(animeId);
    if (result) {
      _animes.removeWhere((a) => a.animeId == animeId);
      _notifier.notifyWatchlistChanged();
      notifyListeners();
    }
    return result;
  }

  Future<void> refresh() async {
    await loadWatchlist();
    _notifier.notifyWatchlistChanged();
  }
}
