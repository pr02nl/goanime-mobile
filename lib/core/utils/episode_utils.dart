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
/// - `safeDecodeComponent("S%C3%A9rie")` → `"Série"` (UTF-8)
/// - `safeDecodeComponent("A%E7%E3o%20%282010%29")` → `"Ação (2010)"` (Latin-1)
String safeDecodeComponent(String input) {
  if (input.isEmpty) return input;

  // 1. Tenta UTF-8 (default).
  try {
    return Uri.decodeComponent(input);
  } on ArgumentError {
    // ArgumentError = %XY não-hex (ex: "%XY"). Cai pro fallback abaixo.
  } on FormatException catch (_) {
    // FormatException = bytes Latin-1 (ex: "%E7"). Tenta Latin-1.
    try {
      return _decodeAsLatin1(input);
    } catch (_) {
      // Se Latin-1 também falhar, faz o fallback caractere-a-caractere.
    }
  }

  // 2. Fallback final: percorre %XX válidos, deixa os outros intactos.
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

/// Tenta decodificar [input] tratando cada `%XX` como byte Latin-1.
/// Útil quando `Uri.decodeComponent` falha porque os bytes são
/// Latin-1, não UTF-8.
String _decodeAsLatin1(String input) {
  final buf = StringBuffer();
  int i = 0;
  while (i < input.length) {
    final ch = input[i];
    if (ch == '%' && i + 2 < input.length) {
      final hex = input.substring(i + 1, i + 3);
      final byte = int.tryParse(hex, radix: 16);
      if (byte != null) {
        buf.writeCharCode(byte);
        i += 3;
        continue;
      }
    }
    buf.write(ch);
    i++;
  }
  return buf.toString();
}

/// Detecta o charset declarado num HTML listing. Ordem de preferência:
/// 1. `<meta charset="...">` no `<head>`.
/// 2. `<meta http-equiv="Content-Type" content="...; charset=...">`.
/// 3. Header HTTP `Content-Type: text/html; charset=...`.
///
/// Retorna `null` se nenhum charset for detectado.
String? detectHtmlCharset(
  String html, {
  Map<String, String>? responseHeaders,
}) {
  if (html.isNotEmpty) {
    // 1) <meta charset="...">
    final metaMatch = RegExp(
      r'<meta[^>]+charset="?([\w-]+)"?',
      caseSensitive: false,
    ).firstMatch(html);
    if (metaMatch != null) return metaMatch.group(1);

    // 2) <meta http-equiv="Content-Type" content="...; charset=...">
    final httpEquivMatch = RegExp(
      r'<meta[^>]+http-equiv="?content-type"?[^>]+content="?[^">]*charset=([\w-]+)"?',
      caseSensitive: false,
    ).firstMatch(html);
    if (httpEquivMatch != null) return httpEquivMatch.group(1);
  }

  // 3) Content-Type header.
  if (responseHeaders != null) {
    final contentType =
        responseHeaders['content-type'] ?? responseHeaders['Content-Type'];
    if (contentType != null) {
      final ctMatch = RegExp(
        'charset=([\\w-]+)',
        caseSensitive: false,
      ).firstMatch(contentType);
      if (ctMatch != null) return ctMatch.group(1);
    }
  }

  return null;
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
