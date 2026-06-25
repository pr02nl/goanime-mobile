/// Orquestrador HTTP para enriquecimento de conteúdo PauloFlix via
/// arquivos NFO/JPG do servidor.
///
/// Fonte: plano `.hermes/plans/2026-06-23_224213-pauloflix-nfo-enrichment.md` (Fase 2).
///
/// **Responsabilidades:**
/// - Fazer GET de `tvshow.nfo` / `movie.nfo` / `season.nfo` do servidor.
/// - Fazer GET do listing HTML de uma pasta (autoindex) e extrair
///   thumbs de episodes.
/// - Resolver URLs de imagem (absoluta ou relativa) usando o `serverUrl`.
///
/// **Garantia de robustez:** todos os métodos públicos (`fetchShowNfo`,
/// `fetchMovieNfo`, `fetchEpisodeThumbs`, `fetchSeasonNfo`) envolvem a
/// chamada HTTP em `try`/`catch` e retornam `null` (ou map vazio) em
/// qualquer falha. NUNCA propagam exceção — o fluxo sempre cai pro
/// fallback Jikan/TMDB.
///
/// **Lifecycle:** a enricher mantém um `http.Client` interno. O caller
/// DEVE chamar `dispose()` ao final (provider é descartado no app
/// shutdown) para evitar socket leak.
library;

import 'package:flutter/foundation.dart';
import 'package:goanime/core/utils/url_codec.dart' as url_codec;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'kodi_nfo_models.dart';
import 'kodi_nfo_parser.dart';

/// Timeout HTTP padrão para todos os fetches NFO. Pequeno o suficiente
/// para não travar o sync, grande o suficiente para servidores lentos.
const Duration _kRequestTimeout = Duration(seconds: 10);

/// Regex que identifica o thumb de um episode a partir do nome do
/// arquivo no listing da season.
///
/// **Match examples:**
/// - `S01E001-thumb.jpg` → episode 1
/// - `S01E002-thumb.png` → episode 2
/// - `S01E10-thumb.webp` → episode 10
///
/// **Non-match:**
/// - `S01E001.jpg` (sem `-thumb`).
/// - `thumb.jpg` (sem padrão S\d+E\d+).
///
/// **Dedup:** o grupo `(\d+)` captura o número do episode. `int.parse`
/// normaliza `001` → `1`, então o map dedup por episode number
/// automaticamente (primeiro match vence).
final RegExp _episodeThumbPattern = RegExp(
  r'S\d+E(\d+)-thumb\.(jpg|jpeg|png|webp)$',
  caseSensitive: false,
);

/// Regex que identifica o NFO de um episode a partir do nome do
/// arquivo no listing da season.
///
/// **Match examples:**
/// - `S01E001.nfo` → episode 1
/// - `S02E010.nfo` → episode 10
///
/// **Non-match:**
/// - `S01E001-thumb.jpg` (é thumb, não NFO).
/// - `tvshow.nfo` (não tem S\d+E\d+).
///
/// **Por que existe separado do `_episodeThumbPattern`:** o
/// `fetchEpisodeNfos` precisa descobrir QUAIS episodes existem na
/// season. Se usar só o thumb pattern, seasons que têm NFO mas
/// não têm thumb (caso comum em setups minimalistas do Kodi) são
/// puladas → plot nunca é populado. Este regex captura os NFOs
/// diretamente do listing.
final RegExp _episodeNfoPattern = RegExp(
  r'S\d+E(\d+)\.nfo$',
  caseSensitive: false,
);

/// Enriquece conteúdo PauloFlix (animes / movies / seasons) lendo
/// arquivos NFO/JPG diretamente do servidor.
class PauloFlixNfoEnricher {
  final http.Client _client;

  /// Cria o enricher com um `http.Client` injetado (em produção, usar
  /// `AuthenticatedHttpClient` para reaproveitar o JWT manager).
  PauloFlixNfoEnricher({required http.Client client}) : _client = client;

  // ============================================================
  // NFO fetchers
  // ============================================================

  /// GET `{showUrl}tvshow.nfo` → parse → `KodiShowNfo?`.
  ///
  /// Retorna `null` em qualquer falha (404, 500, timeout, parse fail).
  Future<KodiShowNfo?> fetchShowNfo(String showUrl) async {
    try {
      final res = await _client
          .get(Uri.parse('${showUrl}tvshow.nfo'))
          .timeout(_kRequestTimeout);
      if (res.statusCode != 200) return null;
      final body = url_codec.decodeResponseBody(
        res.bodyBytes,
        responseHeaders: res.headers,
      );
      if (body.isEmpty) return null;
      return KodiNfoParser.parseShow(body);
    } catch (e) {
      debugPrint('[PauloFlixNfo] fetchShowNfo failed: $e');
      return null;
    }
  }

