/// Um único filme de vídeo dentro do PauloFlix Movies.
///
/// Usado dentro de coleções (sub-pastas) ou retornado pela inspeção
/// de uma pasta que contém um vídeo solto (.mkv/.mp4).
class PauloFlixMovieFile {
  final String folderName;
  final String folderUrl;
  final String videoFileName;
  final String videoUrl;
  final int? year;
  final String cleanedName;

  /// Lista de legendas opcionais para esta pasta, ordenadas por prioridade
  /// (PT-BR primeiro). Vazio se a pasta não tiver nenhum `.srt` — mesmo
  /// assim, o MKV pode ter legendas embutidas que serão listadas pelo
  /// `media_kit` em runtime.
  final List<SubtitleTrackInfo> subtitles;

  /// Legenda principal (a primeira da lista [subtitles], ou null se vazio).
  /// Mantida por compatibilidade com código legado que só esperava uma.
  String? get subtitleUrl =>
      subtitles.isNotEmpty ? subtitles.first.url : null;

  /// Idioma inferido da legenda principal.
  String? get subtitleLanguage =>
      subtitles.isNotEmpty ? subtitles.first.language : null;

  const PauloFlixMovieFile({
    required this.folderName,
    required this.folderUrl,
    required this.videoFileName,
    required this.videoUrl,
    required this.cleanedName,
    this.year,
    this.subtitles = const [],
  });

  @override
  String toString() =>
      'PauloFlixMovieFile(folderName: $folderName, video: $videoFileName'
      ', ${subtitles.length} subtitle(s))';
}

/// Metadados de uma legenda individual: arquivo externo (.srt) no servidor
/// PauloFlix.
///
/// É uma estrutura "leve" —cada instância corresponde a UM arquivo `.srt`
/// encontrado na pasta do filme. A Api do `media_kit` aceita apenas uma
/// legenda ativa por vez via [Player.setSubtitleTrack], então o player vai
/// mesclar essas tracks externas com as embutidas do MKV em runtime.
class SubtitleTrackInfo {
  /// URL absoluta do arquivo `.srt` no servidor.
  final String url;

  /// Idioma inferido (e.g. `"pt-BR"`, `"en"`). Default é `"pt-BR"` quando
  /// não identificado.
  final String language;

  /// Rótulo amigável para UI, ex: "Português (Brasil)" ou "Inglês".
  final String displayName;

  /// Tipo de legenda: regular ou forced (forced subs = aparecem mesmo
  /// com faixa principal desabilitada).
  final bool forced;

  const SubtitleTrackInfo({
    required this.url,
    required this.language,
    required this.displayName,
    this.forced = false,
  });

  @override
  String toString() =>
      'SubtitleTrackInfo($language, ${forced ? "forced, " : ""}$url)';
}

/// Sub-pasta encontrada dentro de uma coleção.
/// Uma entrada de legenda externa do JSON index do PauloFlix Movies.
///
/// Diferente de [SubtitleTrackInfo], esta é a representação **bruta**
/// vinda do `movie_index.json`:
///
/// ```json
/// {"file": "/movies/.../sub.srt", "lang": "pob", "name": "sub.srt"}
/// ```
///
/// O campo [file] já é uma **URL absoluta** resolvida por
/// `PauloFlixMovie.fromMovieIndex()` (baseHost + path relativo).
class ExternalSubtitleEntry {
  /// URL absoluta do arquivo `.srt`.
  final String file;

  /// Código de idioma do servidor (ex: `"pob"`, `"eng"`, `"pt"`).
  final String lang;

  /// Nome amigável do arquivo (ex: `"sub.srt"`).
  final String name;

  const ExternalSubtitleEntry({
    required this.file,
    required this.lang,
    required this.name,
  });

  Map<String, dynamic> toJson() => {'file': file, 'lang': lang, 'name': name};

  factory ExternalSubtitleEntry.fromJson(Map<String, dynamic> json) {
    return ExternalSubtitleEntry(
      file: json['file'] as String,
      lang: json['lang'] as String,
      name: json['name'] as String,
    );
  }

  @override
  String toString() => 'ExternalSubtitleEntry($lang, $name)';
}

class PauloFlixMovieSubfolder {
  final String name;
  final String url;

  const PauloFlixMovieSubfolder({required this.name, required this.url});
}

/// Resultado da inspeção de uma pasta do `/movies/`.
enum MovieFolderType { single, collection, empty }

class PauloFlixMovieRaw {
  final String folderName;
  final String folderUrl;
  final MovieFolderType type;
  final PauloFlixMovieFile? videoFile;
  final List<PauloFlixMovieSubfolder> subfolders;

  /// Nome do arquivo `poster.jpg` (ou similar) na pasta, se existir.
  /// Pode ser diferente de `movie.nfo`'s `<thumb aspect="poster">` —
  /// esta é a versão **física** (arquivo de verdade no disco).
  ///
  /// **Por que ambos?** O `movie.nfo` pode ter `<thumb>` apontando para
  /// um path (relativo ou absoluto) ou omitir o thumb. Independente do
  /// NFO, o `poster.jpg` ao lado do `.mp4` é fonte de verdade.
  ///
  /// O `PauloFlixMovie.fromNfo` (e o TMDB fallback) usa isso como
  /// **fallback** quando o NFO não tem `imageUrl` populado.
  final String? posterFileName;

  /// Nome do arquivo `fanart.jpg` (ou `banner.jpg`) na pasta, se existir.
  /// Mesmo rationale do [posterFileName].
  final String? fanartFileName;

  /// URL absoluta do `poster.jpg` resolvida. `null` se não existir.
  String? get posterUrl => posterFileName == null
      ? null
      : '${folderUrl.endsWith('/') ? folderUrl : '$folderUrl/'}${Uri.encodeComponent(posterFileName!)}';

  /// URL absoluta do `fanart.jpg`/`banner.jpg` resolvida. `null` se não existir.
  String? get fanartUrl => fanartFileName == null
      ? null
      : '${folderUrl.endsWith('/') ? folderUrl : '$folderUrl/'}${Uri.encodeComponent(fanartFileName!)}';

  const PauloFlixMovieRaw({
    required this.folderName,
    required this.folderUrl,
    required this.type,
    this.videoFile,
    this.subfolders = const [],
    this.posterFileName,
    this.fanartFileName,
  });

  factory PauloFlixMovieRaw.single({
    required String folderName,
    required String folderUrl,
    required PauloFlixMovieFile videoFile,
    String? posterFileName,
    String? fanartFileName,
  }) {
    return PauloFlixMovieRaw(
      folderName: folderName,
      folderUrl: folderUrl,
      type: MovieFolderType.single,
      videoFile: videoFile,
      posterFileName: posterFileName,
      fanartFileName: fanartFileName,
    );
  }

  factory PauloFlixMovieRaw.collection({
    required String folderName,
    required String folderUrl,
    required List<PauloFlixMovieSubfolder> subfolders,
  }) {
    return PauloFlixMovieRaw(
      folderName: folderName,
      folderUrl: folderUrl,
      type: MovieFolderType.collection,
      subfolders: subfolders,
    );
  }

  factory PauloFlixMovieRaw.empty({
    required String folderName,
    required String folderUrl,
  }) {
    return PauloFlixMovieRaw(
      folderName: folderName,
      folderUrl: folderUrl,
      type: MovieFolderType.empty,
    );
  }
}
