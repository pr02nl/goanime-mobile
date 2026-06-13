// PauloFlix Service
//
// Service to interact with PauloFlix file server.
// PauloFlix is a simple file server with HTML directory listings at:
// http://100.95.105.113:8300/tvshows/
//
// Structure:
// - /tvshows/ - List of all shows
// - /tvshows/{ShowName}/ - List of seasons
// - /tvshows/{ShowName}/Season {XX}/ - List of episodes (MKV files)

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/jikan_models.dart';
import '../models/pauloflix_content.dart';
import '../models/pauloflix_models.dart';
import 'jikan_service.dart';
import 'pauloflix_database_service.dart';

class PauloFlixService {
  static const String baseUrl = 'http://100.95.105.113:8300/tvshows/';

  /// Fetches all available TV shows from PauloFlix
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

      List<PauloFlixShow> shows = [];
      for (var element in linkElements) {
        final href = element.attributes['href'] ?? '';
        final name = element.text.trim();

        // Skip parent directory link and empty entries
        if (href == '../' || href.isEmpty || name.isEmpty || name == '../') {
          continue;
        }

        // Only include directory links (ending with /)
        if (!href.endsWith('/')) {
          continue;
        }

        // Decode URL-encoded name (e.g., "Demon%20Slayer" -> "Demon Slayer")
        final decodedName = Uri.decodeComponent(
          name.endsWith('/') ? name.substring(0, name.length - 1) : name,
        );

        // Build absolute URL
        final absoluteUrl = '$baseUrl${Uri.encodeComponent(decodedName)}/';

        shows.add(PauloFlixShow(
          name: decodedName,
          url: absoluteUrl,
        ));

        debugPrint('[PauloFlix] Found show: $decodedName -> $absoluteUrl');
      }