  /// GET `{folderUrl}movie.nfo` → parse → `KodiShowNfo?`.
  ///
  /// Retorna `null` em qualquer falha (404, 500, timeout, parse fail).
  Future<KodiShowNfo?> fetchMovieNfo(String folderUrl) async {
    try {
      final res = await _client
          .get(Uri.parse('${folderUrl}movie.nfo'))
          .timeout(_kRequestTimeout);
      if (res.statusCode != 200) return null;
      final body = url_codec.decodeResponseBody(
        res.bodyBytes,
        responseHeaders: res.headers,
      );
      if (body.isEmpty) return null;
      return KodiNfoParser.parseMovie(body);
    } catch (e) {
      debugPrint('[PauloFlixNfo] fetchMovieNfo failed: $e');
      return null;
    }
  }

  /// GET `{seasonUrl}season.nfo` → parse → `KodiSeasonNfo?`.
  ///
  /// Retorna `null` em qualquer falha.
  Future<KodiSeasonNfo?> fetchSeasonNfo(String seasonUrl) async {
    try {
      final res = await _client
          .get(Uri.parse('${seasonUrl}season.nfo'))
          .timeout(_kRequestTimeout);
      if (res.statusCode != 200) return null;
      final body = url_codec.decodeResponseBody(
        res.bodyBytes,
        responseHeaders: res.headers,
      );
      if (body.isEmpty) return null;
      return KodiNfoParser.parseSeasonNfo(body);
    } catch (e) {
      debugPrint('[PauloFlixNfo] fetchSeasonNfo failed: $e');
      return null;
    }
  }

  /// GET `{seasonUrl}S{ss}E{nnn}.nfo` → parse → record Dart 3.
  ///
  /// **Fase 10 do plano NFO enrichment V2**: parse do NFO por
  /// episode (padrão Kodi `S01E001.nfo` na pasta da season) para
  /// popular a coluna `description` (plot) do episode. O nome do
  /// arquivo usa 2 dígitos para season + 3 dígitos para episode
  /// (zero-padded) — `S01E001.nfo`, `S02E010.nfo`, `S10E100.nfo`.
  ///
  /// Exemplo: `fetchEpisodeNfo('http://server/tvshows/X/Season 02/', 2, 1)`
  /// faz GET `http://server/tvshows/X/Season 02/S02E001.nfo`.
  ///
  /// **Por que `seasonNumber` é obrigatório:** antes desta correção
  /// (Fase N+5) o método hardcodava `S01` no filename — só
  /// funcionava para season 1. Para season 2+, gerava `S01E001.nfo`
  /// (404) em vez do correto `S02E001.nfo`. O caller SEMPRE tem o
  /// season number disponível (vem do `PauloFlixSeason.number`
  /// da scraping), então exigir o param força o caller a passar
  /// e elimina o bug.
  ///
  /// **Fallback de zero-padding do episode (Fase N+8):** o padrão
  /// Kodi é `S\d+E\d{3}.nfo` (3 dígitos), mas em servidores reais
  /// a convenção é mista — o ep 13 pode estar salvo como
  /// `S01E013.nfo` (3-dígitos) ou `S01E13.nfo` (2-dígitos) ou
  /// `S01E1.nfo` (sem zero). Ver
  /// `.hermes/plans/2026-06-24-pauloflix-nfo-zero-padding-fallback.md`
  /// para o caso real (Solo Leveling S01, junho 2026: eps 1-12
  /// tinham ambos os formatos 2/3-dígitos, eps 13-25 existiam
  /// APENAS como 2-dígitos → 404 no GET 3-dígitos → NFO nunca
  /// era salvo). Estratégia atual: tenta 3-dígitos primeiro
  /// (padrão Kodi, mais comum), depois 2-dígitos, depois
  /// sem padding. 1 GET por tentativa, máx 3 GETs por ep.
  ///
  /// Retorna `null` em qualquer falha (404 em todas as variantes,
  /// 500, timeout, parse fail).
  Future<KodiEpisodeNfo?>
  fetchEpisodeNfo(String seasonUrl, int seasonNumber, int episodeNumber) async {
    final seasonStr = seasonNumber.toString().padLeft(2, '0');
    final base = seasonUrl.endsWith('/') ? seasonUrl : '$seasonUrl/';
    // Ordem de tentativa: 3-dígitos (Kodi) → 2-dígitos → sem padding.
    // Cobre todas as convenções vistas em file servers reais.
    final candidateFilenames = <String>[
      'S${seasonStr}E${episodeNumber.toString().padLeft(3, '0')}.nfo',
      'S${seasonStr}E${episodeNumber.toString().padLeft(2, '0')}.nfo',
      'S${seasonStr}E$episodeNumber.nfo',
    ];
    try {
      for (final filename in candidateFilenames) {
        final url = '$base$filename';
        final res =
            await _client.get(Uri.parse(url)).timeout(_kRequestTimeout);
        if (res.statusCode == 200 && res.body.isNotEmpty) {
          return KodiNfoParser.parseEpisode(res.body);
        }
        // 404 (ou qualquer outro status != 200) → tenta a próxima
        // variante. Se 200 mas body vazio, também tenta a próxima
        // (defensivo — não deveria acontecer).
      }
      return null;
    } catch (e) {
      debugPrint('[PauloFlixNfo] fetchEpisodeNfo failed: $e');
      return null;
    }
  }

