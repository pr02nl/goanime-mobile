import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/database/app_database.dart' hide PauloFlixSeason, PauloFlixEpisode;
import '../../core/utils/url_codec.dart';
import '../../data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import '../../domain/models/pauloflix_models.dart';
import '../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'kodi/pauloflix_nfo_enricher.dart';

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
/// **Fase 2:** o método [reconcileSeasonEpisodes] estende o sync com
/// deleção de seasons/episodes que sumiram do servidor (com guarda de
/// progresso — só remove o que o usuário não assistiu).
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
  /// [enricher] é o injetor opcional de `PauloFlixNfoEnricher`. Quando
  /// fornecido, o sync busca:
  /// 1. `season.nfo` (Fase 10) → popula `description` da season.
  /// 2. `S01E{nnn}.nfo` em batch (Fase 10) → popula `description` do
  ///    episode.
  /// 3. `S\d+E\d+-thumb.{ext}` do listing (Fase 5) → popula
  ///    `thumbnailUrl` do episode.
  ///
  /// Quando `null` (default), o sync preserva o comportamento legado —
  /// sem chamada extra de HTTP (back-compat com testes e callers que
  /// não injetam enricher).
  ///
  /// **Comportamento:**
  /// 1. Fetch + parse seasons (HTTP).
  /// 2. Para cada season scrapeada:
  ///    a. (Fase 10) GET `season.nfo` → `seasonDescription` (se enricher).
  ///    b. Upsert season (preserva `isCompleted`).
  ///    c. (Fase 10) GET listing + N NFOs paralelos → `episodeDescriptions`
  ///       (se enricher).
  ///    d. (Fase 5) Fetch episode thumbs via enricher.
  ///    e. Fetch + parse episodes da season (HTTP).
  ///    f. Upsert cada episode com `thumbnailUrl` + `description`
  ///       (preserva progresso do user: `positionSeconds`/
  ///       `isCompleted`/`lastWatched`/`durationSeconds`).
  ///    g. Atualiza `episodeCount` + `lastSynced` da season.
  ///
  /// **NÃO** faz reconciliação (deleção de seasons/episodes órfãos do
  /// servidor) — use [reconcileSeasonEpisodes] para isso.
  Future<void> syncSeasonEpisodes({
    required int contentId,
    required String contentServerUrl,
    PauloFlixNfoEnricher? enricher,
  }) async {
    // 1. Fetch + parse seasons.
    final seasons = await _fetchSeasons(contentServerUrl);

    for (final s in seasons) {
      // 2a. (Fase 10) Busca `season.nfo` (se enricher disponível).
      //     `null` = sem NFO / erro → fica null no banco. Caller pode
      //     usar TMDB/Jikan como fallback.
      String? seasonDescription;
      // 2a.1 (Fase 12) Busca poster/fanart da pasta da season via
      // listing. Análogo ao que `PauloFlixMoviesService._detectImageFiles`
      // faz para filmes, mas para seasons. Retorna nomes de arquivo
      // (não URLs) que serão resolvidos pelo repo via `posterUrlWith`.
      // Como `fetchEpisodeThumbs` já faz GET do listing da season
      // para detectar thumbs, poderíamos reusar aqui, mas a
      // separação é mais clara e o custo extra é 1 GET por season
      // (aceitável).
      DetectedSeasonImages seasonImages =
          const DetectedSeasonImages();
      if (enricher != null) {
        try {
          final seasonNfo = await enricher.fetchSeasonNfo(s.url);
          seasonDescription = seasonNfo?.plot;
        } catch (e) {
          debugPrint('[PauloFlixSync] fetchSeasonNfo failed: $e');
        }
        try {
          seasonImages = await enricher.fetchSeasonImages(s.url);
        } catch (e) {
          debugPrint('[PauloFlixSync] fetchSeasonImages failed: $e');
        }
      }

      // 2b. Upsert season (preserva `isCompleted` se já existir).
      final seasonId = await _repo.upsertSeason(
        contentId: contentId,
        seasonNumber: s.number,
        displayName: s.name,
        folderName: s.name,
        seasonDescription: seasonDescription,
        posterFileName: seasonImages.poster,
        fanartFileName: seasonImages.fanart,
      );

      // 2c. (Fase 10) Busca NFO de cada episode em batch (se enricher).
      //     Retorna `Map<int, String?>` episodeNumber → plot. Episodes
      //     sem NFO ficam com `plot = null` no map (não ausentados).
      //
      //     `seasonNumber` (de `s.number`) é OBRIGATÓRIO: antes da
      //     Fase N+5 o enricher hardcodava `S01` no filename do NFO
      //     do episode, então só funcionava para season 1. Para
      //     season 2+ o GET batia em 404 (`S01E001.nfo` em vez do
      //     correto `S02E001.nfo`) → plot nunca era populado.
      final Map<int, String?> episodeDescriptions = enricher != null
          ? (await enricher.fetchEpisodeNfos(s.url, s.number))
              .map((k, v) => MapEntry(k, v.plot))
          : <int, String?>{};

      // 2d. (Fase 5) Busca os thumbs NFO (se enricher disponível).
      //     Mapa: episodeNumber → thumbUrl. Vazio = sem thumb (ou
      //     enricher ausente) → repo preserva coluna `thumbnailUrl`
      //     anterior (não grava null em re-syncs).
      final Map<int, String> thumbs = enricher != null
          ? await enricher.fetchEpisodeThumbs(s.url)
          : <int, String>{};

      // 2e. Fetch + parse episodes desta season.
      final episodes = await _fetchEpisodes(s.url);

      // 2f. Upsert cada episode (preserva `positionSeconds`/
      //     `isCompleted`/`lastWatched`/`durationSeconds`).
      for (final e in episodes) {
        await _repo.upsertEpisode(
          seasonId: seasonId,
          episodeNumber: e.number,
          title: e.title,
          videoUrl: e.url,
          thumbnailUrl: thumbs[e.number],
          description: episodeDescriptions[e.number],
        );
      }

      // 2g. Atualiza `episodeCount` e `lastSynced` da season. **NÃO**
      //     é feito pelo `upsertSeason` (que só atualiza
      //     displayName/folderName/description se já existir) — o
      //     count é derivado do total scrapeado.
      await _updateSeasonCount(seasonId, episodes.length);

      debugPrint(
        '[PauloFlixSync] Content $contentId: '
        'season ${s.number} (${episodes.length} episodes, '
        '${thumbs.length} thumbs, '
        '${episodeDescriptions.values.where((p) => p != null).length} '
        'episode descriptions) sincronizada',
      );
    }
  }

  /// Sincroniza seasons + episodes E reconcilia com o banco.
  ///
  /// Combina [syncSeasonEpisodes] (upsert) com a deleção de
  /// seasons/episodes que sumiram do servidor.
  ///
  /// [enricher] é o injetor opcional de `PauloFlixNfoEnricher` (Fase
  /// 5). Quando fornecido, é propagado para `syncSeasonEpisodes`
  /// para que os thumbnails de episode sejam descobertos durante o
  /// sync. Quando `null` (default), a reconciliação não descobre
  /// thumbs.
  ///
  /// **Política de segurança:** seasons/episodes com progresso do
  /// usuário NUNCA são deletados (mesmo se ausentes do servidor) —
  /// ver `PauloFlixEpisodeProgressRepository.removeMissingSeasons`
  /// e `removeMissingEpisodes`.
  ///
  /// **Quando usar:** no sync geral (botão "Sincronizar" da
  /// `PauloFlixSeeAllScreen`), onde se quer o estado 100% espelhado
  /// com o servidor. NÃO usar para sync pontual ao entrar num anime
  /// (o `syncSeasonEpisodes` simples basta — sem remover nada).
  Future<SeasonEpisodesReconciliationStats> reconcileSeasonEpisodes({
    required int contentId,
    required String contentServerUrl,
    PauloFlixNfoEnricher? enricher,
  }) async {
    // 1. Snapshot do banco ANTES do sync — para detectar o que vai
    //    sumir.
    final preExistingSeasons =
        await _repo.getSeasonNumbersForContent(contentId);
    final seasonsBefore = await _repo.getSeasonsForContent(contentId);
    final preExistingEpisodesBySeason = <int, Set<int>>{};
    for (final s in seasonsBefore) {
      preExistingEpisodesBySeason[s.id!] =
          await _repo.getEpisodeNumbersForSeason(s.id!);
    }

    // 2. Sync básico (upsert) — propaga o enricher para a Fase 5
    //    descobrir thumbs de episode durante o sync.
    await syncSeasonEpisodes(
      contentId: contentId,
      contentServerUrl: contentServerUrl,
      enricher: enricher,
    );

    // 3. Diff de seasons: o que está no banco mas NÃO foi scrapeado?
    final scrapedSeasonNumbers =
        await _repo.getSeasonNumbersForContent(contentId);
    final missingSeasonNumbers =
        preExistingSeasons.difference(scrapedSeasonNumbers);

    // 4. Remove seasons ausentes (se não tiverem progresso). O
    //    repository já retorna a lista de ids removidos; o caller
    //    não precisa saber quais seasonNumbers foram mantidos
    //    individualmente — a heurística é "sem progresso =
    //    removida; com progresso = mantida".
    final seasonsRemoved = await _repo.removeMissingSeasons(
      contentId: contentId,
      scrapedSeasonNumbers: scrapedSeasonNumbers,
    );

    // 5. Para cada season scrapeada, reconcilia episodes.
    var episodesRemoved = 0;
    var episodesKept = 0;
    final seasonsAfter = await _repo.getSeasonsForContent(contentId);
    for (final s in seasonsAfter) {
      final preEpNums = preExistingEpisodesBySeason[s.id!] ?? <int>{};
      final postEpNums = await _repo.getEpisodeNumbersForSeason(s.id!);

      // A season foi raspada nesta sync, então seus episodes atuais
      // correspondem ao scrape novo (+ possíveis episodes
      // pré-existentes que o scrape não trouxe de volta). O diff
      // `preEpNums - postEpNums` = episodes que o servidor removeu.
      final removedIds = await _repo.removeMissingEpisodes(
        seasonId: s.id!,
        scrapedEpisodeNumbers: postEpNums,
      );
      episodesRemoved += removedIds.length;
      episodesKept +=
          preEpNums.difference(postEpNums).length - removedIds.length;
    }

    debugPrint(
      '[PauloFlixSync] Reconciliação content $contentId: '
      '${seasonsRemoved.length} seasons removidas, '
      '${missingSeasonNumbers.length - seasonsRemoved.length} mantidas, '
      '$episodesRemoved episodes removidos, $episodesKept mantidos.',
    );

    return SeasonEpisodesReconciliationStats(
      seasonsRemoved: seasonsRemoved.length,
      seasonsKept: missingSeasonNumbers.length - seasonsRemoved.length,
      episodesRemoved: episodesRemoved,
      episodesKept: episodesKept,
    );
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
    final body = _normalizeHtmlCharset(response.body, response.headers);
    final document = html_parser.parse(body);
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
    final body = _normalizeHtmlCharset(response.body, response.headers);
    final document = html_parser.parse(body);
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

  /// Normaliza o body HTML para UTF-8 quando o servidor declara
  /// charset não-UTF-8 (e.g. ISO-8859-1).
  ///
  /// Mesma estratégia do `PauloFlixMoviesService._normalizeHtmlCharset`:
  /// usa [detectHtmlCharset] (meta tag → Content-Type header) e,
  /// se o charset não for UTF-8, força re-decode via
  /// `latin1.encode` → `utf8.decode(allowMalformed: true)`. Falha
  /// silenciosa (retorna body original).
  static String _normalizeHtmlCharset(
    String htmlBody,
    Map<String, String> responseHeaders,
  ) {
    final charset = detectHtmlCharset(
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
      debugPrint('[PauloFlixSync] Charset re-decode failed: $e');
      return htmlBody;
    }
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

/// Estatísticas de uma reconciliação de seasons/episodes.
///
/// Usado pelo `PauloFlixProvider` para reportar progresso ao usuário
/// durante o sync geral.
class SeasonEpisodesReconciliationStats {
  const SeasonEpisodesReconciliationStats({
    required this.seasonsRemoved,
    required this.seasonsKept,
    required this.episodesRemoved,
    required this.episodesKept,
  });

  /// Seasons removidas (ausentes do servidor + sem progresso).
  final int seasonsRemoved;

  /// Seasons mantidas apesar de ausentes (tinham progresso do user).
  final int seasonsKept;

  /// Episodes removidos (ausentes do servidor + sem progresso).
  final int episodesRemoved;

  /// Episodes mantidos apesar de ausentes (tinham progresso do user).
  final int episodesKept;

  @override
  String toString() =>
      'SeasonEpisodesReconciliationStats('
      'seasonsRemoved: $seasonsRemoved, '
      'seasonsKept: $seasonsKept, '
      'episodesRemoved: $episodesRemoved, '
      'episodesKept: $episodesKept)';
}