      debugPrint('[PauloFlix] Found ${shows.length} shows');
      return shows;
    } catch (e) {
      debugPrint('[PauloFlix] Error fetching shows: $e');
      throw Exception('Error fetching PauloFlix shows: $e');
    }
  }

  /// Fetches seasons for a given show
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

      List<PauloFlixSeason> seasons = [];
      for (var element in linkElements) {
        final href = element.attributes['href'] ?? '';
        final name = element.text.trim();

        // Skip parent directory link and empty entries
        if (href == '../' || href.isEmpty || name.isEmpty || name == '../') {
          continue;
        }

        // Only include directory links (ending with /)
        if (!href.endsWith('/')) {
          continue;
        }

        // Decode URL-encoded name
        final decodedName = Uri.decodeComponent(
          name.endsWith('/') ? name.substring(0, name.length - 1) : name,
        );

        // Try to extract season number from name like "Season 01"
        final seasonNumber = _extractSeasonNumber(decodedName);
        if (seasonNumber == null) {
          debugPrint('[PauloFlix] Skipping non-season entry: $decodedName');
          continue;
        }

        // Build absolute URL
        final absoluteUrl = '$showUrl${Uri.encodeComponent(decodedName)}/';

        seasons.add(PauloFlixSeason(
          name: decodedName,
          url: absoluteUrl,
          number: seasonNumber,
        ));

        debugPrint(
          '[PauloFlix] Found season: $decodedName (number: $seasonNumber)',
        );
      }

      // Sort seasons by number
      seasons.sort((a, b) => a.number.compareTo(b.number));

      debugPrint('[PauloFlix] Found ${seasons.length} seasons');
      return seasons;
    } catch (e) {
      debugPrint('[PauloFlix] Error fetching seasons: $e');
      throw Exception('Error fetching PauloFlix seasons: $e');
    }
  }

  /// Fetches episodes for a given season
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

      List<PauloFlixEpisode> episodes = [];
      for (var element in linkElements) {
        final href = element.attributes['href'] ?? '';
        final name = element.text.trim();

        // Skip parent directory link and empty entries
        if (href == '../' || href.isEmpty || name.isEmpty || name == '../') {
          continue;
        }

        // Only include .mkv files
        if (!name.toLowerCase().endsWith('.mkv')) {
          continue;
        }

        // Extract episode number from filename like "S01E01.mkv"
        final episodeInfo = _extractEpisodeInfo(name);
        if (episodeInfo == null) {
          debugPrint('[PauloFlix] Skipping non-standard episode: $name');
          continue;
        }

        // Build absolute URL
        final absoluteUrl = '$seasonUrl${Uri.encodeComponent(name)}';

        episodes.add(PauloFlixEpisode(
          number: episodeInfo.number,
          title: episodeInfo.title,
          url: absoluteUrl,
          fileSize: null, // File size not available from directory listing
        ));

        debugPrint(
          '[PauloFlix] Found episode: ${episodeInfo.title} -> $absoluteUrl',
        );
      }

      // Sort episodes by number
      episodes.sort((a, b) => a.number.compareTo(b.number));

      debugPrint('[PauloFlix] Found ${episodes.length} episodes');
      return episodes;
    } catch (e) {
      debugPrint('[PauloFlix] Error fetching episodes: $e');
      throw Exception('Error fetching PauloFlix episodes: $e');
    }
  }

  /// Extracts season number from a name like "Season 01"
  static int? _extractSeasonNumber(String name) {
    final match = RegExp(r'Season\s+(\d+)').firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Extracts episode information from filename like "S01E01.mkv"
  static _EpisodeInfo? _extractEpisodeInfo(String filename) {
    // Pattern: S01E01.mkv or S01E01 - Title.mkv
    final match = RegExp(
      r'S\d+E(\d+)(?:\s*-\s*(.+))?\.mkv$',
      caseSensitive: false,
    ).firstMatch(filename);

    if (match != null) {
      final number = int.tryParse(match.group(1)!);
      final title = match.group(2)?.trim() ?? 'Episode ${match.group(1)}';

      if (number != null) {
        return _EpisodeInfo(number: number, title: title);
      }
    }

    // Fallback: try to find just episode number
    final simpleMatch = RegExp(r'E(\d+)').firstMatch(filename);
    if (simpleMatch != null) {
      final number = int.tryParse(simpleMatch.group(1)!);
      if (number != null) {
        return _EpisodeInfo(
          number: number,
          title: filename.replaceAll('.mkv', ''),
        );
      }
    }

    return null;
  }
  /// Synchronizes PauloFlix content with metadata from Jikan and saves to local database.
  static Future<bool> syncContent({
    void Function(String progress)? onProgress,
    void Function(String error)? onError,
  }) async {
    try {
      onProgress?.call('Buscando shows do PauloFlix...');
      final shows = await fetchAllShows();

      if (shows.isEmpty) {
        onError?.call('Nenhum show encontrado no PauloFlix');
        return false;
      }

      onProgress?.call('Encontrados ${shows.length} shows. Buscando metadados...');

      final dbService = PauloFlixDatabaseService();
      final jikanService = JikanService();
      final List<PauloFlixContent> contents = [];
      int processed = 0;

      for (final show in shows) {
        processed++;
        onProgress?.call('Processando ${show.name} ($processed/${shows.length})');

        try {
          // Search Jikan for metadata
          final searchResults = await jikanService.searchAnimes(show.name, limit: 5);

          // Try to find best match
          JikanAnime? matchedAnime;
          if (searchResults.isNotEmpty) {
            // Exact match first
            matchedAnime = searchResults.where((a) =>
              a.title.toLowerCase() == show.name.toLowerCase()
            ).firstOrNull;

            // Fallback to first result if no exact match
            matchedAnime ??= searchResults.first;
          }

          if (matchedAnime != null) {
            contents.add(PauloFlixContent.fromJikan(
              folderName: show.name,
              serverUrl: show.url,
              jikanAnime: matchedAnime,
            ));
          } else {
            // No metadata found, create basic entry
            contents.add(PauloFlixContent(
              folderName: show.name,
              displayName: show.name,
              serverUrl: show.url,
            ));
          }
        } catch (e) {
          debugPrint('[PauloFlix] Error processing ${show.name}: $e');
          // Still add the show without metadata
          contents.add(PauloFlixContent(
            folderName: show.name,
            displayName: show.name,
            serverUrl: show.url,
          ));
        }

        // Rate limiting for Jikan API
        if (processed % 3 == 0) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      onProgress?.call('Salvando ${contents.length} items no banco de dados...');
      await dbService.saveBatch(contents);

      onProgress?.call('Sincronização completa: ${contents.length} shows');
      return true;
    } catch (e) {
      debugPrint('[PauloFlix] Sync error: $e');
      onError?.call('Erro na sincronização: $e');
      return false;
    }
  }
}

/// Helper class for episode information extraction
class _EpisodeInfo {
  final int number;
  final String title;

  const _EpisodeInfo({required this.number, required this.title});
}