  // Lifecycle
  // ============================================================

  /// Fecha o `http.Client` interno. Deve ser chamado no `dispose` do
  /// provider para evitar socket leak.
  void dispose() => _client.close();

  // ============================================================
  // Season images (poster/fanart via poster.jpg/fanart.jpg)
  // ============================================================

  /// Resultado de [PauloFlixNfoEnricher.fetchSeasonImages] — `poster`
  /// e `fanart` são os **nomes de arquivo** (não URLs) encontrados na
  /// pasta da season, ou null se ausentes.
  static const Set<String> _seasonImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  /// Nomes canônicos (Kodi) para poster e fanart de season.
  static const Set<String> _seasonPosterNames = {
    'poster',
    'cover',
    'folder',
    'season-poster',
  };
  static const Set<String> _seasonFanartNames = {
    'fanart',
    'backdrop',
    'banner',
    'season-banner',
  };

  static const DetectedSeasonImages _kEmptyImages = DetectedSeasonImages();

  /// GET do listing HTML da pasta da season + parse dos JPGs
  /// de poster/fanart. Retorna nomes de arquivo detectados.
  ///
  /// **Por que existe:** o `season.nfo` pode ter `<thumb>` apontando
  /// para um path, mas algumas seasons não têm NFO — ou o NFO
  /// não tem tag de imagem. Este método cobre o caso de fallback
  /// (análogo ao `PauloFlixMoviesService._detectImageFiles` para
  /// filmes), lendo direto do listing da pasta.
  ///
  /// **Estratégia:**
  /// 1. Match canônico (`poster.jpg`, `fanart.jpg`).
  /// 2. Match fuzzy (nome contém "poster"/"fanart"/"cover"/"banner").
  /// 3. Fallback: primeiro .jpg como poster (heurística fraca).
  ///
  /// **NÃO** chama `season.nfo` — esse é responsabilidade do
  /// `fetchSeasonNfo`. O caller decide qual usar (ou combina).
  Future<DetectedSeasonImages> fetchSeasonImages(String seasonUrl) async {
    try {
      final res = await _client
          .get(Uri.parse(seasonUrl))
          .timeout(_kRequestTimeout);
      if (res.statusCode != 200) {
        return _kEmptyImages;
      }
      if (res.body.isEmpty) return _kEmptyImages;
      return _parseSeasonImagesFromHtml(res.body);
    } catch (e) {
      debugPrint('[PauloFlixNfo] fetchSeasonImages failed: $e');
      return _kEmptyImages;
    }
  }

