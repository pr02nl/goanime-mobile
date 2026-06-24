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
/// Campos:
/// - `season`: número da season (vem de `<season>`).
/// - `episode`: número do episode (vem de `<episode>`).
/// - `title`: título do episode (vem de `<title>`).
/// - `plot`: sinopse (vem de `<plot>`).
typedef EpisodeNfo = ({int? season, int? episode, String? title, String? plot});

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
  /// Retorna um record Dart 3 `EpisodeNfo` populado, ou `null` em
  /// qualquer erro.
  static EpisodeNfo? parseEpisode(String xmlBody) {
    return _parseRooted<EpisodeNfo>(
      xmlBody,
      expectedRoot: 'episodedetails',
      builder: (root) {
        return (
          season: _parseInt(_firstText(root, 'season')),
          episode: _parseInt(_firstText(root, 'episode')),
          title: _firstText(root, 'title'),
          plot: _firstText(root, 'plot'),
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
}
