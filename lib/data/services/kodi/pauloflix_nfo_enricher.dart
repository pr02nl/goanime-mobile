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
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'package:goanime/core/utils/url_codec.dart' as url_codec;
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

  /// GET `{seasonUrl}S01E{nnn}.nfo` → parse → record Dart 3.
  ///
  /// **Fase 10 do plano NFO enrichment V2**: parse do NFO por
  /// episode (padrão Kodi `S01E001.nfo` na pasta da season) para
  /// popular a coluna `description` (plot) do episode. O nome do
  /// arquivo usa 3 dígitos (zero-padded) — `S01E001.nfo`,
  /// `S01E010.nfo`, `S01E100.nfo`.
  ///
  /// Exemplo: `fetchEpisodeNfo('http://server/tvshows/X/Season 01/', 1)`
  /// faz GET `http://server/tvshows/X/Season 01/S01E001.nfo`.
  ///
  /// Retorna `null` em qualquer falha (404, 500, timeout, parse fail).
  Future<({int? season, int? episode, String? title, String? plot})?>
      fetchEpisodeNfo(String seasonUrl, int episodeNumber) async {
    try {
      final filename = 'S01E${episodeNumber.toString().padLeft(3, '0')}.nfo';
      final base = seasonUrl.endsWith('/') ? seasonUrl : '$seasonUrl/';
      final url = '$base$filename';
      final res = await _client
          .get(Uri.parse(url))
          .timeout(_kRequestTimeout);
      if (res.statusCode != 200) return null;
      if (res.body.isEmpty) return null;
      return KodiNfoParser.parseEpisode(res.body);
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
    'poster', 'cover', 'folder', 'season-poster',
  };
  static const Set<String> _seasonFanartNames = {
    'fanart', 'backdrop', 'banner', 'season-banner',
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

  /// [fetchEpisodeThumbs] para descobrir os episode numbers via
  /// listing HTML (1 GET) e dispara N GETs paralelos de NFO via
  /// [fetchEpisodeNfo].
  ///
  /// Retorna `Map<int, ({int? season, int? episode, String? title, String? plot})>`
  /// indexado por episodeNumber. Map vazio em qualquer falha
  /// (404 no listing, zero episodes detectados).
  ///
  /// **Atenção:** a função é best-effort — episodes sem NFO resultam
  /// em um entry com `plot = null` (não ausenta o entry). Isso
  /// preserva a informação "episódio existe mas não tem NFO" e
  /// permite que o caller decida se quer ou não popular o campo
  /// `description` no banco.
  Future<Map<int, ({int? season, int? episode, String? title, String? plot})>>
      fetchEpisodeNfos(String seasonUrl) async {
    // 1. Descobre os episode numbers via listing (mesma lógica do
    //    `fetchEpisodeThumbs`, mas só queremos os KEYS).
    final thumbs = await fetchEpisodeThumbs(seasonUrl);
    final episodeNumbers = thumbs.keys.toList();
    if (episodeNumbers.isEmpty) {
      return <int,
          ({
            int? season,
            int? episode,
            String? title,
            String? plot
          })>{};
    }

    // 2. GET paralelo de cada NFO. `Future.wait` dispara todos os
    //    requests simultaneamente; tempo total ≈ 1 RTT (não N).
    final results = await Future.wait(
      episodeNumbers.map((n) async {
        final nfo = await fetchEpisodeNfo(seasonUrl, n);
        return MapEntry(
          n,
          nfo ??
              (
                season: null,
                episode: n,
                title: null,
                plot: null
              ),
        );
      }),
    );
    return Map.fromEntries(results);
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
    'poster', 'cover', 'folder', 'tvshow-poster',
  };
  static const Set<String> _showFanartNames = {
    'fanart', 'backdrop', 'banner', 'tvshow-banner',
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
  // Episode thumb scraper
  // ============================================================

  /// GET listing HTML da season → extrai `S\d+E(\d+)-thumb.{ext}`.
  ///
  /// Retorna `Map<int episodeNumber, String thumbUrl>`. Dedup automático
  /// por episode number (`001` → `1`); em caso de duplicata, o primeiro
  /// match no listing vence.
  ///
  /// Retorna map vazio em qualquer falha (404, 500, timeout, parse fail).
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
      String htmlBody, String seasonUrl) {
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
