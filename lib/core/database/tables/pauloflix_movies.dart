import 'package:drift/drift.dart';

/// Tabela de filmes PauloFlix Movies (file server + TMDB).
///
/// Substitui a tabela `pauloflix_movies` SQLite gerenciada por
/// `PauloFlixMoviesDatabaseService`. `genresJson` armazena a lista como
/// JSON (mesma justificativa da tabela `PauloFlixContent`).
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
  TextColumn get releaseDate => text().nullable()();
  IntColumn get runtime => integer().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  BoolColumn get isCollection =>
      boolean().withDefault(const Constant(false))();
  IntColumn get availableMovieCount =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSynced => dateTime()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
}
