import 'package:drift/drift.dart';

/// Tabela de animes PauloFlix (file server local).
///
/// Substitui a tabela `pauloflix_content` SQLite gerenciada por
/// `PauloFlixDatabaseService`. `genresJson` armazena a lista como JSON
/// (corrige o bug do CSV que quebra com gêneros que contêm vírgula, ex.
/// "Sci-Fi", "Slice of Life").
class PauloFlixContent extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get folderName => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get serverUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get score => real().nullable()();
  TextColumn get genresJson => text().nullable()();
  TextColumn get status => text().nullable()();
  IntColumn get episodeCount => integer().nullable()();
  IntColumn get malId => integer().nullable()();
  IntColumn get anilistId => integer().nullable()();
  DateTimeColumn get lastSynced => dateTime()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
}
