// `DownloadItem` é o modelo de domínio (definido em
// `data/services/download_service.dart`). Os enums `DownloadQuality`
// e `DownloadStatus` são os mesmos (não há conflito de nome em Dart
// quando importados via prefix).
import '../../data/services/download_service.dart' as svc;
import '../../core/database/tables/downloads.dart' as db;

/// Modelo de domínio re-exportado para evitar import circular.
typedef DownloadItem = svc.DownloadItem;

/// Contrato de persistência dos downloads.
///
/// **Fase 3** — encapsula Drift. A impl `DownloadsRepositoryImpl` vive
/// em `data/repositories/`. O `DownloadService` (que tem a fila HTTP
/// e o `ChangeNotifier`) passa a chamar este repository por trás,
/// sem mudar sua API pública.
abstract class DownloadsRepository {
  /// Salva (ou substitui, se `id` existir) o item.
  Future<void> save(DownloadItem item);

  /// Lista todos os downloads.
  Future<List<DownloadItem>> getAll();

  /// Retorna o item com o `id` dado, ou `null` se não existir.
  Future<DownloadItem?> getById(String id);

  /// Lista os downloads de um anime específico.
  Future<List<DownloadItem>> getAnimeDownloads(String animeId);

  /// Remove por id.
  Future<void> delete(String id);

  /// Total de downloads armazenados.
  Future<int> count();

  /// Atualiza apenas o status.
  Future<void> updateStatus(String id, db.DownloadStatus status);

  /// Atualiza progresso e bytes downloaded.
  Future<void> updateProgress(
    String id, {
    required double progress,
    required int bytes,
  });

  /// Remove todos com `status = completed`.
  Future<void> clearCompleted();

  /// Remove todos com `status = failed` ou `cancelled`.
  Future<void> clearFailed();

  /// Reseta `downloading` para `queued` (chamado no boot — Fase 1 fix).
  /// Retorna os ids que foram alterados.
  Future<List<String>> resetStaleToQueued();

  /// Stream reativo: emite lista nova sempre que algo muda.
  Stream<List<DownloadItem>> watch();
}
