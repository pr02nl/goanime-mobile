import 'package:flutter/foundation.dart';

import '../../../data/services/watchlist_notifier.dart';
import '../../../domain/models/watchlist_anime.dart';
import '../../../domain/repositories/watchlist_repository.dart';

/// ViewModel da watchlist (Fase 3 do plano `docs/DATABASE_REFACTORING.md`).
///
/// Consome `WatchlistRepository` (Drift) em vez de `WatchlistService`
/// (sqlite3 FFI). O `WatchlistNotifier` continua sendo o gatilho global
/// de notificação — outros widgets (`WatchlistButton`) chamam
/// `notifyWatchlistChanged()` após mutar o repository.
class WatchlistViewModel extends ChangeNotifier {
  final WatchlistRepository _repository;
  final WatchlistNotifier _notifier = WatchlistNotifier();

  List<WatchlistAnime> _animes = [];
  List<WatchlistAnime> get animes => _animes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  WatchlistViewModel({required WatchlistRepository repository})
      : _repository = repository;

  Future<void> loadWatchlist() async {
    _isLoading = true;
    notifyListeners();
    try {
      _animes = await _repository.getAll();
    } catch (e) {
      debugPrint('[WatchlistViewModel] load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeFromWatchlist(String animeId) async {
    await _repository.remove(animeId);
    _animes.removeWhere((a) => a.animeId == animeId);
    _notifier.notifyWatchlistChanged();
    notifyListeners();
    return true;
  }

  Future<void> refresh() async {
    await loadWatchlist();
    _notifier.notifyWatchlistChanged();
  }
}

