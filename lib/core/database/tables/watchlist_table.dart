import 'package:drift/drift.dart';

class WatchlistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get animeId => text().unique()();
  TextColumn get title => text()();
  TextColumn get coverImage => text()();
  TextColumn get myAnimeListUrl => text()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}
