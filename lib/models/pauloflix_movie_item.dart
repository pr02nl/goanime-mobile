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

  /// URL absoluta da legenda `.srt` encontrada na mesma pasta, se houver.
  /// O arquivo é detectado por nome compatível (e.g. `filme.eng.srt`,
  /// `filme.pob.srt`, `filme.pt-BR.srt`) — preferência por `.pob`
  /// (Português Brasil) e fallback por `.srt` único.
  final String? subtitleUrl;

  /// Idioma inferido da legenda (e.g. `"pt-BR"`, `"en"`).
  final String? subtitleLanguage;

  const PauloFlixMovieFile({
    required this.folderName,
    required this.folderUrl,
    required this.videoFileName,
    required this.videoUrl,
    required this.cleanedName,
    this.year,
    this.subtitleUrl,
    this.subtitleLanguage,
  });

  @override
  String toString() =>
      'PauloFlixMovieFile(folderName: $folderName, video: $videoFileName'
      '${subtitleUrl != null ? ", with subtitle" : ""})';
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
