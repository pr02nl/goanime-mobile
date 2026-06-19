import 'package:drift/drift.dart';

class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get downloadId => text().unique()();
  TextColumn get animeId => text()();
  TextColumn get animeName => text()();
  TextColumn get episodeNumber => text()();
  TextColumn get episodeTitle => text()();
  TextColumn get videoUrl => text()();
  TextColumn get thumbnailUrl => text()();
  IntColumn get quality => integer().withDefault(const Constant(0))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
