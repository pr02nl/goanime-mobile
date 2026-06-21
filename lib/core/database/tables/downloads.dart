import 'package:drift/drift.dart';

/// Enums espelhando `DownloadService` para que a coluna possa usar
/// `intEnum<>` e preservar type-safety nos repositórios.
enum DownloadQuality { auto, low, medium, high }

enum DownloadStatus { queued, downloading, paused, completed, failed, cancelled }

/// Tabela de downloads de episódios.
///
/// Substitui a tabela `downloads` SQLite gerenciada por `DownloadService`.
/// Datas em `INTEGER` epoch-ms (consistente com o restante do schema).
class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get downloadId => text().unique()();
  TextColumn get animeId => text()();
  TextColumn get animeName => text()();
  TextColumn get episodeNumber => text()();
  TextColumn get episodeTitle => text()();
  TextColumn get videoUrl => text()();
  TextColumn get thumbnailUrl => text()();
  IntColumn get quality => intEnum<DownloadQuality>()();
  IntColumn get status => intEnum<DownloadStatus>()();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
