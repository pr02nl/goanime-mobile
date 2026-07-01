import 'package:drift/drift.dart';

/// Tabela de filmes PauloFlix Movies (file server).
///
/// `genresJson` armazena a lista como JSON em vez de CSV para evitar
/// bugs com gêneros que contêm vírgula (ex. "Sci-Fi", "Slice of Life").
class PauloFlixMovies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get folderName => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get serverUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get score => real().nullable()();
  TextColumn get genresJson => text().nullable()();
  IntColumn get runtime => integer().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get tmdbId => integer().nullable()();

  /// URL direta do arquivo de vídeo, vinda do campo `file` do
  /// `movie_index.json`.
  TextColumn get videoUrl => text().nullable()();

  /// JSON dos subtitles externos vindo do campo `subtitles` do
  /// `movie_index.json`. Array serializado de
  /// `ExternalSubtitleEntry.toJson()`. `null` se o JSON index não
  /// tiver subtitles.
  TextColumn get subtitlesJson => text().nullable()();

  DateTimeColumn get lastSynced => dateTime()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
}