  /// Faz parse do listing HTML e detecta `poster.jpg`/`fanart.jpg`/
  /// `banner.jpg` na pasta. Nomes são preservados como decoded (sem
  /// URL-encoding) — o caller resolve para URL absoluta via
  /// `resolveThumbUrl`.
  static DetectedSeasonImages _parseSeasonImagesFromHtml(String htmlBody) {
    String? poster;
    String? fanart;
    String? firstImage;

    final document = html_parser.parse(htmlBody);
    for (final anchor in _findAnchors(document)) {
      final href = anchor.attributes['href'];
      if (href == null) continue;
      final name = href.toLowerCase();
      final base = name.contains('.')
          ? name.substring(0, name.lastIndexOf('.'))
          : name;
      final ext = name.contains('.')
          ? name.substring(name.lastIndexOf('.'))
          : '';
      if (!_seasonImageExtensions.contains(ext)) continue;

      firstImage ??= href;

      if (poster == null && _seasonPosterNames.contains(base)) {
        poster = href;
        continue;
      }
      if (fanart == null && _seasonFanartNames.contains(base)) {
        fanart = href;
        continue;
      }
      if (poster == null && _seasonPosterNames.any((n) => base.contains(n))) {
        poster = href;
        continue;
      }
      if (fanart == null && _seasonFanartNames.any((n) => base.contains(n))) {
        fanart = href;
        continue;
      }
    }

    poster ??= firstImage;
    return DetectedSeasonImages(poster: poster, fanart: fanart);
  }

  /// Faz listing HTML da season + descobre episode numbers via
  /// padrão NFO (`S\d+E\d+\.nfo`). Dispara N GETs paralelos de NFO
  /// via [fetchEpisodeNfo] + inclui a `thumbUrl` do
  /// [fetchEpisodeThumbs] (quando existir) no record.
  ///
  /// Retorna `Map<int, ({KodiEpisodeNfo? nfo, String? thumbUrl})>`
  /// indexado por episodeNumber. **Fase N+7:** o record interno
  /// mudou de inline (`({int? season, int? episode, String? title,
  /// String? plot, String? thumbUrl})`) para carregar o
  /// `KodiEpisodeNfo` completo (V2: +`originalTitle`, `outline`,
  /// `aired`, `rating`, `runtime`). Caller pega o que precisa via
  /// `nfo?.plot` etc. Map vazio em qualquer falha (404 no listing,
  /// zero episodes detectados).
  ///
  /// **Atenção:** a função é best-effort — episodes sem NFO resultam
  /// em um entry com `nfo: null` (não ausenta o entry). Isso
  /// preserva a informação "episódio existe mas não tem NFO" e
  /// permite que o caller decida se quer ou não popular o campo
  /// `description` no banco.
  ///
  /// **Por que descobrir episodes via NFO (não via thumb):** antes
  /// desta correção (Fase N+6) usava `fetchEpisodeThumbs` para
  /// descobrir os episode numbers. Resultado: seasons que tinham
  /// `S\d+E\d+\.nfo` mas **não** tinham `S\d+E\d+-thumb.{ext}` (caso
  /// comum em setups minimalistas do Kodi) eram puladas — o NFO
  /// nunca era buscado, o plot nunca era populado. Agora o listing
  /// é parseado procurando o padrão NFO (regex `_episodeNfoPattern`),
  /// que é o indicador primário de "episódio existe nesta season".
  ///
  /// **Custo (Fase N+9):** ZERO GETs pra descobrir episodes/thumbs
  /// (info vem do [fetchSeasonListing] que o caller já chamou) + N
  /// GETs paralelos (um por NFO de episode). Antes da Fase N+9
  /// eram 2 GETs a mais (listing NFO + listing thumbs) — agora
  /// eliminados.
  ///
  /// Caller DEVE chamar [fetchSeasonListing] antes (Fase N+9) e
  /// passar os episode numbers + thumb URLs como parâmetro. Esta
  /// função só faz a parte N-GETs (buscar os NFOs).
  ///
  /// **Atenção:** a função é best-effort — episodes sem NFO resultam
  /// em um entry com `nfo: null` (não ausenta o entry). Isso
  /// preserva a informação "episódio existe mas não tem NFO" e
  /// permite que o caller decida se quer ou não popular o campo
  /// `description` no banco.
  Future<Map<int, ({KodiEpisodeNfo? nfo, String? thumbUrl})>>
      fetchEpisodeNfos({
    required String seasonUrl,
    required int seasonNumber,
    required List<int> episodeNumbers,
    required Map<int, String> thumbUrlsByEpisode,
  }) async {
    if (episodeNumbers.isEmpty) {
      return <int, ({KodiEpisodeNfo? nfo, String? thumbUrl})>{};
    }

    // N GETs paralelos (um por episode). `Future.wait` dispara todos
    // simultaneamente; tempo total ≈ 1 RTT (não N).
    final nfoResults = await Future.wait(
      episodeNumbers.map((n) async {
        final nfo = await fetchEpisodeNfo(seasonUrl, seasonNumber, n);
        return MapEntry<int, ({KodiEpisodeNfo? nfo, String? thumbUrl})>(
          n,
          (nfo: nfo, thumbUrl: thumbUrlsByEpisode[n]),
        );
      }),
    );
    return Map.fromEntries(nfoResults);
  }

