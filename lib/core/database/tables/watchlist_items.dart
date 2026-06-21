import 'package:drift/drift.dart';

/// Tabela de watchlist (animes salvos para assistir depois).
///
/// Substitui o `watchlist` SQLite gerenciado por `WatchlistService` (sqlite3
/// FFI). `addedAt` é armazenado como `INTEGER` epoch-ms (consistente com
/// `downloads.createdAt` e `pauloflix_content.lastSynced`).
class WatchlistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get animeId => text().unique()();
  TextColumn get title => text()();
  TextColumn get coverImage => text()();
  TextColumn get myAnimeListUrl => text()();
  DateTimeColumn get addedAt => dateTime()();
}
