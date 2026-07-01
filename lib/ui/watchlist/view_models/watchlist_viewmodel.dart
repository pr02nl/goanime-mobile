import 'package:flutter/foundation.dart';

import '../../../core/logger/app_logger.dart';

import '../../../domain/models/watchlist_anime.dart';
import '../../../domain/repositories/watchlist_repository.dart';

/// ViewModel da watchlist (Fase 3/4 do plano `docs/DATABASE_REFACTORING.md`).
///
/// Consome `WatchlistRepository` (Drift) como fonte de verdade. Expõe
/// o `Stream<List<WatchlistAnime>> watch()` do repository para que
/// widgets (Screen, Button) possam reagir a mudanças automaticamente
/// — substitui o antigo `WatchlistNotifier` (removido na Fase 4).
class WatchlistViewModel extends ChangeNotifier {
  final WatchlistRepository _repository;

  List<WatchlistAnime> _animes = [];
  List<WatchlistAnime> get animes => _animes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  WatchlistViewModel({required WatchlistRepository repository})
      : _repository = repository;

  /// Stream reativo: emite nova lista sempre que a watchlist muda.
  /// Substitui `WatchlistNotifier`.
  Stream<List<WatchlistAnime>> get watchStream => _repository.watch();

  Future<void> loadWatchlist() async {
    _isLoading = true;
    notifyListeners();
    try {
      _animes = await _repository.getAll();
    } catch (e) {
      const AppLogger('WatchlistViewModel').error('load failed', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeFromWatchlist(String animeId) async {
    await _repository.remove(animeId);
    _animes.removeWhere((a) => a.animeId == animeId);
    notifyListeners();
    return true;
  }

  Future<void> refresh() async {
    await loadWatchlist();
  }
}

