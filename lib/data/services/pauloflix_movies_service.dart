import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/utils/url_codec.dart' as url_codec;
import '../../domain/models/pauloflix_movie.dart';
import '../../domain/models/pauloflix_movie_item.dart';
import '../../domain/repositories/pauloflix_movies_repository.dart';
import 'kodi/pauloflix_nfo_enricher.dart';

/// Lê diretórios HTML do PauloFlix Movies e enriquece com metadados do TMDB.
///
/// ## Como nomes e anos são extraídos
///
/// Para **filmes individuais**, o nome do filme e o ano são extraídos do
/// **NOME DA PASTA**, não do nome do arquivo.
///
/// Exemplos de pastas (todas URL-encoded):
/// - `A%20Origem%20(2010)` → título: "A Origem", ano: 2010
/// - `Amadeus` → título: "Amadeus", ano: null
/// - `Constantine%202005%20(1080p)%20WWW.BLUDV.COM` → título: "Constantine 2005", ano: 2005
///
/// Regex utilizada:
/// - **Ano**: `(YYYY)` entre parênteses `( ... )` no nome da pasta.
///   Se não houver `(YYYY)`, retorna null e a busca no TMDB fica sem filtro de ano.
class PauloFlixMoviesService {
  static const String baseUrl = ApiConstants.moviePauloFlix;
  static const String indexUrl = ApiConstants.movieIndexUrl;

  /// Host base sem path — usado para resolver paths relativos do JSON.
  static const String _baseHost = 'https://media.oliveira.braga.nom.br';

  /// HTTP client injetável (default: `http.Client()`, injetado por
  /// [configure] com `AuthenticatedHttpClient`).
  static http.Client _httpClient = http.Client();

  /// Injeta o HTTP client. Chamar UMA vez no `app.dart`.
  static void configure(http.Client client) {
    _httpClient = client;
  }

  /// Extensões de vídeo reconhecidas.
  static const Set<String> videoExtensions = {
    '.mkv',
    '.mp4',
    '.avi',
    '.webm',
    '.mov',
    '.flv',
    '.wmv',
    '.m4v',
  };

  // ---------------- Parsing de listings HTML ----------------

  /// Re-exporta [safeDecodeComponent] do `url_codec.dart` para
  /// preservar compat com callers legados (e.g.
  /// `PauloFlixMoviesService.safeDecodeComponent(...)` no
  /// `pauloflix_movie_detail_screen.dart`).
  static String safeDecodeComponent(String input) =>
      url_codec.safeDecodeComponent(input);

  /// Faz parse de uma página de listing HTML e retorna os links.
  static List<_LinkEntry> _parseLinks(
    String htmlBody, {
    Map<String, String>? responseHeaders,
  }) {
    try {
      final decodedBody = _normalizeHtmlCharset(htmlBody, responseHeaders);
      final document = html_parser.parse(decodedBody);
      final elements = document.querySelectorAll('a[href]');
      final links = <_LinkEntry>[];
      for (final el in elements) {
        final href = el.attributes['href'] ?? '';
        final text = el.text.trim();
        if (href.isEmpty || href == '../' || text.isEmpty || text == '../') {
          continue;
        }
        final rawName = href.endsWith('/')
            ? href.substring(0, href.length - 1)
            : href;
        links.add(_LinkEntry(href: href, name: safeDecodeComponent(rawName)));
      }
      return links;
    } catch (e, s) {
      debugPrint('[PauloFlix Movies] _parseLinks error: $e\n$s');
      return [];
    }
  }

  /// Normaliza o body HTML para UTF-8 quando o servidor declara um
  /// charset não-UTF-8.
  static String _normalizeHtmlCharset(
    String htmlBody,
    Map<String, String>? responseHeaders,
  ) {
    final charset = url_codec.detectHtmlCharset(
      htmlBody,
      responseHeaders: responseHeaders,
    );
    if (charset == null) return htmlBody;
    if (charset.toLowerCase() == 'utf-8' || charset.toLowerCase() == 'utf8') {
      return htmlBody;
    }
    try {
      final bytes = latin1.encode(htmlBody);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      debugPrint('[PauloFlix Movies] Charset re-decode failed: $e');
      return htmlBody;
    }
  }

