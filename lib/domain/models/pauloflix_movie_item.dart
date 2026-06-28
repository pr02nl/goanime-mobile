/// Metadados de uma legenda individual: arquivo externo (.srt) no servidor
/// PauloFlix.
///
/// Cada instância corresponde a UM arquivo `.srt` encontrado na pasta do filme,
/// ou vindo do campo `subtitles` do `movie_index.json`.
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
