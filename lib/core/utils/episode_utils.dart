/// Utilitários para parsing de nomes de arquivos/pastas de episódios.
///
/// Funções defensivas que lidam com encoding não-padrão de servidores
/// HTTP (nginx não encode nomes de pasta antes de servir HTML, então
/// `Uri.decodeComponent` no nome do `.text` falha com `ArgumentError`
/// quando há `%` literal).
library;

/// Decodifica um componente URI de forma defensiva.
///
/// `Uri.decodeComponent` lança `ArgumentError` quando o input contém
/// `%` que não forma uma sequência hex válida (ex.: nome de pasta
/// "100% completo" em HTML não-encoded). Esta função faz fallback
/// para um decode caractere-a-caractere quando o decode padrão falha.
///
/// Exemplos:
/// - `safeDecodeComponent("Naruto%20Shippuuden")` → `"Naruto Shippuuden"`
/// - `safeDecodeComponent("100% completo")` → `"100% completo"` (sem throw)
/// - `safeDecodeComponent("S01E01")` → `"S01E01"` (sem modificação)
String safeDecodeComponent(String input) {
  try {
    return Uri.decodeComponent(input);
  } on ArgumentError {
    // Fallback: percorre %XX válidos, deixa os outros intactos.
    final pattern = RegExp(r'%([0-9A-Fa-f]{2})');
    final buf = StringBuffer();
    int lastEnd = 0;
    for (final match in pattern.allMatches(input)) {
      buf.write(input.substring(lastEnd, match.start));
      buf.write(Uri.decodeComponent('%${match.group(1)!}'));
      lastEnd = match.end;
    }
    buf.write(input.substring(lastEnd));
    return buf.toString();
  }
}

/// Extrai o número de episódio de uma string como "S01E05" ou "E05".
///
/// Retorna `null` se nenhum padrão for encontrado. Usado por widgets
/// que precisam do número para badge/label.
int? extractEpisodeNumber(String value) {
  // Tenta SxxExx primeiro (mais específico).
  final seasonEpisodeMatch =
      RegExp(r'S\d+E(\d+)', caseSensitive: false).firstMatch(value);
  if (seasonEpisodeMatch != null) {
    return int.tryParse(seasonEpisodeMatch.group(1)!);
  }
  // Fallback: Exx.
  final episodeMatch =
      RegExp(r'\bE(\d+)\b', caseSensitive: false).firstMatch(value);
  if (episodeMatch != null) {
    return int.tryParse(episodeMatch.group(1)!);
  }
  return null;
}