  /// Extrai o ano entre parênteses do nome da pasta. Retorna null se
  /// não houver `(YYYY)`.
  static int? extractYearFromFolder(String folderName) {
    final match = _yearInParens.firstMatch(folderName);
    if (match == null) return null;
    final raw = match.group(0)!;
    final yearStr = raw.substring(1, raw.length - 1);
    return int.tryParse(yearStr);
  }

  /// Regex de ano entre parênteses: `(2010)`, `(1985)`.
  static final RegExp _yearInParens = RegExp(r'\((19|20)\d{2}\)');

  /// Lista de tags decorativas removidas por [cleanTitleForTmdb].
  static const List<String> _decorativeTags = [
    '1080p', '720p', '480p', '2160p', '4K',
    'FULLHD', 'FullHD',
    'BRRip', 'BDRip', 'WEB-DL', 'WEBRip', 'WEB', 'HDTV',
    'HDRip', 'DVDRip', 'Open.Matte', 'Directors.Cut',
    'Extended', 'Versão Estendida', 'VERSAO ESTENDIDA',
    'x265', 'x264', 'HEVC', 'H265', 'H264', 'AV1', 'AVC',
    '10bit', 'Opus', 'AAC', 'AC3', 'DDP5.1', 'DD5.1',
    'DUAL', 'Dublado', 'Legendado',
    'WWW.BLUDV.COM', 'BLUDV.COM', 'WOLVERDONFILMES.COM', 'wolverdonfilmes.com',
    'GalaxyRG', 'YTS.MX', 'KONTRAST', 'Alan_680', 'AndreTPF',
    'LAPUMiA', 'Zero00', 'RARBG', 'TGx',
    'ThePirateFilmes', 'The.Pirate.Filmes',
  ];

  static final Map<RegExp, String> _subtitleLanguageTokens = {
    RegExp(r'\.pob\.srt$', caseSensitive: false): 'pt-BR',
    RegExp(r'\.pt[-_]br\.srt$', caseSensitive: false): 'pt-BR',
    RegExp(r'\.por\.srt$', caseSensitive: false): 'pt-BR',
    RegExp(r'\.pt\.srt$', caseSensitive: false): 'pt',
    RegExp(r'\.eng\.srt$', caseSensitive: false): 'en',
    RegExp(r'\.en\.srt$', caseSensitive: false): 'en',
    RegExp(r'\.spa\.srt$', caseSensitive: false): 'es',
    RegExp(r'\.es\.srt$', caseSensitive: false): 'es',
    RegExp(r'\.fra\.srt$', caseSensitive: false): 'fr',
    RegExp(r'\.fr\.srt$', caseSensitive: false): 'fr',
    RegExp(r'\.deu\.srt$', caseSensitive: false): 'de',
    RegExp(r'\.ger\.srt$', caseSensitive: false): 'de',
    RegExp(r'\.de\.srt$', caseSensitive: false): 'de',
    RegExp(r'\.ita\.srt$', caseSensitive: false): 'it',
    RegExp(r'\.it\.srt$', caseSensitive: false): 'it',
    RegExp(r'\.jpn\.srt$', caseSensitive: false): 'ja',
    RegExp(r'\.jp\.srt$', caseSensitive: false): 'ja',
  };

  static final RegExp _forcedSrtPattern = RegExp(
    r'\.forced\.srt$',
    caseSensitive: false,
  );

  static const Map<String, String> _languageDisplayNames = {
    'pt-BR': 'Português (Brasil)',
    'pt': 'Português',
    'en': 'Inglês',
    'es': 'Espanhol',
    'fr': 'Francês',
    'de': 'Alemão',
    'it': 'Italiano',
    'ja': 'Japonês',
  };

