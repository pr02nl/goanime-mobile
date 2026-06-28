/// Record de banco do progresso de um filme PauloFlix Movies.
///
/// Diferente do `PauloFlixEpisodeRecord` (que depende de seasonId),
/// este modelo identifica o filme unicamente por `folderName`.
///
/// Campos desnormalizados (`displayName`, `imageUrl`, `serverUrl`)
/// permitem que a seção "Continue assistindo" na home de filmes
/// exiba os cards sem precisar de JOIN com `paulo_flix_movies`.
class PauloFlixMovieProgressRecord {
  final int? id;
  final String folderName;
  final String serverUrl;
  final String displayName;
  final String? imageUrl;
  final String? videoUrl;
  final int? durationSeconds;
  final int positionSeconds;
  final bool isCompleted;
  final DateTime? lastWatched;
  final DateTime lastSynced;

  PauloFlixMovieProgressRecord({
    this.id,
    required this.folderName,
    required this.serverUrl,
    required this.displayName,
    this.imageUrl,
    this.videoUrl,
    this.durationSeconds,
    this.positionSeconds = 0,
    this.isCompleted = false,
    this.lastWatched,
    required this.lastSynced,
  });

  /// Progresso como fração 0.0 (nenhum) a 1.0 (completo).
  double get progressRatio {
    final dur = durationSeconds;
    if (dur == null || dur <= 0) return 0.0;
    final ratio = positionSeconds / dur;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixMovieProgressRecord &&
          folderName == other.folderName;

  @override
  int get hashCode => folderName.hashCode;

  @override
  String toString() =>
      'PauloFlixMovieProgressRecord('
      'folderName: $folderName, '
      'positionSeconds: $positionSeconds, '
      'isCompleted: $isCompleted)';
}
