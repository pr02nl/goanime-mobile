import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/url_codec.dart';
import '../../domain/models/pauloflix_content.dart';
import '../../domain/models/pauloflix_models.dart';
import '../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import '../../domain/repositories/pauloflix_repository.dart';

class PauloFlixService {
  static const String baseUrl = ApiConstants.animePauloFlix;
  static const String indexUrl = ApiConstants.tvIndexUrl;

  /// Chave SharedPreferences para armazenar o `updated_at` do último
  /// JSON index baixado. Se o servidor retornar o mesmo valor, o sync
  /// é pulado (evita processamento desnecessário do lado do cliente).
  static const String _lastUpdatedAtKey = 'last_tv_index_updated_at';

  /// Host base — centralizado em [ApiConstants.mediaBaseHost].
  static String get _baseHost => ApiConstants.mediaBaseHost;

  /// HTTP client usado pelas chamadas estáticas.
  /// Inicializado por [configure] no startup do app com o
  /// `AuthenticatedHttpClient` (que injeta `Authorization: Bearer *** JWT).
  /// Default: `http.Client()` (sem auth) — usado em testes e como fallback.
  static http.Client _httpClient = http.Client();

  /// Injeta o HTTP client. Chamar UMA vez no `app.dart` antes do primeiro
  /// sync. Em testes, pode injetar um `MockClient`.
  static void configure(http.Client client) {
    _httpClient = client;
  }