  static List<SubtitleTrackInfo> _rankAllSubtitles(
    List<_LinkEntry> subtitleFiles,
    String folderUrl,
  ) {
    if (subtitleFiles.isEmpty) return const [];

    int score(_LinkEntry l) {
      final fileName = _safeBase(l.href).toLowerCase();
      if (fileName.endsWith('.pob.srt') ||
          fileName.endsWith('.pt-br.srt') ||
          fileName.endsWith('.por.srt')) {
        return 100;
      }
      if (_forcedSrtPattern.hasMatch(fileName)) {
        if (fileName.contains('.pob.') || fileName.contains('.pt-br.')) {
          return 95;
        }
        return 60;
      }
      if (fileName.endsWith('.pt.srt')) return 90;
      for (final entry in _subtitleLanguageTokens.entries) {
        if (entry.key.hasMatch(fileName)) return 80;
      }
      return 50;
    }

    final sorted = [...subtitleFiles]
      ..sort((a, b) => score(b).compareTo(score(a)));

    return sorted.map((entry) {
      final base = _safeBase(entry.href).toLowerCase();
      String? langCode;
      for (final token in _subtitleLanguageTokens.entries) {
        if (token.key.hasMatch(base)) {
          langCode = token.value;
          break;
        }
      }
      langCode ??= 'pt-BR';
      final forced = _forcedSrtPattern.hasMatch(base);
      final displayName = _languageDisplayNames[langCode] ?? langCode;
      final fullDisplayName = forced ? '$displayName (forçado)' : displayName;
      final url = '$folderUrl${Uri.encodeComponent(entry.name)}';
      return SubtitleTrackInfo(
        url: url,
        language: langCode,
        displayName: fullDisplayName,
        forced: forced,
      );
    }).toList();
  }

  static String _safeBase(String href) {
    final parts = href.split('/');
    var last = parts.isEmpty ? href : parts.last;
    try {
      last = Uri.decodeComponent(last);
    } catch (e) {
      debugPrint('Erro ao decodificar URL component: $e');
    }
    return last;
  }

  static const Set<String> _imageExtensions = {
    '.jpg', '.jpeg', '.png', '.webp',
  };

  static const _posterNames = {'poster', 'cover', 'folder', 'movie-poster'};
  static const _fanartNames = {'fanart', 'backdrop', 'banner', 'movie-banner'};

  static _DetectedImages _detectImageFiles(List<_LinkEntry> links) {
    String? poster;
    String? fanart;
    String? firstImage;

    for (final link in links) {
      final name = link.name.toLowerCase();
      final base = name.contains('.')
          ? name.substring(0, name.lastIndexOf('.'))
          : name;
      final ext = name.contains('.')
          ? name.substring(name.lastIndexOf('.'))
          : '';
      if (!_imageExtensions.contains(ext)) continue;

      firstImage ??= link.name;

      if (poster == null && _posterNames.contains(base)) {
        poster = link.name;
        continue;
      }
      if (fanart == null && _fanartNames.contains(base)) {
        fanart = link.name;
        continue;
      }
      if (poster == null && _posterNames.any((n) => base.contains(n))) {
        poster = link.name;
        continue;
      }
      if (fanart == null && _fanartNames.any((n) => base.contains(n))) {
        fanart = link.name;
        continue;
      }
    }

    poster ??= firstImage;
    return _DetectedImages(poster: poster, fanart: fanart);
  }

