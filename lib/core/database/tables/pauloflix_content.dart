import 'package:drift/drift.dart';

/// Tabela de animes PauloFlix (file server local).
///
/// `genresJson` armazena a lista como JSON em vez de CSV para evitar
/// bugs com gêneros que contêm vírgula (ex. "Sci-Fi", "Slice of Life").
///
/// **Campos extended (originalTitle, year, tmdbId):** populados a partir
/// do JSON index (`tv_index.json`) durante o sync via
/// `PauloFlixService.syncContent`. Persistidos no SQLite para consulta
/// offline.
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
  TextColumn get originalTitle => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  DateTimeColumn get lastSynced => dateTime()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
}