  /// Busca temporadas de um show via scraping HTML da pasta do show.
  /// Mantido para a tela de episódios (chamada on-demand pelo
  /// `PauloFlixEpisodeListViewModel`).
  static Future<List<PauloFlixSeason>> fetchShowSeasons(String showUrl) async {
    try {
      debugPrint('[PauloFlix] Fetching seasons from $showUrl');
      final response = await _httpClient
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
        final decodedName = safeDecodeComponent(rawName);
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

  /// Busca episódios de uma temporada via scraping HTML da pasta.
  /// Mantido para a tela de episódios (chamada on-demand pelo
  /// `PauloFlixEpisodeListViewModel`).
  static Future<List<PauloFlixEpisode>> fetchSeasonEpisodes(
    String seasonUrl,
  ) async {
    try {
      debugPrint('[PauloFlix] Fetching episodes from $seasonUrl');
      final response = await _httpClient
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
        final decodedName = safeDecodeComponent(href);
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
    final seasonMatch = RegExp(
      r'Season\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(name);
    if (seasonMatch != null) return int.tryParse(seasonMatch.group(1)!);

    final sMatch = RegExp(r'\bS(\d+)\b').firstMatch(name);
    if (sMatch != null) return int.tryParse(sMatch.group(1)!);

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
        var title = filename;
        for (final ext in videoExtensions) {
          title = title.replaceAll(ext, '');
        }
        return _EpisodeInfo(number: number, title: title);
      }
    }
    return null;
  }

  /// Sincroniza todo o conteúdo do PauloFlix TV a partir do JSON index
  /// do servidor (`tv_index.json`).
  ///
  /// ## Diferenças do sync legado (HTML scraping + Jikan)
  ///
  /// - **Sem scraping HTML:** lê um JSON index que já contém todos os
  ///   metadados (título, descrição, poster, fanart, seasons/episódios).
  /// - **Sem API externa (Jikan):** toda a informação vem do JSON,
  ///   eliminando chamadas HTTP externas e rate limiting.
  /// - **Sem TTL:** o JSON é fonte da verdade — cada sync processa
  ///   todos os shows e atualiza o banco via `DoUpdate` (UPSERT real).
  /// - **Sync de episódios integrado:** quando [episodeRepository] é
  ///   fornecido, o sync popula seasons/episódios diretamente do JSON,
  ///   sem scraping adicional.
  /// - **Verificação de `updated_at`:** antes de processar, compara o
  ///   campo `updated_at` do JSON com o último valor salvo em
  ///   SharedPreferences. Se igual, pula o processamento (economiza
  ///   CPU e banda em aberturas frequentes do app).
  static Future<bool> syncContent({
    required PauloFlixRepository repository,
    void Function(String progress)? onProgress,
    void Function(String error)? onError,

    /// Mantido para compatibilidade de assinatura, mas **ignorado**
    /// — o JSON index substituiu o scraped-based sync.
    // ignore: avoid_unused_constructor_parameters
    Future<void> Function(PauloFlixContent content)? onContentSynced,

    /// Quando fornecido, popula seasons/episódios diretamente do JSON
    /// index, sem necessidade de scraping adicional.
    PauloFlixEpisodeProgressRepository? episodeRepository,
  }) async {
    try {
      onProgress?.call('Baixando índice JSON do PauloFlix TV...');
      final response = await _httpClient
          .get(Uri.parse(indexUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        onError?.call('Erro ao baixar índice: HTTP ${response.statusCode}');
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      // ─── Verificação rápida de updated_at ───────────────────────
      final serverUpdatedAt = data['updated_at'] as String?;
      if (serverUpdatedAt != null) {
        final prefs = await SharedPreferences.getInstance();
        final lastUpdatedAt = prefs.getString(_lastUpdatedAtKey);
        if (serverUpdatedAt == lastUpdatedAt) {
          debugPrint(
            '[PauloFlix] Índice não mudou desde a última sync — pulando.',
          );
          return true;
        }
      }

      final List<dynamic> showsJson = data['shows'] as List<dynamic>;

      if (showsJson.isEmpty) {
        onError?.call('Nenhum show encontrado no índice JSON');
        return false;
      }

      onProgress?.call('Índice baixado: ${showsJson.length} shows');

      // Converte todos os shows do JSON para PauloFlixContent
      final List<PauloFlixContent> contents = [];
      final Map<String, Map<String, dynamic>> showJsonByPath = {};

      for (final showJson in showsJson) {
        final json = showJson as Map<String, dynamic>;
        final content = PauloFlixContent.fromTvIndex(
          json: json,
          baseHost: _baseHost,
        );
        contents.add(content);
        showJsonByPath[json['path'] as String] = json;
      }

      // Busca shows existentes no banco
      final existingContent = await repository.getAll();
      final existingPaths = existingContent.map((c) => c.folderName).toSet();
      final currentPaths = contents.map((c) => c.folderName).toSet();

      // Shows que sumiram do servidor
      final removedPaths = existingPaths.difference(currentPaths);

      if (removedPaths.isNotEmpty) {
        onProgress?.call('Marcando ${removedPaths.length} shows removidos...');
      }

      // Salva todos os shows (DoUpdate lida com conflitos)
      onProgress?.call('Salvando ${contents.length} shows no banco...');
      await repository.saveBatch(contents);

      // Se temos repositório de episódios, popula seasons/episódios do JSON
      if (episodeRepository != null) {
        final saved = await _loadSavedContentsWithIds(
          repository,
          contents.map((c) => c.folderName).toList(),
        );

        for (final content in saved) {
          final json = showJsonByPath[content.folderName];
          if (json == null) continue;

          final seasonsJson = json['seasons'] as List<dynamic>?;
          if (seasonsJson == null || seasonsJson.isEmpty) continue;

          onProgress?.call(
            'Sincronizando episódios de ${content.displayName}...',
          );

          for (final seasonJson in seasonsJson) {
            final seasonData = seasonJson as Map<String, dynamic>;
            final seasonNumber = seasonData['season'] as int;
            final folderName =
                seasonData['folderName'] as String? ?? 'Season $seasonNumber';
            final displayName = folderName;

            final seasonId = await episodeRepository.upsertSeason(
              contentId: content.id!,
              seasonNumber: seasonNumber,
              displayName: displayName,
              folderName: folderName,
            );

            final episodesJson = seasonData['episodes'] as List<dynamic>?;
            if (episodesJson == null || episodesJson.isEmpty) continue;

            for (final episodeJson in episodesJson) {
              final ep = episodeJson as Map<String, dynamic>;
              final episodeNumber = ep['episode'] as int;
              final episodeTitle =
                  (ep['title'] as String?) ?? 'Episode $episodeNumber';
              final filePath = ep['file'] as String;
              final videoUrl = '$_baseHost$filePath';

              String? thumbnailUrl;
              if (ep['thumb'] != null) {
                thumbnailUrl = '$_baseHost${ep['thumb']}';
              }

              // NFO V2 fields extras
              final dynamic rawNfo = ep['nfo'];
              final Map<String, dynamic>? nfoJson = rawNfo is Map
                  ? Map<String, dynamic>.from(rawNfo)
                  : null;
              final int? runtime;
              if (nfoJson?['runtime'] != null) {
                runtime = int.tryParse(nfoJson!['runtime'].toString());
              } else {
                runtime = null;
              }

              await episodeRepository.upsertEpisode(
                seasonId: seasonId,
                episodeNumber: episodeNumber,
                title: episodeTitle,
                videoUrl: videoUrl,
                thumbnailUrl: thumbnailUrl,
                description: ep['plot'] as String?,
                originalTitle: nfoJson?['originaltitle'] as String?,
                outline: nfoJson?['outline'] as String?,
                aired: ep['aired'] != null
                    ? DateTime.tryParse(ep['aired'] as String)
                    : null,
                rating: ep['rating'] is num
                    ? (ep['rating'] as num).toDouble()
                    : double.tryParse(ep['rating'] as String? ?? ''),
                runtime: runtime,
              );
            }
          }
        }
      }

      // Dispara callback onContentSynced (se caller ainda quiser)
      if (onContentSynced != null) {
        final saved = await _loadSavedContentsWithIds(
          repository,
          contents.map((c) => c.folderName).toList(),
        );
        for (final c in saved) {
          await onContentSynced(c);
        }
      }

      // Marca shows removidos
      for (final path in removedPaths) {
        await repository.markAsUnavailable(path);
      }

      final totalAvailable = existingContent.length - removedPaths.length;

      // Salva o updated_at para pular syncs futuros se nada mudou.
      if (serverUpdatedAt != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastUpdatedAtKey, serverUpdatedAt);
      }

      onProgress?.call('Sincronização completa: $totalAvailable shows');
      return true;
    } catch (e) {
      debugPrint('[PauloFlix] Sync error: $e');
      onError?.call('Erro na sincronização: $e');
      return false;
    }
  }

  /// Relê do banco os `PauloFlixContent` pelos folderNames recém
  /// inseridos, retornando-os com `id` preenchido.
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
}

/// Informação de episódio extraída do nome do arquivo pelo
/// [PauloFlixService._extractEpisodeInfo].
class _EpisodeInfo {
  final int number;
  final String title;
  const _EpisodeInfo({required this.number, required this.title});
}