  /// Limpa o nome da pasta para produzir um título buscável no TMDB.
  static String cleanTitleForTmdb(String folderName) {
    var name = folderName;
    name = name.replaceAll(_yearInParens, ' ');
    name = name.replaceAll(RegExp(r'\[(19|20)\d{2}\]'), ' ');
    for (final tag in _decorativeTags) {
      final escaped = RegExp.escape(tag);
      name = name.replaceAll(RegExp(escaped, caseSensitive: false), ' ');
    }
    name = name.replaceAll(RegExp(r'[._+\-]+'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    name = name.replaceAll(RegExp(r'^[^\wÀ-ÿ]+|[^\wÀ-ÿ]+$'), '');
    return name;
  }

  // ---------------- Inspeção de pasta (scraping on-demand) ----------------

  /// Resultado do scraping on-demand de uma pasta para uso pelo
  /// [PauloFlixMoviesProvider] (tela de detalhe).
  static Future<PauloFlixMovieRaw> inspectFolder(
    String folderName,
    String folderUrl,
  ) async {
    final folderTitle = cleanTitleForTmdb(folderName);
    final folderYear = extractYearFromFolder(folderName);

    debugPrint(
      '[PauloFlix Movies] Inspecting: $folderUrl — '
      'title="$folderTitle", year=${folderYear ?? "?"}',
    );

    try {
      final response = await _httpClient
          .get(Uri.parse(folderUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return PauloFlixMovieRaw.empty(
          folderName: folderName,
          folderUrl: folderUrl,
        );
      }

      final links = _parseLinks(
        response.body,
        responseHeaders: response.headers,
      );

      final subtitleFiles = links
          .where(
            (l) =>
                l.href.toLowerCase().endsWith('.srt') ||
                l.name.toLowerCase().endsWith('.srt'),
          )
          .toList();
      final rankedSubtitles = _rankAllSubtitles(subtitleFiles, folderUrl);

      final videoFiles = links
          .where(
            (l) => videoExtensions.any(
              (ext) => l.href.toLowerCase().endsWith(ext),
            ),
          )
          .toList();

      if (videoFiles.isEmpty) {
        videoFiles.addAll(
          links.where(
            (l) => videoExtensions.any(
              (ext) => l.name.toLowerCase().endsWith(ext),
            ),
          ),
        );
      }

      if (videoFiles.isNotEmpty) {
        final first = videoFiles.first;
        final videoUrl = '$folderUrl${Uri.encodeComponent(first.name)}';
        final imageFiles = _detectImageFiles(links);
        return PauloFlixMovieRaw.single(
          folderName: folderName,
          folderUrl: folderUrl,
          videoFile: PauloFlixMovieFile(
            folderName: folderName,
            folderUrl: folderUrl,
            videoFileName: first.name,
            videoUrl: videoUrl,
            cleanedName: folderTitle,
            year: folderYear,
            subtitles: rankedSubtitles,
          ),
          posterFileName: imageFiles.poster,
          fanartFileName: imageFiles.fanart,
        );
      }

      final subFolders = links
          .where((l) => l.href.endsWith('/'))
          .map(
            (l) => PauloFlixMovieSubfolder(
              name: l.name,
              url: '$folderUrl${l.href}',
            ),
          )
          .toList();

      if (subFolders.isNotEmpty) {
        return PauloFlixMovieRaw.collection(
          folderName: folderName,
          folderUrl: folderUrl,
          subfolders: subFolders,
        );
      }

      return PauloFlixMovieRaw.empty(
        folderName: folderName,
        folderUrl: folderUrl,
      );
    } catch (e) {
      debugPrint('[PauloFlix Movies] inspectFolder error: $e');
      return PauloFlixMovieRaw.empty(
        folderName: folderName,
        folderUrl: folderUrl,
      );
    }
  }

  // ---------------- Sincronização (JSON index) ----------------

  /// Sincroniza todo o conteúdo do PauloFlix Movies a partir do JSON
  /// index do servidor (`movie_index.json`).
  ///
  /// ## Diferenças do sync legado (HTML scraping + TMDB)
  ///
  /// - **Sem scraping HTML:** o JSON index contém todos os metadados
  ///   (título, ano, descrição, poster, fanart, gêneros, rating, etc.).
  /// - **Sem API externa (TMDB):** toda a informação vem do JSON,
  ///   eliminando chamadas HTTP externas e rate limiting.
  /// - **Sem TTL:** o JSON é fonte da verdade — cada sync processa
  ///   todos os filmes e atualiza o banco via `DoUpdate` (UPSERT real).
  ///
  /// [enricher] e o fluxo TMDB são mantidos apenas para compatibilidade
  /// de assinatura — são **ignorados** neste sync.
  static Future<bool> syncContent({
    required PauloFlixMoviesRepository repository,
    void Function(String progress)? onProgress,
    void Function(String error)? onError,

    /// Mantido para compatibilidade de assinatura — **ignorado**.
    // ignore: avoid_unused_constructor_parameters
    PauloFlixNfoEnricher? enricher,
  }) async {
    try {
      onProgress?.call('Baixando índice JSON do PauloFlix Movies...');
      final response = await _httpClient
          .get(Uri.parse(indexUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        onError?.call('Erro ao baixar índice: HTTP ${response.statusCode}');
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> moviesJson = data['movies'] as List<dynamic>;

      if (moviesJson.isEmpty) {
        onError?.call('Nenhum filme encontrado no índice JSON');
        return false;
      }

      onProgress?.call('Índice baixado: ${moviesJson.length} filmes');

      // Converte todos os filmes do JSON para PauloFlixMovie
      final List<PauloFlixMovie> contents = [];
      for (final movieJson in moviesJson) {
        final json = movieJson as Map<String, dynamic>;
        contents.add(
          PauloFlixMovie.fromMovieIndex(
            json: json,
            baseHost: _baseHost,
          ),
        );
      }

      // Busca filmes existentes no banco
      final existingContent = await repository.getAll();
      final existingPaths =
          existingContent.map((c) => c.folderName).toSet();
      final currentPaths = contents.map((c) => c.folderName).toSet();

      // Filmes que sumiram do servidor
      final removedPaths = existingPaths.difference(currentPaths);

      if (removedPaths.isNotEmpty) {
        onProgress?.call(
          'Marcando ${removedPaths.length} filmes removidos...',
        );
      }

      // Salva todos os filmes (DoUpdate lida com conflitos)
      onProgress?.call('Salvando ${contents.length} filmes no banco...');
      await repository.saveBatch(contents);

      // Marca filmes removidos
      for (final path in removedPaths) {
        await repository.markAsUnavailable(path);
      }

      final totalAvailable =
          existingContent.length - removedPaths.length;
      onProgress?.call('Sincronização completa: $totalAvailable filmes');
      return true;
    } catch (e) {
      debugPrint('[PauloFlix Movies] syncContent error: $e');
      onError?.call('Erro na sincronização: $e');
      return false;
    }
  }

  /// Retorna o arquivo de vídeo (.mkv/.mp4) de uma pasta de filme.
  /// Usado pela tela de detalhe (scraping on-demand da pasta).
  static Future<PauloFlixMovieFile?> fetchMovieFile(String folderUrl) async {
    final segments = folderUrl.split('/');
    final rawName = segments[segments.length - 2].isEmpty
        ? segments[segments.length - 1]
        : segments[segments.length - 2];
    final folderName = safeDecodeComponent(rawName);
    final inspected = await inspectFolder(folderName, folderUrl);
    if (inspected.type == MovieFolderType.single) {
      return inspected.videoFile;
    }
    return null;
  }
}

/// Resultado de [PauloFlixMoviesService._detectImageFiles] —
/// `poster` e `fanart` são os **nomes de arquivo** (não URLs)
/// encontrados na pasta, ou null se ausentes.
class _DetectedImages {
  final String? poster;
  final String? fanart;
  const _DetectedImages({this.poster, this.fanart});
}

class _LinkEntry {
  final String href;
  final String name;
  const _LinkEntry({required this.href, required this.name});
}
