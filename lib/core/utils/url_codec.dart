/// Utilitários de encoding/decoding de URLs.
///
/// Centraliza o helper defensivo [safeDecodeComponent] usado pelos
/// services PauloFlix (PauloFlixService, PauloFlixMoviesService,
/// PauloFlixEpisodeSyncService) para evitar `ArgumentError` em
/// pastas/arquivos cujo nome contém `%` literal seguido de caracteres
/// não-hexadecimais (e.g. `100% completo`).
///
/// Foi extraído para cá na Fase 8 do plano NFO Enrichment V2
/// (`.hermes/plans/2026-06-23_225500-pauloflix-nfo-enrichment-v2.md`)
/// para eliminar a duplicação entre 3 services e servir de ponto único
/// para testes unitários.
///
/// **Decoding de NFOs:** [decodeResponseBody] resolve o problema de
/// NFOs do Kodi salvos em Latin-1/Windows-1252 (acentos do PT-BR
/// quebrados). O `package:http` decodifica o body como Latin-1 por
/// default se o Content-Type não especifica charset, o que quebra
/// NFOs UTF-8 sem header correto. Esta função detecta o encoding
/// real (BOM, declaration XML, ou Content-Type) e re-decodifica.
library;

import 'dart:convert';

/// Decodifica um componente URI de forma defensiva.
///
/// **Por que `Uri.decodeComponent` falha com Latin-1/ISO-8859-1:**
/// o método da stdlib Dart **só suporta UTF-8**. Bytes Latin-1 como
/// `%E7` (= ç em Latin-1) são continuação bytes inválidos em UTF-8, e
/// o decoder joga `FormatException: Missing extension byte`.
///
/// Esta função faz 2 tentativas:
/// 1. UTF-8 (default — funciona para `Naruto%20Shippuuden`, `%C3%A9`,
///    etc).
/// 2. Se UTF-8 falha, tenta Latin-1 (cobre `%E7`, `%E3`, `%E1` — bytes
///    de 0x80-0xFF que são chars Latin-1 válidos).
///
/// **Por que essa ordem:** UTF-8 é o padrão HTTP/1.1 + Kodi NFO; tentar
/// UTF-8 primeiro evita ambiguidade (ex: `%C3%A9` pode ser "é" UTF-8
/// ou "Ã©" Latin-1 errado). Latin-1 é fallback.
///
/// **Edge cases:**
/// - `safeDecodeComponent("100% completo")` → "100% completo" (sem throw)
/// - `safeDecodeComponent("S01E01")` → "S01E01" (sem modificação)
/// - `safeDecodeComponent("")` → "" (early return)
/// - `safeDecodeComponent("S%C3%A9rie")` → "Série" (UTF-8)
/// - `safeDecodeComponent("A%E7%E3o%20%282010%29")` → "Ação (2010)" (Latin-1)
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
      // Se Latin-1 também falhar, faz o fallback caractere-a-caractere
      // (preserva %XY inválido como literal).
    }
  }

  // 2. Fallback final: percorre %XX válidos (qualquer charset), deixa
  //    os outros intactos.
  return _fallbackCharByChar(input);
}

