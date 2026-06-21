import '../../domain/models/pauloflix_movie.dart';

/// Contrato de persistência do conteúdo PauloFlix Movies.
///
/// **Fase 3** — encapsula Drift. Espelha `PauloFlixRepository` mas com
/// domínio de filme (com `tmdbId`, `year`, `isCollection`,
/// `availableMovieCount`).
abstract class PauloFlixMoviesRepository {
  Future<List<PauloFlixMovie>> getAll();

  /// Busca por `displayName` (LIKE com ESCAPE).
  Future<List<PauloFlixMovie>> searchByName(String query);

  Future<PauloFlixMovie?> getByFolderName(String folderName);
  Future<PauloFlixMovie?> getByTmdbId(int tmdbId);

  Future<void> saveContent(PauloFlixMovie content);
  Future<void> saveBatch(List<PauloFlixMovie> contents);

  Future<void> markAsUnavailable(String folderName);

  /// Contagens: total, available, withMetadata, collections.
  Future<Map<String, int>> getStats();

  Stream<List<PauloFlixMovie>> watch();
}
