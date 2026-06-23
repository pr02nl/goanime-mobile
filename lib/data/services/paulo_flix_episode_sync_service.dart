import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/database/app_database.dart' hide PauloFlixSeason, PauloFlixEpisode;
import '../../core/utils/episode_utils.dart';
import '../../data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import '../../domain/models/pauloflix_models.dart';
import '../../domain/repositories/paulo_flix_episode_progress_repository.dart';

/// Service de sincronização on-demand de seasons + episodes PauloFlix.
///
/// **Fase 1.4 do plano**
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`.
///
/// Por que existe um service separado (não no `PauloFlixService`)?
/// - **SRP**: `PauloFlixService` é o **scraper de shows** (Fase 0 da
///   refatoração). Este service é o **sync de episodes** (Fase 1) —
///   concerns diferentes, ciclos de vida diferentes.
/// - **Testabilidade**: HTTP injetado via `http.Client` (mesmo padrão
///   do `TmdbService` — `http.testing.MockClient`), sem depender dos
///   métodos `static` do `PauloFlixService` (que seriam impossíveis
///   de mockar).
/// - **Reuso mínimo**: parsing HTML é simples (listas `<a href="...">`)
///   e foi copiado do `PauloFlixService` por questão de isolamento.
///   Trade-off aceito: ~30 linhas duplicadas vs zero dependência do
///   legado estático.
///
/// Comportamento:
/// 1. `GET contentServerUrl` → parse HTML → extrai seasons.
/// 2. Para cada season: `GET seasonUrl` → parse HTML → extrai episodes.
/// 3. Chama `repo.upsertSeason` / `repo.upsertEpisode` (Fase 1.3).
/// 4. Atualiza `episodeCount` da season.
///
/// Lança exceção se a rede falhar em qualquer step. Caller decide se
/// mostra erro ou usa seasons/episodes já em cache do banco.
class PauloFlixEpisodeSyncService {
  final PauloFlixEpisodeProgressRepository _repo;
  final http.Client _httpClient;

  /// Ctor de produção: usa `http.Client()` padrão + URL base do PauloFlix.
  PauloFlixEpisodeSyncService(this._repo, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Ctor alternativo: recebe `appDatabase` e constrói o repo internamente.
  ///
  /// **Por que existe:** evita a dependência circular em
  /// `app.dart` onde o `Provider<PauloFlixEpisodeSyncService>` é
  /// declarado no MESMO `MultiProvider` que
  /// `Provider<PauloFlixEpisodeProgressRepository>`. Ler o repo via
  /// `context.read<...>()` no `create:` callback lança
  /// `ProviderNotFoundException` (o context é ancestral do repo no
  /// mesmo MultiProvider).
  ///
  /// Em vez disso, este ctor constrói o repo lazy (o `appDatabase` já
  /// está disponível como field da `PauloFlixApp`). Use ESTE ctor
  /// no `MultiProvider`. O ctor `PauloFlixEpisodeSyncService(repo)`
  /// continua disponível para testes unitários (ver test/data/services/).
  factory PauloFlixEpisodeSyncService.fromDatabase(
    AppDatabase appDatabase, {
    http.Client? httpClient,
  }) {
    return PauloFlixEpisodeSyncService(
      PauloFlixEpisodeProgressRepositoryImpl(appDatabase),
      httpClient: httpClient,
    );
  }

  /// Extensões de vídeo reconhecidas (mesma lista do `PauloFlixService`).
  /// Duplicada aqui para isolar do legado.
  static const Set<String> _videoExtensions = {
    '.mkv',
    '.mp4',
    '.avi',
    '.webm',
    '.mov',
    '.flv',
    '.wmv',
    '.m4v',
  };

  /// Sincroniza seasons + episodes do servidor para o banco.
  ///
  /// [contentId] é o ID do `PauloFlixContent` (banco local).
  /// [contentServerUrl] é a URL do show no file server PauloFlix.
  Future<void> syncSeasonEpisodes({
    required int contentId,
    required String contentServerUrl,
  }) async {
    // 1. Fetch + parse seasons.
    final seasons = await _fetchSeasons(contentServerUrl);

    for (final s in seasons) {
      // 2. Upsert season (preserva `isCompleted` se já existir).
      final seasonId = await _repo.upsertSeason(
        contentId: contentId,
        seasonNumber: s.number,
        displayName: s.name,
        folderName: s.name,
      );

      // 3. Fetch + parse episodes desta season.
      final episodes = await _fetchEpisodes(s.url);

      // 4. Upsert cada episode (preserva `positionSeconds`/
      // `isCompleted`/`lastWatched`/`durationSeconds`).
      for (final e in episodes) {
        await _repo.upsertEpisode(
          seasonId: seasonId,
          episodeNumber: e.number,
          title: e.title,
          videoUrl: e.url,
        );
      }

      // 5. Atualiza `episodeCount` e `lastSynced` da season. **NÃO** é
      // feito pelo `upsertSeason` (que só atualiza displayName/folderName
      // se já existir) — o count é derivado do total scrapeado.
      await _updateSeasonCount(seasonId, episodes.length);

      debugPrint(
        '[PauloFlixSync] Content $contentId: '
        'season ${s.number} (${episodes.length} episodes) sincronizada',
      );
    }
  }

  /// Atualiza `episodeCount` + `lastSynced` da season. Chamado após
  /// o upsert dos episodes para persistir o total descoberto.
  ///
  /// NÃO sobrescreve `isCompleted` (preservado pelo repository).
  Future<void> _updateSeasonCount(int seasonId, int count) async {
    // Implementação inline usando o repo. Como o repo não expõe um
    // método `updateSeasonCount`, fazemos via um helper.
    // (Mantido aqui para manter o service self-contained.)
    await _repo.updateSeasonCount(seasonId, count);
  }

  // ─── HTTP + parsing ──────────────────────────────────────────────────

  /// GET show URL → parse HTML → lista de seasons.
  Future<List<PauloFlixSeason>> _fetchSeasons(String showUrl) async {
    final response = await _httpClient
        .get(Uri.parse(showUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'PauloFlixSync: GET $showUrl falhou (status ${response.statusCode})',
      );
    }
    final document = html_parser.parse(response.body);
    final linkElements = document.querySelectorAll('a[href]');
    final seasons = <PauloFlixSeason>[];
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
    return seasons;
  }

  /// GET season URL → parse HTML → lista de episodes.
  Future<List<PauloFlixEpisode>> _fetchEpisodes(String seasonUrl) async {
    final response = await _httpClient
        .get(Uri.parse(seasonUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
        'PauloFlixSync: GET $seasonUrl falhou (status ${response.statusCode})',
      );
    }
    final document = html_parser.parse(response.body);
    final linkElements = document.querySelectorAll('a[href]');
    final episodes = <PauloFlixEpisode>[];
    for (final element in linkElements) {
      final href = element.attributes['href'] ?? '';
      final text = element.text.trim();
      if (href == '../' || href.isEmpty || text.isEmpty || text == '../') {
        continue;
      }
      final lowerHref = href.toLowerCase();
      final hasVideoExtension =
          _videoExtensions.any((ext) => lowerHref.endsWith(ext));
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
    return episodes;
  }

  // ─── Parsing (cópia do PauloFlixService) ─────────────────────────────

  /// Extrai número da season do nome da pasta.
  /// Suporta "Season 01", "S01", "S01 - East Blue", "Temporada 1".
  int? _extractSeasonNumber(String name) {
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

  /// Extrai número + título do nome do arquivo de vídeo.
  /// Suporta "S01E01.mkv", "S01E01 - Naruto Returns.mkv", "ep1.mkv".
  _EpisodeInfo? _extractEpisodeInfo(String filename) {
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
        for (final ext in _videoExtensions) {
          title = title.replaceAll(ext, '');
        }
        return _EpisodeInfo(number: number, title: title);
      }
    }
    return null;
  }

  /// URL base do PauloFlix (re-exportada para consistência com outros
  /// services do projeto).
  static String get baseUrl => ApiConstants.animePauloFlix;
}

class _EpisodeInfo {
  final int number;
  final String title;
  const _EpisodeInfo({required this.number, required this.title});
}