/// Tenta decodificar [input] tratando cada `%XX` como byte Latin-1
/// (ISO-8859-1). Útil quando o `Uri.decodeComponent` falha porque
/// os bytes são Latin-1, não UTF-8.
///
/// Retorna a string decoded com acentos Latin-1 (ç=0xE7, ã=0xE3, etc).
String _decodeAsLatin1(String input) {
  // Para cada bloco de bytes (%XX hex), decodifica o byte Latin-1
  // e concatena. Blocos sem %XX são passados direto.
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

/// Fallback quando UTF-8 e Latin-1 falham: percorre %XX válidos
/// (hex), deixa os outros intactos. É o que o helper antigo fazia
/// antes de adicionarmos Latin-1.
String _fallbackCharByChar(String input) {
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

/// Detecta o charset declarado num HTML listing (nginx/apache
/// autoindex) e nos headers HTTP. Ordem de preferência:
/// 1. `<meta charset="...">` no `<head>` (mais autoritativo).
/// 2. `<meta http-equiv="Content-Type" content="...; charset=...">`.
/// 3. Header HTTP `Content-Type: text/html; charset=...`.
///
/// Retorna `null` se nenhum charset for detectado — nesse caso, o
/// `html_parser` assume UTF-8 (default HTTP/1.1).
String? detectHtmlCharset(
  String html, {
  Map<String, String>? responseHeaders,
}) {
  if (html.isNotEmpty) {
    // 1) <meta charset="..."> ou <meta charset='...'>
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

/// Detecta o charset declarado num documento XML (Kodi NFO, RSS feed,
/// etc). Ordem de preferência:
/// 1. `<?xml version="1.0" encoding="..."?>` declaration (autoritativo).
/// 2. Header HTTP `Content-Type: text/xml; charset=...` (pode mentir).
///
/// **Por que não confiar no `xml` package sozinho:** o
/// `XmlDocument.parse` tenta detectar o encoding via declaration XML
/// automaticamente, mas isso SÓ funciona se os bytes forem UTF-8/UTF-16
/// (que têm BOM opcional). Se o NFO for Latin-1/Windows-1252 sem
/// declaration, o `xml` assume UTF-8 e produz caracteres errados.
///
/// Esta função extrai o encoding declarado para que o caller possa
/// re-decodificar os bytes brutos (`response.bodyBytes`) com o codec
/// correto antes de passar para o parser.
///
/// Retorna `null` se nenhum encoding for detectado. O caller deve
/// então tentar UTF-8 (default HTTP/1.1 + mais comum para NFOs do Kodi).
String? detectXmlCharset(
  String xml, {
  Map<String, String>? responseHeaders,
}) {
  if (xml.isNotEmpty) {
    // 1) <?xml version="1.0" encoding="..."?>
    // Aceita com/sem aspas duplas, com/sem 'standalone', em qualquer
    // ordem dos atributos (version/encoding/standalone).
    final declMatch = RegExp(
      r'<\?xml[^>]+encoding="?([\w-]+)"?',
      caseSensitive: false,
    ).firstMatch(xml);
    if (declMatch != null) return declMatch.group(1);
  }

  // 2) Content-Type header (fallback menos confiável).
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

/// Decodifica `bodyBytes` (raw bytes de um HTTP response) usando o
/// charset detectado. Resolve o problema clássico de NFOs do Kodi
/// salvos em Latin-1/Windows-1252 (acentos do PT-BR/PT-PT quebrados).
///
/// **Por que isso é necessário:** o `package:http` (que o projeto
/// PauloFlix usa) tem um comportamento confuso: `response.body` é
/// uma String decodificada, mas SEM o charset declarado no
/// Content-Type — o default é Latin-1 (ISO-8859-1) por motivos
/// históricos do HTTP/1.0. Isso significa que NFOs salvos em UTF-8
/// (que é o padrão moderno) SEM header `Content-Type: ...; charset=utf-8`
/// ficam com acentos errados antes mesmo de chegar no parser.
///
/// **Estratégia:**
/// 1. Se `bodyBytes` começa com BOM UTF-8 (`EF BB BF`) ou UTF-16,
///    decodifica direto (BOM é autoritativo).
/// 2. Se `bodyBytes` começa com `<?xml ... encoding="...">`, lê o
///    encoding e re-decodifica os bytes com o codec certo.
/// 3. Se Content-Type header tem `charset=...`, usa esse.
/// 4. Fallback UTF-8 (default HTTP/1.1 + padrão Kodi NFO).
///
/// **Reencoda** o resultado para UTF-8 normalizado, garantindo que
/// o `KodiNfoParser` (Fase 1) sempre receba uma String UTF-8
/// (que é o que o `xml` package assume por default).
String decodeResponseBody(
  List<int> bodyBytes, {
  Map<String, String>? responseHeaders,
  String? xmlPreview,
}) {
  if (bodyBytes.isEmpty) return '';

  // 1. BOM detection (autoritativo, ignora Content-Type).
  if (bodyBytes.length >= 3 &&
      bodyBytes[0] == 0xEF &&
      bodyBytes[1] == 0xBB &&
      bodyBytes[2] == 0xBF) {
    // UTF-8 BOM. Strip o BOM e decodifica.
    return utf8.decode(bodyBytes.sublist(3));
  }
  if (bodyBytes.length >= 2) {
    // Suporte a UTF-16 com BOM foi removido por simplificação: NFOs do
    // Kodi SEMPRE são UTF-8 ou Latin-1. Se algum dia aparecer um NFO
    // em UTF-16, o `xml` package vai detectar pelo BOM e decodificar.
    // Caso contrário, caímos no Latin-1 fallback (passo 2 abaixo).
  }

  // 2. Tenta detectar via XML declaration (precisa do body como string
  //    provisória em Latin-1 para que bytes UTF-8 não quebrem o decode).
  //    Se xmlPreview for fornecido, usa direto; senão, decodifica como
  //    Latin-1 (sempre seguro para qualquer byte 0x00-0xFF).
  final preview = xmlPreview ?? latin1.decode(bodyBytes);
  final xmlCharset = detectXmlCharset(
    preview.length > 256 ? preview.substring(0, 256) : preview,
    responseHeaders: responseHeaders,
  );

  // 3. Decide qual codec usar.
  final codec = _codecForCharsetName(xmlCharset);

  // 4. Decodifica com o codec escolhido. Se for UTF-8, decode direto
  //    (caso comum). Senão, decode com codec + reencoda para UTF-8
  //    (garante que downstream sempre recebe UTF-8).
  final decoded = codec.decode(bodyBytes);
  if (codec == utf8) return decoded;
  // Garante UTF-8 normalizado.
  return utf8.decode(latin1.encode(decoded));
}

/// Mapeia nome de charset (case-insensitive) para o `Encoding` do
/// `dart:convert`. Retorna UTF-8 como fallback default.
///
/// Suporta: utf-8, iso-8859-1, windows-1252, us-ascii, latin1.
Encoding _codecForCharsetName(String? name) {
  if (name == null) return utf8;
  final lower = name.toLowerCase().trim();
  switch (lower) {
    case 'utf-8':
    case 'utf8':
      return utf8;
    case 'iso-8859-1':
    case 'latin1':
    case 'latin-1':
      return latin1;
    case 'windows-1252':
    case 'cp1252':
      return Encoding.getByName('windows-1252') ?? latin1;
    case 'us-ascii':
    case 'ascii':
      return ascii;
    default:
      // Tenta lookup genérico (cobre charsets menos comuns).
      return Encoding.getByName(lower) ?? utf8;
  }
}
