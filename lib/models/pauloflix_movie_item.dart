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

  const PauloFlixMovieRaw({
    required this.folderName,
    required this.folderUrl,
    required this.type,
    this.videoFile,
    this.subfolders = const [],
  });

  factory PauloFlixMovieRaw.single({
    required String folderName,
    required String folderUrl,
    required PauloFlixMovieFile videoFile,
  }) {
    return PauloFlixMovieRaw(
      folderName: folderName,
      folderUrl: folderUrl,
      type: MovieFolderType.single,
      videoFile: videoFile,
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
