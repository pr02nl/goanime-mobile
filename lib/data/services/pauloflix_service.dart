import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../domain/models/pauloflix_content.dart';
import '../../domain/models/pauloflix_models.dart';
import '../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import '../../domain/repositories/pauloflix_repository.dart';
import '../models/jikan_models.dart';
import 'jikan_service.dart';

class PauloFlixService {
  static const String baseUrl = ApiConstants.animePauloFlix;
  static const Duration reEnrichThreshold = Duration(days: 7);

  static Future<List<PauloFlixShow>> fetchAllShows() async {
    try {
      debugPrint('[PauloFlix] Fetching all shows from $baseUrl');
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('[PauloFlix] Failed to fetch shows: ${response.statusCode}');
        return [];
      }
      final document = html_parser.parse(response.body);
      final linkElements = document.querySelectorAll('a[href]');
      final List<PauloFlixShow> shows = [];
      for (final element in linkElements) {
        final href = element.attributes['href'] ?? '';
        final text = element.text.trim();
        if (href == '../' || href.isEmpty || text.isEmpty || text == '../') {
          continue;
        }
        if (!href.endsWith('/')) continue;
        final rawName = href.substring(0, href.length - 1);
        final decodedName = Uri.decodeComponent(rawName);
        final absoluteUrl = '$baseUrl$href';
        shows.add(PauloFlixShow(name: decodedName, url: absoluteUrl));
      }
      debugPrint('[PauloFlix] Found ${shows.length} shows');
      return shows;
    } catch (e) {
      debugPrint('[PauloFlix] Error fetching shows: $e');
      throw Exception('Error fetching PauloFlix shows: $e');
    }
  }

  static Future<List<PauloFlixSeason>> fetchShowSeasons(String showUrl) async {
    try {
      debugPrint('[PauloFlix] Fetching seasons from $showUrl');
      final response = await http
          .get(Uri.parse(showUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint(
          '[PauloFlix] Failed to fetch seasons: ${response.statusCode}',
        );
        return [];
      }
      final document = html_parser.parse(response.body);
      final linkElements = document.querySelectorAll('a[href]');
      final List<PauloFlixSeason> seasons = [];
      for (final element in linkElements) {
        final href = element.attributes['href'] ?? '';
        final text = element.text.trim();
        if (href == '../' || href.isEmpty || text.isEmpty || text == '../') {
          continue;
        }
        if (!href.endsWith('/')) continue;
        final rawName = href.substring(0, href.length - 1);
        final decodedName = Uri.decodeComponent(rawName);
        final seasonNumber = _extractSeasonNumber(decodedName);
        if (seasonNumber == null) continue;
        final absoluteUrl = '$showUrl$href';
        seasons.add(
          PauloFlixSeason(
            name: decodedName,
            url: absoluteUrl,
            number: seasonNumber,
          ),
        );
      }
      seasons.sort((a, b) => a.number.compareTo(b.number));
      debugPrint('[PauloFlix] Found ${seasons.length} seasons');
      return seasons;
    } catch (e) {
      debugPrint('[PauloFlix] Error fetching seasons: $e');
      throw Exception('Error fetching PauloFlix seasons: $e');
    }
  }

  /// Supported video extensions
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

  static Future<List<PauloFlixEpisode>> fetchSeasonEpisodes(
    String seasonUrl,
  ) async {
    try {
      debugPrint('[PauloFlix] Fetching episodes from $seasonUrl');
      final response = await http
          .get(Uri.parse(seasonUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint(
          '[PauloFlix] Failed to fetch episodes: ${response.statusCode}',
        );
        return [];
      }
      final document = html_parser.parse(response.body);
      final linkElements = document.querySelectorAll('a[href]');
      final List<PauloFlixEpisode> episodes = [];
      for (final element in linkElements) {
        final href = element.attributes['href'] ?? '';
        final text = element.text.trim();
        if (href == '../' || href.isEmpty || text.isEmpty || text == '../') {
          continue;
        }
        final lowerHref = href.toLowerCase();
        final hasVideoExtension = videoExtensions.any(
          (ext) => lowerHref.endsWith(ext),
        );
        if (!hasVideoExtension) continue;
        final decodedName = Uri.decodeComponent(href);
        final episodeInfo = _extractEpisodeInfo(decodedName);
        if (episodeInfo == null) continue;
        final absoluteUrl = '$seasonUrl$href';
        episodes.add(
          PauloFlixEpisode(
            number: episodeInfo.number,
            title: episodeInfo.title,
            url: absoluteUrl,
            fileSize: null,
          ),
        );
      }
      episodes.sort((a, b) => a.number.compareTo(b.number));
      debugPrint('[PauloFlix] Found ${episodes.length} episodes');
      return episodes;
    } catch (e) {
      debugPrint('[PauloFlix] Error fetching episodes: $e');
      throw Exception('Error fetching PauloFlix episodes: $e');
    }
  }

  static int? _extractSeasonNumber(String name) {
    // Padrão 1: "Season 01", "Season 1" (formato completo)
    final seasonMatch = RegExp(
      r'Season\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(name);
    if (seasonMatch != null) return int.tryParse(seasonMatch.group(1)!);

    // Padrão 2: "S01", "S1" (abreviação comum)
    // Cuida de "S01 - East Blue", "S01E01", "S01_Arco_X", etc.
    final sMatch = RegExp(r'\bS(\d+)\b').firstMatch(name);
    if (sMatch != null) return int.tryParse(sMatch.group(1)!);

    // Padrão 3: "Temporada 01" (português)
    final ptMatch = RegExp(
      r'Temporada\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(name);
    if (ptMatch != null) return int.tryParse(ptMatch.group(1)!);

    return null;
  }

  static _EpisodeInfo? _extractEpisodeInfo(String filename) {
    final match = RegExp(
      r'S\d+E(\d+)(?:\s*-\s*(.+))?\.(mkv|mp4|avi|webm|mov|flv|wmv|m4v)$',
      caseSensitive: false,
    ).firstMatch(filename);
    if (match != null) {
      final number = int.tryParse(match.group(1)!);
      final title = match.group(2)?.trim() ?? 'Episode ${match.group(1)}';
      if (number != null) return _EpisodeInfo(number: number, title: title);
    }
    final simpleMatch = RegExp(r'E(\d+)').firstMatch(filename);
    if (simpleMatch != null) {
      final number = int.tryParse(simpleMatch.group(1)!);
      if (number != null) {
        // Remove any video extension from title
        var title = filename;
        for (final ext in videoExtensions) {
          title = title.replaceAll(ext, '');
        }
        return _EpisodeInfo(number: number, title: title);
      }
    }
    return null;
  }

  static Future<bool> syncContent({
    required PauloFlixRepository repository,
    void Function(String progress)? onProgress,
    void Function(String error)? onError,

    /// Callback chamado **após** cada show ser salvo no banco.
    /// Usado pelo `PauloFlixProvider` para disparar o sync de
    /// seasons/episodes do show imediatamente após ele existir no banco
    /// (evita uma segunda passada por show no final).
    ///
    /// [PauloFlixContent.id] é guaranteed non-null no callback (o show
    /// acabou de ser inserido com id auto-gerado).
    Future<void> Function(PauloFlixContent content)? onContentSynced,

    /// Opcional (Fase 2) — quando fornecido, **também** sincroniza
    /// seasons/episodes de shows novos ou que mudaram de pasta.
    /// Usado pelo `PauloFlixProvider.syncContent` que tem o
    /// `PauloFlixEpisodeSyncService` injetado.
    PauloFlixEpisodeProgressRepository? episodeRepository,
  }) async {
    try {
      onProgress?.call('Buscando shows do PauloFlix...');
      final shows = await fetchAllShows();
      if (shows.isEmpty) {
        onError?.call('Nenhum show encontrado no PauloFlix');
        return false;
      }

      final existingContent = await repository.getAll();
      final result = await _computeShowsToProcess(shows, existingContent);

      if (result.removedFolderNames.isNotEmpty) {
        onProgress?.call(
          'Marcando ${result.removedFolderNames.length} shows removidos...',
        );
      }

      if (result.showsToProcess.isEmpty) {
        onProgress?.call(
          'Sincronizacao completa: ${existingContent.length} shows',
        );
        await _finishSync(repository, result.removedFolderNames);
        return true;
      }

      final contents = await _enrichShowsWithJikan(
        result.showsToProcess,
        onProgress,
      );

      onProgress?.call(
        'Salvando ${contents.length} items no banco de dados...',
      );
      await repository.saveBatch(contents);

      // Relê o batch inserido para obter os ids reais (autoincrement).
      // Para cada show, dispara o callback onContentSynced (que pode
      // acionar o sync de seasons/episodes, se o caller passar
      // episodeRepository). O callback é chamado **sequencialmente** para
      // não martelar o servidor com requests paralelas.
      if (onContentSynced != null) {
        final saved = await _loadSavedContentsWithIds(
          repository,
          contents.map((c) => c.folderName).toList(),
        );
        var i = 0;
        for (final c in saved) {
          i++;
          onProgress?.call(
            'Sincronizando seasons/episodes $i/${saved.length} (${c.displayName})...',
          );
          try {
            await onContentSynced(c);
          } catch (e) {
            debugPrint(
              '[PauloFlix] Erro no sync de seasons/episodes '
              'de ${c.displayName}: $e',
            );
            // Continua com os outros shows.
          }
        }
      }

      await _finishSync(repository, result.removedFolderNames);

      final totalAvailable =
          existingContent.length -
          result.removedFolderNames.length +
          result.showsToProcess.length;
      onProgress?.call('Sincronizacao completa: $totalAvailable shows');
      return true;
    } catch (e) {
      debugPrint('[PauloFlix] Sync error: $e');
      onError?.call('Erro na sincronizacao: $e');
      return false;
    }
  }

  /// Relê do banco os `PauloFlixContent` pelos folderNames recém
  /// inseridos, retornando-os com `id` preenchido.
  ///
  /// Necessário porque `saveBatch` não retorna os ids gerados pelo
  /// autoincrement. 1 query batch (1 round-trip ao banco) em vez de N.
  static Future<List<PauloFlixContent>> _loadSavedContentsWithIds(
    PauloFlixRepository repository,
    List<String> folderNames,
  ) async {
    final all = await repository.getAll();
    final byFolder = {for (final c in all) c.folderName: c};
    return [
      for (final name in folderNames)
        if (byFolder.containsKey(name)) byFolder[name]!,
    ];
  }

  static Future<_ComputeResult> _computeShowsToProcess(
    List<PauloFlixShow> shows,
    List<PauloFlixContent> existingContent,
  ) async {
    final existingFolderNames = existingContent
        .map((c) => c.folderName)
        .toSet();
    final currentFolderNames = shows.map((s) => s.name).toSet();

    final removedFolderNames = existingFolderNames.difference(
      currentFolderNames,
    );

    final staleThreshold = DateTime.now().subtract(reEnrichThreshold);

    final newShows = shows
        .where((s) => !existingFolderNames.contains(s.name))
        .toList();
    final needsUpdate = existingContent
        .where(
          (c) =>
              currentFolderNames.contains(c.folderName) &&
              (_isIncomplete(c) || c.lastSynced.isBefore(staleThreshold)),
        )
        .toList();

    final showsToProcess = [...newShows];
    for (final content in needsUpdate) {
      final match = shows.where((s) => s.name == content.folderName);
      if (match.isNotEmpty) {
        final show = match.first;
        if (!showsToProcess.any((s) => s.name == show.name)) {
          showsToProcess.add(show);
        }
      }
    }
    return _ComputeResult(
      showsToProcess: showsToProcess,
      removedFolderNames: removedFolderNames.toList(),
    );
  }

  static Future<List<PauloFlixContent>> _enrichShowsWithJikan(
    List<PauloFlixShow> shows,
    void Function(String progress)? onProgress,
  ) async {
    final total = shows.length;
    final jikanService = JikanService();
    final List<PauloFlixContent> contents = [];
    const batchSize = 3;

    for (int i = 0; i < shows.length; i += batchSize) {
      final batch = shows.skip(i).take(batchSize).toList();
      final processed = i + batch.length;

      onProgress?.call(
        'Processando $processed/$total (batch de ${batch.length})',
      );

      final batchResults = await Future.wait(
        batch.map((show) => _enrichSingleShow(show, jikanService)),
      );

      contents.addAll(batchResults);

      if (processed < total) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return contents;
  }

  static Future<PauloFlixContent> _enrichSingleShow(
    PauloFlixShow show,
    JikanService jikanService,
  ) async {
    try {
      final searchResults = await jikanService.searchAnimes(
        show.name,
        limit: 5,
      );
      JikanAnime? matchedAnime;
      if (searchResults.isNotEmpty) {
        matchedAnime = searchResults
            .where((a) => a.title.toLowerCase() == show.name.toLowerCase())
            .firstOrNull;
        matchedAnime ??= searchResults.first;
      }
      if (matchedAnime != null) {
        return PauloFlixContent.fromJikan(
          folderName: show.name,
          serverUrl: show.url,
          jikanAnime: matchedAnime,
        );
      }
    } catch (e) {
      debugPrint('[PauloFlix] Error processing ${show.name}: $e');
    }
    return PauloFlixContent(
      folderName: show.name,
      serverUrl: show.url,
      displayName: show.name,
    );
  }

  static Future<void> _finishSync(
    PauloFlixRepository repository,
    List<String> removedFolderNames,
  ) async {
    for (final folderName in removedFolderNames) {
      await repository.markAsUnavailable(folderName);
    }
    // removeStaleContent não tem equivalente exato no repository; o
    // markAsUnavailable já é suficiente (a migração v1→v3 cobre legados).
  }

  /// Um conteúdo PauloFlix é considerado "incompleto" quando falta um
  /// dos dois metadados essenciais para exibição: `imageUrl` (card/hero)
  /// ou `malId` (vínculo com Jikan/AniList). Shows incompletos são
  /// re-enriquecidos em todo `syncContent`, independente do TTL de 7
  /// dias, para que o Jikan tenha novas chances de preencher o que
  /// faltou em tentativas anteriores (anime obscure, rate limit etc.).
  static bool _isIncomplete(PauloFlixContent content) {
    final imageMissing = content.imageUrl == null || content.imageUrl!.isEmpty;
    final malIdMissing = content.malId == null;
    return imageMissing || malIdMissing;
  }
}

class _EpisodeInfo {
  final int number;
  final String title;
  const _EpisodeInfo({required this.number, required this.title});
}

class _ComputeResult {
  final List<PauloFlixShow> showsToProcess;
  final List<String> removedFolderNames;
  const _ComputeResult({
    required this.showsToProcess,
    required this.removedFolderNames,
  });
}
