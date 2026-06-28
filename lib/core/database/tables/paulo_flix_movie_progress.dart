import 'package:drift/drift.dart';

/// Tabela de progresso de filmes PauloFlix Movies.
///
/// ## Por que tabela separada (em vez de colunas em `pauloflix_movies`)
///
/// Mesma justificativa das tabelas `paulo_flix_seasons`/`paulo_flix_episodes`:
/// - FK não se aplica (filmes não têm FK para seasons/episodes).
/// - Stream reativo para a seção "Continue assistindo" (watch stream).
/// - `positionSeconds`/`isCompleted`/`lastWatched` não precisam poluir o
///   model `PauloFlixMovie` que é o model de catálogo/metadados.
///
/// ## `folderName` é a chave única
///
/// Corresponde ao `PauloFlixMovie.folderName` (que é UNIQUE em
/// `paulo_flix_movies`). Permite join simples para buscar metadados
/// do filme (displayName, imageUrl, serverUrl) na seção "Continue
/// assistindo".
///
/// ## `positionSeconds` é a fonte de verdade do "continuar de onde parou"
///
/// - Salvo a cada 5s pelo player durante playback.
/// - Flush no dispose do player (garante último save).
///
/// ## `isCompleted` é flag derivada
///
/// Marcada `true` quando `positionSeconds / durationSeconds >= 0.9`.
///
/// ## `lastWatched` é atualizado a cada save
///
/// Usado para ordenar a home (mais recente primeiro).
class PauloFlixMovieProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get folderName => text().unique()();
  TextColumn get serverUrl => text()();

  /// Desnormalizado para exibir no card "Continue assistindo"
  /// sem precisar de JOIN com `paulo_flix_movies`.
  TextColumn get displayName => text()();

  /// Desnormalizado: poster/imageUrl do filme.
  TextColumn get imageUrl => text().nullable()();

  /// URL do arquivo de vídeo específico que estava sendo assistido.
  /// Populada na primeira abertura do player.
  TextColumn get videoUrl => text().nullable()();

  /// Duração total do vídeo em segundos.
  /// Nullable porque na primeira abertura ainda não foi descoberta.
  IntColumn get durationSeconds => integer().nullable()();

  /// Posição atual do playback em segundos. Default 0 = nunca assistido.
  IntColumn get positionSeconds =>
      integer().withDefault(const Constant(0))();

  /// Flag derivada: true quando positionSeconds/durationSeconds >= 0.9.
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();

  /// Timestamp do último save de progresso. Null = nunca assistido.
  DateTimeColumn get lastWatched => dateTime().nullable()();

  DateTimeColumn get lastSynced => dateTime()();
}
