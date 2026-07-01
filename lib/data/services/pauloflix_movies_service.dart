import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/logger/app_logger.dart';
import '../../domain/models/pauloflix_movie.dart';
import '../../domain/repositories/pauloflix_movies_repository.dart';

/// Sincroniza o catálogo do PauloFlix Movies a partir do JSON index
/// (`movie_index.json`).
///
/// ## Como funciona
///
/// O JSON index contém todos os metadados dos filmes (título, ano,
/// descrição, poster, fanart, gêneros, rating, URL do vídeo, legendas).
class PauloFlixMoviesService {
  static const String baseUrl = ApiConstants.moviePauloFlix;
  static const String indexUrl = ApiConstants.movieIndexUrl;

  /// Chave SharedPreferences para armazenar o `updated_at` do último
  /// JSON index de filmes baixado.
  static const String _lastUpdatedAtKey = 'last_movie_index_updated_at';

  /// Host base — centralizado em [ApiConstants.mediaBaseHost].
  static String get _baseHost => ApiConstants.mediaBaseHost;

  /// HTTP client injetável (default: `http.Client()`, injetado por
  /// [configure] com `AuthenticatedHttpClient`).
  static http.Client _httpClient = http.Client();

  /// Injeta o HTTP client. Chamar UMA vez no `app.dart`.
  static void configure(http.Client client) {
    _httpClient = client;
  }

  // ---------------- Sincronização (JSON index) ----------------

  /// Sincroniza todo o conteúdo do PauloFlix Movies a partir do JSON
  /// index do servidor (`movie_index.json`).
  ///
  /// ## Diferenças do sync legado (HTML scraping + TMDB)
  ///
  /// - **Sem scraping HTML:** o JSON index contém todos os metadados
  ///   (título, ano, descrição, poster, fanart, gêneros, rating, etc.),
  ///   incluindo URL direta do vídeo (`file`) e legendas (`subtitles`).
  /// - **Sem API externa (TMDB):** toda a informação vem do JSON,
  ///   eliminando chamadas HTTP externas e rate limiting.
  /// - **Sem TTL:** o JSON é fonte da verdade — cada sync processa
  ///   todos os filmes e atualiza o banco via `DoUpdate` (UPSERT real).
  /// - **Verificação de `updated_at`:** antes de processar, compara o
  ///   campo `updated_at` do JSON com o último valor salvo em
  ///   SharedPreferences. Se igual, pula o processamento.
  ///
  /// [enricher] e o fluxo TMDB são mantidos apenas para compatibilidade
  /// de assinatura — são **ignorados** neste sync.
  static Future<bool> syncContent({
    required PauloFlixMoviesRepository repository,
    void Function(String progress)? onProgress,
    void Function(String error)? onError,
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

      // ─── Verificação rápida de updated_at ───────────────────────
      final serverUpdatedAt = data['updated_at'] as String?;
      if (serverUpdatedAt != null) {
        final prefs = await SharedPreferences.getInstance();
        final lastUpdatedAt = prefs.getString(_lastUpdatedAtKey);
        if (serverUpdatedAt == lastUpdatedAt) {
          const AppLogger(
            'PauloFlixMoviesService',
          ).debug('Índice não mudou desde a última sync — pulando.');
          return true;
        }
      }

      final moviesJson = data['movies'] as List<dynamic>?;
      if (moviesJson == null || moviesJson.isEmpty) {
        onError?.call('Nenhum filme encontrado no índice JSON');
        return false;
      }

      onProgress?.call('Índice baixado: ${moviesJson.length} filmes');

      // Converte todos os filmes do JSON para PauloFlixMovie
      final List<PauloFlixMovie> contents = [];
      for (final movieJson in moviesJson) {
        final json = movieJson as Map<String, dynamic>;
        contents.add(
          PauloFlixMovie.fromMovieIndex(json: json, baseHost: _baseHost),
        );
      }

      // Busca filmes existentes no banco
      final existingContent = await repository.getAll();
      final existingPaths = existingContent.map((c) => c.folderName).toSet();
      final currentPaths = contents.map((c) => c.folderName).toSet();

      // Filmes que sumiram do servidor
      final removedPaths = existingPaths.difference(currentPaths);

      if (removedPaths.isNotEmpty) {
        onProgress?.call('Marcando ${removedPaths.length} filmes removidos...');
      }

      // Salva todos os filmes (DoUpdate lida com conflitos)
      onProgress?.call('Salvando ${contents.length} filmes no banco...');
      await repository.saveBatch(contents);

      // Marca filmes removidos
      for (final path in removedPaths) {
        await repository.markAsUnavailable(path);
      }

      final totalAvailable = existingContent.length - removedPaths.length;

      // Salva o updated_at para pular syncs futuros se nada mudou.
      if (serverUpdatedAt != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastUpdatedAtKey, serverUpdatedAt);
      }

      onProgress?.call('Sincronização completa: $totalAvailable filmes');
      return true;
    } catch (e, st) {
      const AppLogger('PauloFlixMoviesService').error('syncContent error', e, st);
      onError?.call('Erro na sincronização: $e');
      return false;
    }
  }
}
