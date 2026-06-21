import '../../domain/models/watchlist_anime.dart';

/// Contrato de persistência da watchlist.
///
/// **Fase 3 do plano `docs/DATABASE_REFACTORING.md`** — encapsula Drift
/// e devolve modelos de domínio (WatchlistAnime). A impl concreta
/// (WatchlistRepositoryImpl) fica em `data/repositories/`.
///
/// O `Stream<List<WatchlistAnime>> watch()` permite que a UI reaja
/// automaticamente a mudanças no banco (Drift `watch()` reativo).
abstract class WatchlistRepository {
  /// Lista todos os animes da watchlist, ordenado por `addedAt` DESC
  /// (mais recente primeiro).
  Future<List<WatchlistAnime>> getAll();

  /// Retorna o anime com o `animeId` dado, ou `null` se não existir.
  Future<WatchlistAnime?> getByAnimeId(String animeId);

  /// Adiciona (ou substitui, se `animeId` já existir) o anime.
  Future<void> add(WatchlistAnime anime);

  /// Remove o anime com o `animeId` dado. No-op se não existir.
  Future<void> remove(String animeId);

  /// Verifica se o `animeId` está na watchlist.
  Future<bool> isInWatchlist(String animeId);

  /// Conta quantos animes estão na watchlist.
  Future<int> count();

  /// Remove todos os animes.
  Future<void> clear();

  /// Stream reativo: emite nova lista sempre que a watchlist muda.
  /// Ordenado por `addedAt` DESC.
  Stream<List<WatchlistAnime>> watch();
}
