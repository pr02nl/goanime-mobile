/// Parser puro (sem Flutter) para arquivos NFO do Kodi.
///
/// Fonte: plano `.hermes/plans/2026-06-23_224213-pauloflix-nfo-enrichment.md` (Fase 1).
///
/// **Garantia de robustez:** todos os métodos públicos (`parseShow`,
/// `parseMovie`, `parseEpisode`) envolvem o parse em `try`/`catch` e
/// retornam `null` em qualquer falha (XML inválido, root mismatch, erro
/// genérico). NUNCA propagam exceção — o fluxo sempre cai pro fallback
/// Jikan/TMDB.
///
/// **Raízes suportadas:**
/// - `parseShow` espera `<tvshow>` (tvshow.nfo).
/// - `parseMovie` espera `<movie>` (movie.nfo).
/// - `parseEpisode` espera `<episodedetails>` (episodedetails.nfo).
library;

import 'package:xml/xml.dart';

import 'kodi_nfo_models.dart';

/// Record Dart 3 para o retorno de `parseEpisode`.
///
/// **Fase N+7扩e:** agora alias de `KodiEpisodeNfo` (que tem os 5
/// novos campos V2: `originalTitle`, `outline`, `aired`, `rating`,
/// `runtime`). Era um record inline com só 4 campos (season,
/// episode, title, plot) — incompatível com o schema V2 do NFO.
/// Manter como `typedef` evita quebrar callers que importam
/// `EpisodeNfo` diretamente.
typedef EpisodeNfo = KodiEpisodeNfo;

/// Parser estático de NFOs Kodi.
class KodiNfoParser {
  // Construtor privado — classe não deve ser instanciada.
  const KodiNfoParser._();

  /// Faz parse de um `tvshow.nfo` (root `<tvshow>`).
  ///
  /// Retorna `KodiShowNfo?` populado, ou `null` em qualquer erro
  /// (XML inválido, root diferente de `<tvshow>`, etc).
  static KodiShowNfo? parseShow(String xmlBody) {
    return _parseRooted<KodiShowNfo>(
      xmlBody,
      expectedRoot: 'tvshow',
      builder: _buildShowFromRoot,
    );
  }

  /// Faz parse de um `movie.nfo` (root `<movie>`).
  ///
  /// Retorna `KodiShowNfo?` populado (mesma classe — show e movie
  /// compartilham estrutura), ou `null` em qualquer erro.
  static KodiShowNfo? parseMovie(String xmlBody) {
    return _parseRooted<KodiShowNfo>(
      xmlBody,
      expectedRoot: 'movie',
      builder: _buildShowFromRoot,
    );
  }

  /// Faz parse de um `episodedetails.nfo` (root `<episodedetails>`).
  ///
  /// Retorna um `KodiEpisodeNfo` (typedef `EpisodeNfo` é alias) com
  /// schema V2 completo: V1 (`season`, `episode`, `title`, `plot`,
  /// `thumb`) + V2 (`originalTitle`, `outline`, `aired`, `rating`,
  /// `runtime`). Todos opcionais — NFO pode ter só subset.
  ///
  /// Retorna `null` em qualquer erro (XML inválido, root mismatch).
  static KodiEpisodeNfo? parseEpisode(String xmlBody) {
    return _parseRooted<KodiEpisodeNfo>(
      xmlBody,
      expectedRoot: 'episodedetails',
      builder: (root) {
        return KodiEpisodeNfo(
          seasonNumber: _parseInt(_firstText(root, 'season')),
          episodeNumber: _parseInt(_firstText(root, 'episode')),
          title: _firstText(root, 'title'),
          originalTitle: _firstText(root, 'originaltitle'),
          plot: _firstText(root, 'plot'),
          outline: _firstText(root, 'outline'),
          aired: _parseDateTime(_firstText(root, 'aired')),
          rating: _parseDouble(_firstText(root, 'rating')),
          runtime: _parseInt(_firstText(root, 'runtime')),
          // thumb: episode NFO não usa thumb (o thumb vem de
          // S01E001-thumb.jpg no listing da season, separado).
        );
      },
    );
  }

  /// Faz parse de um `season.nfo` (root `<season>`).
  ///
  /// Campos parseados:
  /// - `seasonNumber` (de `<seasonnumber>`)
  /// - `plot` (de `<plot>`)
  /// - `posterThumb` (de `<thumb aspect="season">` ou `<thumb>`
  ///   sem aspect como fallback)
  ///
  /// **Preferência de thumb:** Kodi season NFO pode ter
  /// `<thumb>` (sem aspect, genérico) OU `<thumb aspect="season">`
  /// OU `<thumb aspect="poster">`. Preferência nesta ordem:
  /// 1. `<thumb aspect="season">` (mais específico)
  /// 2. `<thumb>` sem aspect (fallback genérico)
  /// 3. `<thumb aspect="poster">` (último recurso)
  ///
  /// Retorna `null` em qualquer falha (XML inválido, root mismatch).
  static KodiSeasonNfo? parseSeasonNfo(String xmlBody) {
    return _parseRooted<KodiSeasonNfo>(
      xmlBody,
      expectedRoot: 'season',
      builder: (root) {
        return KodiSeasonNfo(
          seasonNumber: _parseInt(_firstText(root, 'seasonnumber')),
          plot: _firstText(root, 'plot'),
          posterThumb: _seasonPosterThumb(root),
        );
      },
    );
  }

