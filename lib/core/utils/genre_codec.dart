/// Codifica/decodifica a coluna `genres` (Lista de strings) para
/// representação em SQLite.
///
/// A representação canônica (pós-Fase 1) é **JSON** — uma string como
/// `["Action","Slice of Life","Sci-Fi"]` — para preservar vírgulas dentro
/// de nomes de gênero sem ambiguidade (o formato CSV anterior quebrava
/// com "Slice of Life" e "Action, Adventure").
///
/// A decodificação tem **fallback para CSV** para que bancos legados
/// (pré-Fase 1) continuem legíveis. A migração v1→v3 (Fase 2 do plano)
/// reescreve os bancos com a representação nova.
library;

import 'dart:convert';

/// Codifica uma lista de gêneros para a representação a ser persistida.
/// Lista vazia → `null` (não `[]` nem `''`) para que a coluna no banco
/// fique NULL e o round-trip decodifique como `[]`.
String? encodeGenres(List<String> genres) =>
    genres.isEmpty ? null : jsonEncode(genres);

/// Decodifica o valor bruto da coluna `genres`.
///
/// - `null` ou string vazia → `[]`
/// - String começando com `[` → tenta `jsonDecode`; em sucesso devolve a
///   lista. Em falha, cai no fallback.
/// - Qualquer outra string → fallback CSV (split por vírgula, trim, filtra
///   vazios) para tolerar bancos legados.
List<String> decodeGenresOrFallback(dynamic raw) {
  if (raw == null) return const [];
  final s = raw as String;
  if (s.isEmpty) return const [];
  if (s.startsWith('[')) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
    } catch (_) {
      // cai no fallback CSV
    }
  }
  return s
      .split(',')
      .map((g) => g.trim())
      .where((g) => g.isNotEmpty)
      .toList(growable: false);
}
