import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
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

  /// Host base sem path — usado para resolver paths relativos do JSON.
  static const String _baseHost = 'https://media.oliveira.braga.nom.br';

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
      onProgress?.call('Sincronização completa: $totalAvailable filmes');
      return true;
    } catch (e) {
      debugPrint('[PauloFlix Movies] syncContent error: $e');
      onError?.call('Erro na sincronização: $e');
      return false;
    }
  }
}
