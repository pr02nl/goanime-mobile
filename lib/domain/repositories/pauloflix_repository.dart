import '../../domain/models/pauloflix_content.dart';

/// Contrato de persistência do conteúdo PauloFlix (animes do file server).
///
/// **Fase 3** — encapsula Drift. A impl fica em `data/repositories/`.
abstract class PauloFlixRepository {
  Future<List<PauloFlixContent>> getAll();

  /// Busca por `displayName` (case-insensitive, com `LIKE` + `ESCAPE`
  /// para tratar `%` e `_` como literais).
  Future<List<PauloFlixContent>> searchByName(String query);

  Future<PauloFlixContent?> getByFolderName(String folderName);

  /// Salva ou substitui (UNIQUE em folderName).
  Future<void> saveContent(PauloFlixContent content);

  /// Salva múltiplos em batch (transação única).
  Future<void> saveBatch(List<PauloFlixContent> contents);

  /// Marca o conteúdo como indisponível (servidor removeu).
  Future<void> markAsUnavailable(String folderName);

  /// Contagens para diagnóstico.
  Future<Map<String, int>> getStats();

  /// Stream reativo.
  Stream<List<PauloFlixContent>> watch();
}
