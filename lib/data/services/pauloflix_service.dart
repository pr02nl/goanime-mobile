import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/logger/app_logger.dart';
import '../../domain/models/pauloflix_content.dart';
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

  /// Sincroniza todo o conteúdo do PauloFlix TV a partir do JSON index
  /// do servidor (`tv_index.json`).
  ///
  /// ## Diferenças do sync legado (HTML scraping)
  ///
  /// - **Sem scraping HTML:** lê um JSON index que já contém todos os
  ///   metadados (título, descrição, poster, fanart, seasons/episódios).
  /// - **Sem API externa:** toda a informação vem do JSON,
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
          const AppLogger(
            'PauloFlixService',
          ).debug('Índice não mudou desde a última sync — pulando.');
          return true;
        }
      }

      final showsJson = data['shows'] as List<dynamic>?;
      if (showsJson == null || showsJson.isEmpty) {
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

      // Antes de salvar, constrói um mapa path→id dos dados já existentes.
      // Após o `saveBatch` com `DoUpdate`, itens já existentes mantêm seu
      // `id` original — apenas os novos precisam ser relidos.
      final existingIds = <String, int>{};
      for (final c in existingContent) {
        if (c.id != null) existingIds[c.folderName] = c.id!;
      }

      // Salva todos os shows (DoUpdate lida com conflitos)
      onProgress?.call('Salvando ${contents.length} shows no banco...');
      await repository.saveBatch(contents);

      // Busca IDs apenas para shows novos (não estavam em existingIds).
      final updatedIds = <String, int>{...existingIds};
      for (final path in currentPaths.difference(existingPaths)) {
        final found = await repository.getByFolderName(path);
        if (found?.id != null) updatedIds[path] = found!.id!;
      }

      // Se temos repositório de episódios, popula seasons/episódios do JSON
      if (episodeRepository != null) {
        for (final content in contents) {
          final contentId = updatedIds[content.folderName];
          if (contentId == null) continue;

          final json = showJsonByPath[content.folderName];
          if (json == null) continue;

          final seasonsJson = json['seasons'] as List<dynamic>?;
          if (seasonsJson == null || seasonsJson.isEmpty) continue;

          onProgress?.call(
            'Sincronizando episódios de ${content.displayName}...',
          );

          final scrapedSeasonNumbers = <int>{};
          // Mapa: seasonId (DB) → scraped episode numbers
          final scrapedEpisodeNumbersBySeason = <int, Set<int>>{};
          // Mapa: seasonId (DB) por seasonNumber (scraped)
          final seasonIdByNumber = <int, int>{};

          for (final seasonJson in seasonsJson) {
            final seasonData = seasonJson as Map<String, dynamic>;
            final seasonNumber = seasonData['season'] as int;
            scrapedSeasonNumbers.add(seasonNumber);
            final folderName =
                seasonData['folderName'] as String? ?? 'Season $seasonNumber';
            final displayName = folderName;

            final seasonId = await episodeRepository.upsertSeason(
              contentId: contentId,
              seasonNumber: seasonNumber,
              displayName: displayName,
              folderName: folderName,
            );
            seasonIdByNumber[seasonNumber] = seasonId;

            final episodesJson = seasonData['episodes'] as List<dynamic>?;
            if (episodesJson == null || episodesJson.isEmpty) {
              scrapedEpisodeNumbersBySeason[seasonId] = <int>{};
              continue;
            }

            final scrapedEpNumbers = <int>{};
            for (final episodeJson in episodesJson) {
              final ep = episodeJson as Map<String, dynamic>;
              final episodeNumber = ep['episode'] as int;
              scrapedEpNumbers.add(episodeNumber);
              final episodeTitle =
                  (ep['title'] as String?) ?? 'Episode $episodeNumber';
              final filePath = ep['file'] as String;
              final videoUrl = '$_baseHost$filePath';

              String? thumbnailUrl;
              if (ep['thumb'] != null) {
                thumbnailUrl = '$_baseHost${ep['thumb']}';
              }

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
                contentId: contentId,
                seasonNumber: seasonNumber,
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
            scrapedEpisodeNumbersBySeason[seasonId] = scrapedEpNumbers;
          }

          // Remove seasons que sumiram do índice
          final removedSeasons = await episodeRepository.removeMissingSeasons(
            contentId: contentId,
            scrapedSeasonNumbers: scrapedSeasonNumbers,
          );

          // Remove episódios que sumiram de cada season (exceto seasons
          // que já foram removidas acima — cascade cuida delas).
          for (final entry in scrapedEpisodeNumbersBySeason.entries) {
            if (removedSeasons.contains(entry.key)) continue;
            await episodeRepository.removeMissingEpisodes(
              seasonId: entry.key,
              scrapedEpisodeNumbers: entry.value,
            );
          }
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
    } catch (e, st) {
      const AppLogger('PauloFlixService').error('Sync error', e, st);
      onError?.call('Erro na sincronização: $e');
      return false;
    }
  }
}