  // ============================================================
  // Show images (poster/fanart via poster.jpg/fanart.jpg)
  // ============================================================

  /// Resultado de [PauloFlixNfoEnricher.fetchShowImages] — `poster` e
  /// `fanart` são os **nomes de arquivo** (não URLs) encontrados na
  /// pasta do show, ou null se ausentes.
  static const Set<String> _showImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  /// Nomes canônicos (Kodi) para poster e fanart de show.
  static const Set<String> _showPosterNames = {
    'poster',
    'cover',
    'folder',
    'tvshow-poster',
  };
  static const Set<String> _showFanartNames = {
    'fanart',
    'backdrop',
    'banner',
    'tvshow-banner',
  };

  static const DetectedShowImages _kEmptyShowImages = DetectedShowImages();

  /// GET do listing HTML da pasta do show + parse dos JPGs
  /// de poster/fanart. Retorna nomes de arquivo detectados.
  ///
  /// **Por que existe:** o `tvshow.nfo` pode ter `<thumb>` apontando
  /// para um path, mas alguns shows não têm NFO — ou o NFO
  /// não tem tag de imagem. Este método cobre o caso de fallback
  /// (espelha `fetchSeasonImages` para seasons), lendo direto
  /// do listing da pasta.
  ///
  /// **Estratégia:**
  /// 1. Match canônico (`poster.jpg`, `fanart.jpg`).
  /// 2. Match fuzzy (nome contém "poster"/"fanart"/"cover"/"banner").
  /// 3. Fallback: primeiro .jpg como poster (heurística fraca).
  ///
  /// **NÃO** chama `tvshow.nfo` — esse é responsabilidade do
  /// `fetchShowNfo`. O caller decide qual usar (ou combina).
  Future<DetectedShowImages> fetchShowImages(String showUrl) async {
    try {
      final res = await _client
          .get(Uri.parse(showUrl))
          .timeout(_kRequestTimeout);
      if (res.statusCode != 200) {
        return _kEmptyShowImages;
      }
      if (res.body.isEmpty) return _kEmptyShowImages;
      return _parseShowImagesFromHtml(res.body);
    } catch (e) {
      debugPrint('[PauloFlixNfo] fetchShowImages failed: $e');
      return _kEmptyShowImages;
    }
  }

  /// Faz parse do listing HTML e detecta `poster.jpg`/`fanart.jpg`/
  /// `banner.jpg` na pasta do show. Nomes são preservados como
  /// decoded (sem URL-encoding) — o caller resolve para URL absoluta
  /// via `resolveThumbUrl`.
  static DetectedShowImages _parseShowImagesFromHtml(String htmlBody) {
    String? poster;
    String? fanart;
    String? firstImage;

    final document = html_parser.parse(htmlBody);
    for (final anchor in _findAnchors(document)) {
      final href = anchor.attributes['href'];
      if (href == null) continue;
      final name = href.toLowerCase();
      final base = name.contains('.')
          ? name.substring(0, name.lastIndexOf('.'))
          : name;
      final ext = name.contains('.')
          ? name.substring(name.lastIndexOf('.'))
          : '';
      if (!_showImageExtensions.contains(ext)) continue;

      firstImage ??= href;

      if (poster == null && _showPosterNames.contains(base)) {
        poster = href;
        continue;
      }
      if (fanart == null && _showFanartNames.contains(base)) {
        fanart = href;
        continue;
      }
      if (poster == null && _showPosterNames.any((n) => base.contains(n))) {
        poster = href;
        continue;
      }
      if (fanart == null && _showFanartNames.any((n) => base.contains(n))) {
        fanart = href;
        continue;
      }
    }

    poster ??= firstImage;
    return DetectedShowImages(poster: poster, fanart: fanart);
  }

