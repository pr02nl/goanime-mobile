import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../data/services/tmdb_service.dart';
import '../domain/models/pauloflix_movie.dart';
import '../domain/models/pauloflix_movie_item.dart';
import 'pauloflix_movies_database_service.dart';

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
///
/// Para **coleções** (pastas só com sub-pastas, ex: `Coleção Harry Potter`),
/// o nome da pasta é usado como displayName sem extração de ano.
///
/// O nome do arquivo (`.mkv`/`.mp4`) só é usado para localizar a URL de
/// streaming — nunca é passado pro TMDB.
class PauloFlixMoviesService {
  static const String baseUrl = 'http://100.95.105.113:8300/movies/';
  static const Duration reEnrichThreshold = Duration(days: 7);

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

  /// Decodifica um componente URI de forma defensiva.
  ///
  /// [Uri.decodeComponent] lança [ArgumentError] quando o input contém
  /// sequências `%` inválidas (e.g. `%XY` onde `XY` não é hexadecimal).
  /// Isso acontece com nomes de pastas no servidor que já vêm com `%`
  /// literal (não decodificado duas vezes).
  ///
  /// Aqui, em caso de erro, devolvemos o input original — o `%` segue
  /// como caractere válido no nome, o que é preferível a abortar o
  /// parse e perder o restante da listagem.
  static String safeDecodeComponent(String input) {
    if (input.isEmpty) return input;
    try {
      return Uri.decodeComponent(input);
    } on ArgumentError {
      final buf = StringBuffer();
      final pattern = RegExp(r'%([0-9A-Fa-f]{2})');
      int lastEnd = 0;
      for (final match in pattern.allMatches(input)) {
        buf.write(input.substring(lastEnd, match.start));
        buf.write(Uri.decodeComponent('%${match.group(1)!}'));
        lastEnd = match.end;
      }
      buf.write(input.substring(lastEnd));
      return buf.toString();
    } catch (e) {
      debugPrint('[PauloFlix Movies] Erro ao decodificar URL manualmente: $e');
      return input;
    }
  }

