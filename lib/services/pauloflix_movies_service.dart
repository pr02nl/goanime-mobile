import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/pauloflix_movie.dart';
import '../models/pauloflix_movie_item.dart';
import 'pauloflix_movies_database_service.dart';
import 'tmdb_service.dart';

/// Lê diretórios HTML do PauloFlix Movies e enriquece com metadados do TMDB.
class PauloFlixMoviesService {
  static const String baseUrl = 'http://100.95.105.113:8300/movies/';

  /// Extensões de vídeo reconhecidas.
  static const Set<String> videoExtensions = {
    '.mkv', '.mp4', '.avi', '.webm', '.mov', '.flv', '.wmv', '.m4v',
  };

  // ---------------- Parsing de listings HTML ----------------

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
        final decodedName = Uri.decodeComponent(
          text.endsWith('/') ? text.substring(0, text.length - 1) : text,
        );
        links.add(_LinkEntry(href: href, name: decodedName));
      }
      return links;
    } catch (e) {
      debugPrint('[PauloFlix Movies] _parseLinks error: $e');
      return [];
    }
  }

  /// Detecta se uma pasta contém um filme individual ou coleção de sub-pastas.
  static Future<PauloFlixMovieRaw> inspectFolder(
    String folderName,
    String folderUrl,
  ) async {
    try {
      debugPrint('[PauloFlix Movies] Inspecting: $folderUrl');
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

      // Arquivos de vídeo (sem '/' no href)
      final videoFiles = links
          .where(
            (l) => videoExtensions.any(
              (ext) => l.name.toLowerCase().endsWith(ext),
            ),
          )
          .toList();

      if (videoFiles.isNotEmpty) {
        final first = videoFiles.first;
        final videoUrl = '$folderUrl${Uri.encodeComponent(first.name)}';
        final cleaned = cleanMovieName(first.name);
        return PauloFlixMovieRaw.single(
          folderName: folderName,
          folderUrl: folderUrl,
          videoFile: PauloFlixMovieFile(
            folderName: folderName,
            folderUrl: folderUrl,
            videoFileName: first.name,
            videoUrl: videoUrl,
            cleanedName: cleaned,
            year: extractYear(first.name) ?? extractYear(folderName),
          ),
        );
      }

      // Sub-pastas
      final subFolders = links
          .where((l) => l.href.endsWith('/'))
          .map((l) => PauloFlixMovieSubfolder(name: l.name, url: '$folderUrl${l.href}'))
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

  // ---------------- Limpeza de nome ----------------

  /// Remove extensão.
  static String _removeExtension(String s) {
    return s.replaceAll(
      RegExp(r'\.(mkv|mp4|avi|webm|mov|flv|wmv|m4v)$', caseSensitive: false),
      '',
    );
  }

  /// Extrai ano (YYYY) do texto, se presente.
  static int? extractYear(String text) {
    final match = RegExp(r'\b(19|20)\d{2}\b').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  /// Limpa nome de arquivo bagunçado e devolve um título "limpo" para busca.
  static String cleanMovieName(String rawName) {
    var name = rawName;

    // 1) Extensão
    name = _removeExtension(name);

    // 2) Ano entre parênteses ou colchetes (ex: " (2010) " ou " [1985] ")
    name = name.replaceAll(RegExp(r'\s*[\[\(](19|20)\d{2}[\]\)]\s*'), ' ');

    // 3) Tags em ordem (case-insensitive). Mais longas primeiro para evitar prefixos.
    _removeInOrder(name, _qualityTags);
    name = _stripAfter(_qualityTags, name);

    _stripAfter(_codecs, name);
    _stripAfter(_audioTags, name);
    _stripAfter(_groups, name);
    _stripAfter(_extraTags, name);

    // 4) Pontos/underscores viram espaço, normaliza múltiplos espaços, limpa pontuação solta
    name = name.replaceAll(RegExp(r'[._]+'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove caracteres especiais nas pontas
    name = name.replaceAll(RegExp(r'^[^\wÀ-ÿ]+|[^\wÀ-ÿ]+$'), '');

    return name;
  }

  // Tags estáticas (case-insensitive em _stripAfter).
  static const List<String> _qualityTags = [
    'Open.Matte', 'Directors.Cut', 'Remasterizada', 'Remastered',
    'Versão Estendida', 'VERSAO ESTENDIDA',
    'BluRay', 'BRRip', 'BDRip', 'WEB-DL', 'WEBRip', 'WEB', 'HDTV',
    'HDRip', 'DVDRip', 'Extended', 'FullHD', 'FULLHD',
    '1080p', '720p', '480p', '2160p', '4K',
  ];

  static const List<String> _codecs = [
    'x265', 'x264', 'HEVC', 'H265', 'H264', 'AV1', 'AVC', 'Opus', '10bit',
  ];

  static const List<String> _audioTags = [
    'Dual.Áudio', 'Dual Audio', 'Dual.Audio', 'Dual.áudio',
    'DUAL', 'Dublado', 'Legendado',
    'DDP5.1', 'DD5.1', '5.1', '7.1', 'AAC', 'AC3',
  ];

  static const List<String> _groups = [
    'WWW.BLUDV.COM', 'BLUDV.COM', 'wolverdonfilmes.com',
    'WOLVERDONFILMES.COM',
    'GalaxyRG', 'YTS.MX', 'KONTRAST', 'Alan_680', 'AndreTPF',
    'LAPUMiA', 'Zero00', 'FG4LL4RD0', 'RARBG', 'TGx',
    'ThePirateFilmes', 'The.Pirate.Filmes',
    'Rich_jc', 'rich_jc',
  ];

  static const List<String> _extraTags = [
    'Coleção', 'COLEÇÃO', 'Colecao',
  ];

  static void _removeInOrder(String input, List<String> tags) {
    // No-op — usado via _stripAfter para garantir imutabilidade
  }

  static String _stripAfter(List<String> tags, String input) {
    var result = input;
    for (final tag in tags) {
      // Escapa caracteres regex especiais no tag antes de montar o pattern
      final escaped = RegExp.escape(tag);
      result = result.replaceAll(RegExp(escaped, caseSensitive: false), ' ');
    }
    return result;
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
        onError?.call(
          'TMDB não configurado. Vá em Configurações → API Keys.',
        );
        return false;
      }

      onProgress?.call('Buscando pastas do PauloFlix Movies...');
      final folders = await fetchRootFolders();
      if (folders.isEmpty) {
        onError?.call('Nenhuma pasta encontrada em /movies/');
        return false;
      }
      onProgress
          ?.call('Encontradas ${folders.length} pastas. Inspecionando...');

      final db = PauloFlixMoviesDatabaseService();
      final existing = await db.getAllContent();
      final existingFolders = existing.map((c) => c.folderName).toSet();
      final currentFolders = folders.map((f) => f.name).toSet();

      // Marca removidos
      final removed = existingFolders.difference(currentFolders);
      if (removed.isNotEmpty) {
        onProgress?.call('Marcando ${removed.length} filmes removidos...');
        for (final name in removed) {
          await db.markAsUnavailable(name);
        }
      }

      // Coleta tudo o que precisa enriquecer
      final needsEnrich = existing
          .where(
            (c) =>
                c.imageUrl == null ||
                c.imageUrl!.isEmpty ||
                (c.isCollection == false &&
                    c.availableMovieCount == 0),
          )
          .map((c) => folders.firstWhere(
                (f) => f.name == c.folderName,
                orElse: () => folders.first,
              ))
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
        return true;
      }

      onProgress
          ?.call('Processando ${toProcess.length} pastas no TMDB...');

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
                video.cleanedName.isEmpty ? folder.name : video.cleanedName,
                year: video.year,
                limit: 3,
              );
              final match =
                  tmdb.matchInResults(searchResults, video.cleanedName);
              if (match != null) {
                contents.add(
                  PauloFlixMovie.fromTmdb(
                    folderName: folder.name,
                    serverUrl: folder.url,
                    tmdb: match,
                  ),
                );
              } else {
                contents.add(_placeholder(folder.name, folder.url,
                    displayName: video.cleanedName));
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
              contents.add(
                _placeholder(folder.name, folder.url),
              );
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
    // folderUrl já aponta para a sub-pasta; estima-se que é um filme.
    // Reaproveita inspectFolder para reutilizar a lógica de detecção.
    final segments = folderUrl.split('/');
    final folderName = Uri.decodeComponent(
      segments[segments.length - 2].isEmpty
          ? segments[segments.length - 1]
          : segments[segments.length - 2],
    );
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