  /// GET `{showUrl}tvshow.nfo` + GET listing HTML em paralelo.
  ///
  /// Retorna um record com o NFO parseado (ou null em falha) e os
  /// JPGs físicos detectados na pasta (poster/fanart via
  /// `poster.jpg`/`fanart.jpg`).
  ///
  /// **Por que um record e não só `KodiShowNfo?`:** o NFO pode ter
  /// `<thumb aspect="poster">poster.jpg</thumb>` mas o arquivo físico
  /// pode estar ausente (ou vice-versa). Expor os 2 ao caller permite
  /// fallback em cascata:
  /// 1. URL absoluta do NFO `<thumb>` (se existir).
  /// 2. URL do JPG físico (se existir).
  /// 3. Jikan (camada externa).
  ///
  /// **Custo:** 2 GETs paralelos por show (mesmo RTT que 1 GET sequencial
  /// graças ao `Future.wait`).
  ///
  /// **Compat:** este método é **adicional** ao `fetchShowNfo` (que
  /// continua existindo para callers que só querem o NFO, ex. testes
  /// unitários antigos). Não quebra API existente.
  Future<({KodiShowNfo? nfo, DetectedShowImages images})>
  fetchShowNfoWithImages(String showUrl) async {
    final results = await Future.wait<Object?>([
      fetchShowNfo(showUrl),
      fetchShowImages(showUrl),
    ]);
    return (
      nfo: results[0] as KodiShowNfo?,
      images: results[1] as DetectedShowImages,
    );
  }

  // ============================================================
  // Season listing unificado (Fase N+9)
  // ============================================================
  //
  // **Problema:** antes desta fase o sync service fazia 3 GETs
  // separados pra mesma URL de season:
  // 1. `fetchEpisodeNfos` (1 GET listing) → episode numbers + thumbs.
  // 2. `fetchSeasonNfo` (1 GET season.nfo) → plot da season.
  // 3. `fetchSeasonImages` (1 GET listing — REDUNDANTE com #1) →
  //    poster.jpg/fanart.jpg.
  //
  // 2 dos 3 GETs iam pra MESMA URL — desperdício de RTT e carga no
  // file server. E o caller (sync service) tinha que orquestrar
  // 3 awaits pra extrair o que dá pra extrair em 1.
  //
  // **Solução:** `fetchSeasonListing` faz 1 GET ao listing e retorna
  // tudo: episode numbers (do regex NFO), thumb URLs, season images,
  // flag `hasSeasonNfo`, lista de NFOs individuais encontrados.
  // Caller decide depois se quer buscar o `season.nfo` (1 GET extra)
  // e/ou os NFOs individuais (N GETs paralelos).
  //
  // **Custo:** 1 GET base (sempre). Acima disso:
  // - 0 GETs extras se o caller só precisa de episodes + thumbs + images.
  // - +1 GET se quiser o `season.nfo` plot.
  // - +N GETs paralelos se quiser os NFOs individuais.
  //
  // **Por que `episodeNumbers` vem do regex NFO (não do thumb):** o
  // `fetchEpisodeNfos` (Fase N+6) já descobriu via NFO porque seasons
  // minimalistas têm NFO mas não têm thumb. Mantemos a mesma
  // semântica. Se a season não tiver NFO nenhum, retorna lista vazia
  // (caller cai no path de scraping de .mkv que já existia).

  /// Resultado de [PauloFlixNfoEnricher.fetchSeasonListing] —
  /// record Dart 3 com tudo extraído de UM único GET ao listing
  /// HTML da pasta da season.
  ///
  /// Campos:
  /// - [episodeNumbers]: lista ordenada de episode numbers
  ///   detectados via regex `S\d+E(\d+)\.nfo` no listing. Vazio se
  ///   a season não tem NFOs (caller cai no scraping de .mkv).
  /// - [thumbUrls]: mapa `episodeNumber → thumbUrl absoluta` para
  ///   `S\d+E\d+-thumb.{ext}` encontrados. Dedup automático (001
  ///   e 01 normalizam pro mesmo episode number; primeiro vence).
  /// - [images]: nomes de arquivo de poster/fanart detectados via
  ///   nomes canônicos (`poster.jpg`, `fanart.jpg`).
  /// - [hasSeasonNfo]: `true` se o listing contém `season.nfo`.
  ///   Caller decide se vale a pena 1 GET extra.
  /// - [episodeNfoFilenames]: lista de filenames `S\d+E\d+\.nfo`
  ///   (com a grafia original do servidor). Útil pro caller
  ///   evitar a heurística de zero-padding do `fetchEpisodeNfo`
  ///   quando já sabe o filename exato.
  static const _kEmptyListing = (
    episodeNumbers: <int>[],
    thumbUrls: <int, String>{},
    images: DetectedSeasonImages(),
    hasSeasonNfo: false,
    episodeNfoFilenames: <String>[],
  );