  /// Faz parse de uma página de listing HTML e retorna os links.
  static List<_LinkEntry> _parseLinks(String htmlBody) {
    try {
      final document = html_parser.parse(htmlBody);
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

  /// Detecta se uma pasta contém um filme individual ou coleção de sub-pastas.
  ///
  /// - O **título** do filme é derivado do `folderName` (com remoção leve
  ///   de tags).
  /// - O **ano** é extraído pela regex `(YYYY)` no `folderName`.
  /// - O **arquivo de vídeo** é o primeiro `.mkv`/`.mp4` encontrado —
  ///   a URL dele é o `videoUrl` final a ser enviado ao player.
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
      final response = await http
          .get(Uri.parse(folderUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return PauloFlixMovieRaw.empty(
          folderName: folderName,
          folderUrl: folderUrl,
        );
      }

      final links = _parseLinks(response.body);

      // Arquivos de legenda (.srt) —lista completa, ranking aplicado depois.
      final subtitleFiles = links
          .where(
            (l) =>
                l.href.toLowerCase().endsWith('.srt') ||
                l.name.toLowerCase().endsWith('.srt'),
          )
          .toList();
      final rankedSubtitles = _rankAllSubtitles(subtitleFiles, folderUrl);

      // Arquivos de vídeo (sem '/' no href)
      final videoFiles = links
          .where(
            (l) => videoExtensions.any(
              (ext) => l.href.toLowerCase().endsWith(ext),
            ),
          )
          .toList();

      // Procura também por nome (caso o link receba href e text iguais)
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
        );
      }

      // Sub-pastas (coleção)
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

  /// Lista todas as pastas raiz de /movies/.
  static Future<List<PauloFlixMovieSubfolder>> fetchRootFolders() async {
    try {
      debugPrint('[PauloFlix Movies] Fetching root: $baseUrl');
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final links = _parseLinks(response.body);
      return links
          .where((l) => l.href.endsWith('/'))
          .map(
            (l) => PauloFlixMovieSubfolder(
              name: l.name,
              url: '$baseUrl${Uri.encodeComponent(l.name)}/',
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[PauloFlix Movies] fetchRootFolders error: $e');
      return [];
    }
  }

  // ---------------- Extração de título + ano ----------------

  /// Regex de ano entre parênteses: `(2010)`, `(1985)`.
  static final RegExp _yearInParens = RegExp(r'\((19|20)\d{2}\)');

  /// Extrai o ano entre parênteses do nome da pasta. Retorna null se
  /// não houver `(YYYY)`.
  ///
  /// Importante: a regex é deliberadamente restrita a parênteses
  /// (não colchetes) e exige exatamente 4 dígitos começando com `19` ou
  /// `20` — isso evita falsos positivos com anos embutidos em tags
  /// de codec (ex: `x265` → false, mas `(2010)` → matched).
  static int? extractYearFromFolder(String folderName) {
    final match = _yearInParens.firstMatch(folderName);
    if (match == null) return null;
    final raw = match.group(0)!; // "(2010)"
    final yearStr = raw.substring(1, raw.length - 1);
    return int.tryParse(yearStr);
  }

  /// Tags comuns que aparecem em nomes de pastas como ornamentação.
  /// Case-insensitive. Removidas por [cleanTitleForTmdb].
  static const List<String> _decorativeTags = [
    // Qualidade
    '1080p', '720p', '480p', '2160p', '4K',
    'FULLHD', 'FullHD',
    'BRRip', 'BDRip', 'WEB-DL', 'WEBRip', 'WEB', 'HDTV',
    'HDRip', 'DVDRip', 'Open.Matte', 'Directors.Cut',
    'Extended', 'Versão Estendida', 'VERSAO ESTENDIDA',
    // Codec / áudio
    'x265', 'x264', 'HEVC', 'H265', 'H264', 'AV1', 'AVC',
    '10bit', 'Opus', 'AAC', 'AC3', 'DDP5.1', 'DD5.1',
    'DUAL', 'Dublado', 'Legendado',
    // Grupos
    'WWW.BLUDV.COM', 'BLUDV.COM', 'WOLVERDONFILMES.COM', 'wolverdonfilmes.com',
    'GalaxyRG', 'YTS.MX', 'KONTRAST', 'Alan_680', 'AndreTPF',
    'LAPUMiA', 'Zero00', 'RARBG', 'TGx',
    'ThePirateFilmes', 'The.Pirate.Filmes',
  ];

  /// Mapa estático (não const porque `RegExp` não tem construtor const)
  /// de tokens de idioma comum em legendas SRT → código BCP-47.
  ///
  /// Ordem na estrutura reflete prioridade de matching.
  static final Map<RegExp, String> _subtitleLanguageTokens = {
    // PT-BR tem prioridade máxima
    RegExp(r'\.pob\.srt$', caseSensitive: false): 'pt-BR',
    RegExp(r'\.pt[-_]br\.srt$', caseSensitive: false): 'pt-BR',
    RegExp(r'\.por\.srt$', caseSensitive: false): 'pt-BR',
    RegExp(r'\.pt\.srt$', caseSensitive: false): 'pt',
    // Outros idiomas
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

  /// Detecta se o arquivo `.srt` é uma legenda "forced" — versão de
  /// trechos traduzidos que ficam visíveis mesmo sem selecionar faixa
  /// (e.g. signos em língua estrangeira no filme).
  static final RegExp _forcedSrtPattern = RegExp(
    r'\.forced\.srt$',
    caseSensitive: false,
  );

  /// Rótulos amigáveis para o selector no player. Mantém ordem
  /// canônica para conseguir match determinístico.
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

  /// Retorna TODAS as legendas candidatas (ordenadas por prioridade),
  /// com `SubtitleTrackInfo` completo para cada uma —incluindo o
  /// displayName amigável.
  ///
  /// Quando não há nenhum `.srt` na pasta, retorna lista vazia.
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
      // Detecta idioma
      String? langCode;
      for (final token in _subtitleLanguageTokens.entries) {
        if (token.key.hasMatch(base)) {
          langCode = token.value;
          break;
        }
      }
      langCode ??= 'pt-BR';

      // Detecta forced
      final forced = _forcedSrtPattern.hasMatch(base);

      // Display name: "[Idioma] (forçado)" se forced, senão só "[Idioma]"
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

  /// Extrai só o nome do arquivo de uma URL ou nome completo (sem separadores
  /// de path).
  static String _safeBase(String href) {
    final parts = href.split('/');
    var last = parts.isEmpty ? href : parts.last;
    // Decodifica %XX se houver
    try {
      last = Uri.decodeComponent(last);
    } catch (e) {
      debugPrint('Erro ao decodificar URL component: $e');
    }
    return last;
  }

  /// Limpa o nome da pasta para produzir um título buscável no TMDB.
  ///
  /// Regras:
  /// 1. Remove o `(YYYY)` se houver (vai ser usado como filtro separado).
  /// 2. Remove ano solto entre colchetes `[1985]`.
  /// 3. Remove tags decorativas (qualidade, codecs, áudio, grupos).
  /// 4. Substitui `.`, `_`, `-`, `+` por espaço.
  /// 5. Colapsa múltiplos espaços, remove acentos das pontas.
  ///
  /// Exemplos:
  /// - `A Origem (2010)` → `A Origem`
  /// - `Constantine 2005 (1080p) WWW.BLUDV.COM` → `Constantine 2005`
  /// - `Coleção Harry Potter 2001 - 2011  WWW.BLUDV.COM` → `Coleção Harry Potter 2001 2011`
  static String cleanTitleForTmdb(String folderName) {
    var name = folderName;

    // 1) Remove (YYYY) — vai ser extraído separadamente
    name = name.replaceAll(_yearInParens, ' ');

    // 2) Remove [YYYY] também
    name = name.replaceAll(RegExp(r'\[(19|20)\d{2}\]'), ' ');

    // 3) Remove tags decorativas
    for (final tag in _decorativeTags) {
      final escaped = RegExp.escape(tag);
      name = name.replaceAll(RegExp(escaped, caseSensitive: false), ' ');
    }

    // 4) Pontuação virando espaço
    name = name.replaceAll(RegExp(r'[._+\-]+'), ' ');

    // 5) Normaliza múltiplos espaços + trim + remove pontas
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    name = name.replaceAll(RegExp(r'^[^\wÀ-ÿ]+|[^\wÀ-ÿ]+$'), '');

    return name;
  }

  // ---------------- Sincronização ----------------

  /// Sincroniza todo o conteúdo:
  /// - Marca como indisponível o que não está mais em /movies/
  /// - Enriquece com metadados TMDB apenas o que é novo OU está sem imagem
  static Future<bool> syncContent({
    void Function(String progress)? onProgress,
    void Function(String error)? onError,
  }) async {
    try {
      final tmdb = TmdbService();
      if (!tmdb.isConfigured) {
        onError?.call('TMDB não configurado. Vá em Configurações → API Keys.');
        return false;
      }

      onProgress?.call('Buscando pastas do PauloFlix Movies...');
      final folders = await fetchRootFolders();
      if (folders.isEmpty) {
        onError?.call('Nenhuma pasta encontrada em /movies/');
        return false;
      }
      onProgress?.call(
        'Encontradas ${folders.length} pastas. Inspecionando...',
      );

      final db = PauloFlixMoviesDatabaseService();
      final existing = await db.getAllContent();
      final existingFolders = existing.map((c) => c.folderName).toSet();
      final currentFolders = folders.map((f) => f.name).toSet();

      final removed = existingFolders.difference(currentFolders);
      final staleThreshold = DateTime.now().subtract(reEnrichThreshold);

      // Coleta tudo o que precisa enriquecer
      final needsEnrich = existing
          .where(
            (c) =>
                currentFolders.contains(c.folderName) &&
                (c.imageUrl == null ||
                    c.imageUrl!.isEmpty ||
                    (c.isCollection == false && c.availableMovieCount == 0) ||
                    c.lastSynced.isBefore(staleThreshold)),
          )
          .map((c) {
            final match = folders.where((f) => f.name == c.folderName);
            return match.isNotEmpty ? match.first : null;
          })
          .whereType<PauloFlixMovieSubfolder>()
          .toList();

      final newFolders = folders
          .where((f) => !existingFolders.contains(f.name))
          .toList();

      final toProcess = <PauloFlixMovieSubfolder>[...newFolders];
      for (final f in needsEnrich) {
        if (!toProcess.any((tf) => tf.name == f.name)) toProcess.add(f);
      }

      if (toProcess.isEmpty) {
        onProgress?.call('Sincronização completa: ${existing.length} itens');
        if (removed.isNotEmpty) {
          for (final name in removed) {
            await db.markAsUnavailable(name);
          }
        }
        await db.removeStaleContent();
        return true;
      }

      onProgress?.call('Processando ${toProcess.length} pastas no TMDB...');

      final List<PauloFlixMovie> contents = [];
      int processed = 0;

      for (final folder in toProcess) {
        processed++;
        onProgress?.call(
          'Processando ${folder.name} ($processed/${toProcess.length})',
        );

        try {
          final raw = await inspectFolder(folder.name, folder.url);
          switch (raw.type) {
            case MovieFolderType.single:
              final video = raw.videoFile!;
              final searchResults = await tmdb.searchMovies(
                video.cleanedName,
                year: video.year,
                limit: 3,
              );
              final match = tmdb.matchInResults(
                searchResults,
                video.cleanedName,
              );
              if (match != null) {
                contents.add(
                  PauloFlixMovie.fromTmdb(
                    folderName: folder.name,
                    serverUrl: folder.url,
                    tmdb: match,
                  ),
                );
              } else {
                contents.add(
                  _placeholder(
                    folder.name,
                    folder.url,
                    displayName: video.cleanedName,
                  ),
                );
              }
              break;

            case MovieFolderType.collection:
              contents.add(
                PauloFlixMovie(
                  folderName: folder.name,
                  serverUrl: folder.url,
                  displayName: folder.name,
                  isCollection: true,
                  availableMovieCount: raw.subfolders.length,
                ),
              );
              break;

            case MovieFolderType.empty:
              contents.add(_placeholder(folder.name, folder.url));
              break;
          }
        } catch (e) {
          debugPrint('[PauloFlix Movies] Error on ${folder.name}: $e');
          contents.add(_placeholder(folder.name, folder.url));
        }

        // Throttle amigável para o TMDB
        if (processed % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      onProgress?.call('Salvando ${contents.length} itens no banco...');
      await db.saveBatch(contents);

      if (removed.isNotEmpty) {
        onProgress?.call('Marcando ${removed.length} filmes removidos...');
        for (final name in removed) {
          await db.markAsUnavailable(name);
        }
      }
      await db.removeStaleContent();

      final totalAvailable =
          existing.length - removed.length + newFolders.length;
      onProgress?.call('Sincronização completa: $totalAvailable filmes');
      return true;
    } catch (e) {
      debugPrint('[PauloFlix Movies] syncContent error: $e');
      onError?.call('Erro na sincronização: $e');
      return false;
    }
  }

  static PauloFlixMovie _placeholder(
    String folderName,
    String folderUrl, {
    String? displayName,
  }) {
    return PauloFlixMovie(
      folderName: folderName,
      serverUrl: folderUrl,
      displayName: displayName ?? folderName,
    );
  }

  /// Retorna o arquivo de vídeo (.mkv/.mp4) de uma pasta de filme.
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

class _LinkEntry {
  final String href;
  final String name;
  const _LinkEntry({required this.href, required this.name});
}
