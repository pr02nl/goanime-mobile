import '../../domain/models/paulo_flix_movie_progress_record.dart';

/// Contrato de persistência do progresso de filmes PauloFlix Movies.
///
/// Segue o mesmo padrão do `PauloFlixEpisodeProgressRepository` mas
/// simplificado: filmes não têm seasons/episodes, apenas 1 progresso
/// por `folderName`.
abstract class PauloFlixMovieProgressRepository {
  /// Grava o progresso atual do filme e atualiza `lastWatched`.
  ///
  /// Se `positionSeconds / durationSeconds >= 0.9`:
  /// marca `isCompleted = true`.
  ///
  /// Se o record ainda não existe (primeira vez), cria com
  /// os metadados fornecidos.
  Future<void> updateProgress({
    required String folderName,
    required String serverUrl,
    required String displayName,
    String? imageUrl,
    String? videoUrl,
    required int positionSeconds,
    int? durationSeconds,
  });

  /// Limpa o progresso do filme (zera posição + isCompleted).
  /// Usado quando o usuário reassiste ou pula um filme que
  /// mal começou (heurística < 10%).
  Future<void> resetProgress(String folderName);

  /// Retorna o progresso salvo de um filme, ou `null` se nunca
  /// foi aberto.
  Future<PauloFlixMovieProgressRecord?> getProgress(String folderName);

  /// Lista filmes com progresso em andamento, ordenados por
  /// `lastWatched DESC`. Limite 12 por padrão.
  ///
  /// Filtra: `positionSeconds > 0 && !isCompleted`.
  Future<List<PauloFlixMovieProgressRecord>> getInProgressMovies({
    int limit = 12,
  });

  /// Stream reativo da lista de filmes em andamento.
  /// Aciona ao adicionar/resetar/assistir filmes.
  Stream<List<PauloFlixMovieProgressRecord>> watchInProgressMovies({
    int limit = 12,
  });

  /// Retorna TODO progresso salvo (em andamento + completo), sem limite.
  /// Usado pela home de filmes para exibir overlays nos cards.
  Future<List<PauloFlixMovieProgressRecord>> getAllProgress();
}