  Future<({
    List<int> episodeNumbers,
    Map<int, String> thumbUrls,
    DetectedSeasonImages images,
    bool hasSeasonNfo,
    List<String> episodeNfoFilenames,
  })>
      fetchSeasonListing(String seasonUrl) async {
    try {
      final res = await _client
          .get(Uri.parse(seasonUrl))
          .timeout(_kRequestTimeout);
      if (res.statusCode != 200) return _kEmptyListing;
      if (res.body.isEmpty) return _kEmptyListing;
      return _parseSeasonListing(res.body, seasonUrl);
    } catch (e) {
      debugPrint('[PauloFlixNfo] fetchSeasonListing failed: $e');
      return _kEmptyListing;
    }
  }

  /// Faz parse do listing HTML e extrai todos os metadados da
  /// season num único pass. Ver [fetchSeasonListing] pra descrição
  /// completa do retorno.
  static ({
    List<int> episodeNumbers,
    Map<int, String> thumbUrls,
    DetectedSeasonImages images,
    bool hasSeasonNfo,
    List<String> episodeNfoFilenames,
  }) _parseSeasonListing(String htmlBody, String seasonUrl) {
    final episodeNumbers = <int>{};
    final thumbUrls = <int, String>{};
    final episodeNfoFilenames = <String>[];
    var hasSeasonNfo = false;

    String? poster;
    String? fanart;
    String? firstImage;

    final document = html_parser.parse(htmlBody);
    for (final anchor in _findAnchors(document)) {
      final href = anchor.attributes['href'];
      if (href == null) continue;

      // 1. Episodes via NFO pattern (sinal primário de "ep existe").
      final nfoMatch = _episodeNfoPattern.firstMatch(href);
      if (nfoMatch != null) {
        final ep = int.tryParse(nfoMatch.group(1)!);
        if (ep != null) {
          episodeNumbers.add(ep);
          episodeNfoFilenames.add(href);
        }
        continue; // NFO não é thumb nem imagem
      }

      // 2. Episode thumbs (S\d+E\d+-thumb.{ext}).
      final thumbMatch = _episodeThumbPattern.firstMatch(href);
      if (thumbMatch != null) {
        final ep = int.tryParse(thumbMatch.group(1)!);
        if (ep != null && !thumbUrls.containsKey(ep)) {
          thumbUrls[ep] = resolveThumbUrl(seasonUrl, href);
        }
        continue;
      }

      // 3. season.nfo existence flag.
      if (href.toLowerCase() == 'season.nfo') {
        hasSeasonNfo = true;
        continue;
      }

      // 4. Season images (poster/fanart canônicos).
      final name = href.toLowerCase();
      final base = name.contains('.')
          ? name.substring(0, name.lastIndexOf('.'))
          : name;
      final ext = name.contains('.')
          ? name.substring(name.lastIndexOf('.'))
          : '';
      if (!_seasonImageExtensions.contains(ext)) continue;

      firstImage ??= href;
      if (poster == null && _seasonPosterNames.contains(base)) {
        poster = href;
        continue;
      }
      if (fanart == null && _seasonFanartNames.contains(base)) {
        fanart = href;
        continue;
      }
      if (poster == null && _seasonPosterNames.any((n) => base.contains(n))) {
        poster = href;
        continue;
      }
      if (fanart == null && _seasonFanartNames.any((n) => base.contains(n))) {
        fanart = href;
        continue;
      }
    }

    poster ??= firstImage;

    return (
      episodeNumbers: episodeNumbers.toList()..sort(),
      thumbUrls: thumbUrls,
      images: DetectedSeasonImages(poster: poster, fanart: fanart),
      hasSeasonNfo: hasSeasonNfo,
      episodeNfoFilenames: episodeNfoFilenames,
    );
  }

  // ============================================================
  // Episode thumb scraper
  // ============================================================