  // ============================================================
  // Internals
  // ============================================================

  /// Template para os 3 parsers. Centraliza o try/catch e a
  /// validação do root.
  ///
  /// - [xmlBody] é o XML cru (string).
  /// - [expectedRoot] é o nome da tag raiz esperada
  ///   (`tvshow`, `movie`, `episodedetails`).
  /// - [builder] é a função que constrói o DTO a partir do root
  ///   (já validado).
  ///
  /// Retorna `null` se:
  /// - O XML for inválido (`XmlException`).
  /// - Qualquer outra exceção for lançada.
  /// - O root for diferente de [expectedRoot] (root mismatch).
  static T? _parseRooted<T>(
    String xmlBody, {
    required String expectedRoot,
    required T Function(XmlElement root) builder,
  }) {
    try {
      final document = XmlDocument.parse(xmlBody);
      final root = document.rootElement;
      if (root.name.local != expectedRoot) {
        // Root mismatch (ex: parseMovie chamado em tvshow XML).
        return null;
      }
      return builder(root);
    } on XmlException {
      // XML inválido.
      return null;
    } on Exception {
      // Qualquer outra exceção inesperada — nunca propaga.
      return null;
    }
  }

  /// Constrói um `KodiShowNfo` a partir do elemento root (já validado).
  static KodiShowNfo _buildShowFromRoot(XmlElement root) {
    return KodiShowNfo(
      title: _firstText(root, 'title'),
      plot: _firstText(root, 'plot'),
      genres: _allTexts(root, 'genre'),
      year: _parseInt(_firstText(root, 'year')),
      rating: _parseDouble(_firstText(root, 'rating')),
      posterThumb: _thumbByAspect(root, 'poster'),
      bannerThumb: _thumbByAspect(root, 'banner'),
      fanartThumb: _thumbByAspect(root, 'fanart'),
    );
  }

  /// Retorna o `innerText` (trimmed) do primeiro elemento [tag] filho
  /// de [parent], ou `null` se não existir.
  static String? _firstText(XmlElement parent, String tag) {
    return parent
        .findElements(tag)
        .firstOrNull
        ?.innerText
        .trim();
  }

  /// Retorna a lista de `innerText` (trimmed) de todos os elementos
  /// [tag] filhos de [parent]. Strings vazias são filtradas.
  static List<String> _allTexts(XmlElement parent, String tag) {
    return parent
        .findElements(tag)
        .map((e) => e.innerText.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Retorna o `innerText` (trimmed) do primeiro `<thumb>` filho de
  /// [parent] cujo atributo `aspect` seja igual a [aspect], ou `null`
  /// se não existir.
  ///
  /// `<thumb>` sem atributo `aspect` é ignorado (decisão documentada
  /// nos testes de Task 1.4).
  static String? _thumbByAspect(XmlElement parent, String aspect) {
    for (final thumb in parent.findElements('thumb')) {
      final thumbAspect = thumb.getAttribute('aspect');
      if (thumbAspect == aspect) {
        return thumb.innerText.trim();
      }
    }
    return null;
  }

  /// Resolve o `posterThumb` de uma season NFO, considerando os 3
  /// formatos comuns do Kodi:
  /// 1. `<thumb aspect="season">season01.jpg</thumb>` (preferência)
  /// 2. `<thumb>season01.jpg</thumb>` (genérico, sem aspect)
  /// 3. `<thumb aspect="poster">poster.jpg</thumb>` (último recurso)
  ///
  /// Retorna `null` se nenhum `<thumb>` for encontrado.
  static String? _seasonPosterThumb(XmlElement parent) {
    final thumbs = parent.findElements('thumb').toList();
    if (thumbs.isEmpty) return null;

    // 1. aspect="season"
    for (final thumb in thumbs) {
      if (thumb.getAttribute('aspect') == 'season') {
        final text = thumb.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    // 2. sem aspect (genérico) — primeiro que tiver texto não vazio
    for (final thumb in thumbs) {
      if (thumb.getAttribute('aspect') == null) {
        final text = thumb.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    // 3. aspect="poster"
    for (final thumb in thumbs) {
      if (thumb.getAttribute('aspect') == 'poster') {
        final text = thumb.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  /// Tenta parsear [value] como `int`. Retorna `null` se for `null`,
  /// vazio, ou não for um inteiro válido.
  static int? _parseInt(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  /// Tenta parsear [value] como `double`. Retorna `null` se for `null`,
  /// vazio, ou não for um double válido.
  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }

  /// Tenta parsear [value] como `DateTime` no formato `YYYY-MM-DD`
  /// (Kodi `<aired>` standard).
  ///
  /// Retorna `null` se for `null`, vazio, ou formato inválido.
  /// **NÃO** faz fuzzy parsing (ex: `5-12-2021` ou timestamps
  /// completos) — só aceita o formato ISO `YYYY-MM-DD`. Valores
  /// fora do formato viram `null` (defensivo — não propagam erro).
  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
