import 'package:drift/drift.dart';

import 'app_database.dart';

/// Utilitários estáticos para operações comuns de repositórios Drift.
///
/// Substitui a tentativa anterior de mixin com membros privados, que
/// não funciona entre libraries em Dart (membros `_` são library-scoped).
///
/// Uso:
/// ```dart
/// final stats = await DriftUtils.getStats(db, 'paulo_flix_content');
/// await DriftUtils.markAsUnavailable(db, 'paulo_flix_content', folderName);
/// final items = await DriftUtils.searchByName(
///   db, 'paulo_flix_content', query, fromRawMap,
/// );
/// ```
class DriftUtils {
  DriftUtils._();

  /// Escapa caracteres especiais do SQL LIKE (`%`, `_`, `\`).
  static String escapeLike(String q) => q
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// Marca um item como indisponível (servidor o removeu).
  static Future<void> markAsUnavailable(
    AppDatabase db,
    String tableName,
    String folderName,
  ) async {
    await db.customUpdate(
      'UPDATE $tableName SET is_available = 0 WHERE folder_name = ?1',
      variables: [Variable.withString(folderName)],
    );
  }

  /// Contagens para diagnóstico (total, available, withMetadata).
  static Future<Map<String, int>> getStats(
    AppDatabase db,
    String tableName,
  ) async {
    final totalRow = await db.customSelect(
      'SELECT COUNT(*) as cnt FROM $tableName',
    ).getSingle();
    final availRow = await db.customSelect(
      'SELECT COUNT(*) as cnt FROM $tableName WHERE is_available = 1',
    ).getSingle();
    final metadataRow = await db.customSelect(
      'SELECT COUNT(*) as cnt FROM $tableName '
      'WHERE is_available = 1 AND image_url IS NOT NULL',
    ).getSingle();
    return {
      'total': totalRow.data['cnt'] as int,
      'available': availRow.data['cnt'] as int,
      'withMetadata': metadataRow.data['cnt'] as int,
    };
  }

  /// Busca por nome via `LIKE` com ESCAPE.
  /// [fromRawMap] converte o `Map<String, dynamic>` cru (chaves snake_case)
  /// para o modelo de domínio. Ex:
  /// ```dart
  /// DriftUtils.searchByName(db, 'minha_tabela', query,
  ///   (data) => _toDomain(db.minhaTabela.map(data)));
  /// ```
  static Future<List<T>> searchByName<T>(
    AppDatabase db,
    String tableName,
    String query,
    T Function(Map<String, dynamic>) fromRawMap,
  ) async {
    final escaped = escapeLike(query);
    final pattern = '%$escaped%';
    final rows = await db.customSelect(
      'SELECT * FROM $tableName '
      "WHERE display_name LIKE ?1 ESCAPE '\\' "
      'AND is_available = 1 '
      'ORDER BY display_name',
      variables: [Variable.withString(pattern)],
    ).get();
    return rows.map((r) => fromRawMap(r.data)).toList();
  }
}