  /// GET listing HTML da season → extrai `S\d+E(\d+)-thumb.{ext}`.
  ///
  /// Retorna `Map<int episodeNumber, String thumbUrl>`. Dedup automático
  /// por episode number (`001` → `1`); em caso de duplicata, o primeiro
  /// match no listing vence.
  ///
  /// Retorna map vazio em qualquer falha (404, 500, timeout, parse fail).
  ///
  /// **DEPRECADO (Fase N+9):** prefira [fetchSeasonListing] — extrai
  /// thumbs + episodes + images num único GET. Este método continua
  /// existindo só pra back-compat com testes e callers externos.
  Future<Map<int, String>> fetchEpisodeThumbs(String seasonUrl) async {
    try {
      final res = await _client
          .get(Uri.parse(seasonUrl))
          .timeout(_kRequestTimeout);
      if (res.statusCode != 200) return const <int, String>{};
      if (res.body.isEmpty) return const <int, String>{};
      return _parseEpisodeThumbsFromHtml(res.body, seasonUrl);
    } catch (e) {
      debugPrint('[PauloFlixNfo] fetchEpisodeThumbs failed: $e');
      return const <int, String>{};
    }
  }

  // ============================================================
  // URL resolution
  // ============================================================

  /// Resolve a URL final de um thumb.
  ///
  /// - Se [thumb] já é URL absoluta (`http://` ou `https://`), retorna
  ///   como está.
  /// - Se é path relativo, monta `{serverUrl}{thumb}` (com encoding).
  static String resolveThumbUrl(String serverUrl, String thumb) {
    if (thumb.startsWith('http://') || thumb.startsWith('https://')) {
      return thumb;
    }
    final base = serverUrl.endsWith('/') ? serverUrl : '$serverUrl/';
    return '$base${Uri.encodeComponent(thumb)}';
  }

  // ============================================================
  // Internals
  // ============================================================

  /// Faz parse do listing HTML e extrai os thumbs de episodes.
  ///
  /// Usa o pacote `html` (já no projeto) com `document.querySelectorAll`.
  static Map<int, String> _parseEpisodeThumbsFromHtml(
    String htmlBody,
    String seasonUrl,
  ) {
    final result = <int, String>{};
    final document = html_parser.parse(htmlBody);

    // `querySelectorAll` é o método padrão do pacote `html`.
    // Fallback para `getElementsByTagName` em caso de incompatibilidade.
    final Iterable<dom.Element> anchors = _findAnchors(document);

    for (final anchor in anchors) {
      final href = anchor.attributes['href'];
      if (href == null) continue;
      final match = _episodeThumbPattern.firstMatch(href);
      if (match == null) continue;
      final episodeNumber = int.tryParse(match.group(1)!);
      if (episodeNumber == null) continue;
      // Dedup: primeiro match vence.
      if (result.containsKey(episodeNumber)) continue;
      result[episodeNumber] = resolveThumbUrl(seasonUrl, href);
    }
    return result;
  }

  /// Helper que faz `document.querySelectorAll('a[href]')` ou usa
  /// `getElementsByTagName('a')` como fallback.
  static Iterable<dom.Element> _findAnchors(dom.Document document) {
    try {
      return document.querySelectorAll('a[href]');
    } catch (_) {
      return document.getElementsByTagName('a');
    }
  }

  /// Retorna o `innerText` (trimmed) do primeiro elemento [tag] filho
  /// de [parent], ou `null` se não existir.
  ///
  /// **Fase 10 do plano NFO enrichment V2:** este helper ficou
  /// descontinuado após o `_parseSeasonNfo` delegar para
  /// `KodiNfoParser.parseSeasonNfo` (que tem seu próprio helper).
  /// Removido nesta Fase 10 — se outros parsers precisarem,
  /// re-adicionar ou importar de `KodiNfoParser`.
}

/// Resultado de [PauloFlixNfoEnricher.fetchSeasonImages] — `poster`
/// e `fanart` são os **nomes de arquivo** (não URLs) encontrados na
/// pasta da season, ou null se ausentes.
class DetectedSeasonImages {
  final String? poster;
  final String? fanart;
  const DetectedSeasonImages({this.poster, this.fanart});
}

/// Resultado de [PauloFlixNfoEnricher.fetchShowImages] — `poster` e
/// `fanart` são os **nomes de arquivo** (não URLs) encontrados na
/// pasta do show, ou null se ausentes.
///
/// Espelha [DetectedSeasonImages] (mesma forma), mas usado para
/// shows (`/tvshows/HxH/`) em vez de seasons (`/tvshows/HxH/Season 01/`).
class DetectedShowImages {
  final String? poster;
  final String? fanart;
  const DetectedShowImages({this.poster, this.fanart});
}
