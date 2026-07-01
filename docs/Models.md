# 📦 Modelos de Dados - Documentação

> **Persistência:** Drift com 7 tabelas. `genres` é **JSON serializado** (não CSV).
> Ver `docs/Services.md` para a arquitetura completa.

> ~~Jikan API Models~~ foram removidos.

## AniList API Models

### MediaDetails
```dart
class MediaDetails {
  final int id;                   // ID AniList
  final int? idMal;               // ID MyAnimeList
  final MediaTitle title;         // romaji, english, native
  final CoverImage coverImage;    // best = extraLarge ?? large ?? medium
  final String? bannerImage;
  final String? description;
  final int? episodes;
  final String? status, season;
  final int? seasonYear;
  final double? averageScore;
  final int? popularity;
  final List<String> genres;
  final MediaFormat? format;
}
```

---

## Modelos Internos

### Anime
Modelo unificado para animes externos (não PauloFlix).
```dart
class Anime {
  final String name, url;
  final String? fallbackImageUrl;
  MediaDetails? aniListData;
  // Getters: imageUrl, bannerUrl, description, malId, anilistId, genres...
}
```

### Episode
```dart
class Episode {
  final String number, url;
  final String? thumbnail, title, description, subtitleUrl;
}
```

---

## PauloFlixContent

Modelo de conteúdo PauloFlix (TV shows do file server).

> **Fábricas:**
> - `fromTvIndex()` — fonte **primária** (JSON index do servidor)
> - `fromNfo()` — fallback (Kodi NFO, usado pelo NfoEnricher)
> - `fromMap()` — desserialização do banco Drift

```dart
class PauloFlixContent {
  final int? id;
  final String folderName;        // Nome da pasta no servidor (path no JSON index)
  final String displayName;       // Nome formatado para exibição
  final String serverUrl;         // URL completa no servidor
  final String? imageUrl;         // Poster (do JSON index ou NFO)
  final String? bannerUrl;        // Fanart/banner (do JSON index ou NFO)
  final String? description;      // Descrição
  final double? score;            // Rating
  final List<String> genres;      // Gêneros (JSON no banco)
  final String? status;           // Status (Finished, Ongoing...)
  final int? episodeCount;
  final String? originalTitle;    // Título original (NFO V2)
  final int? year;                // Ano de estreia
  final int? tmdbId;              // TMDB ID
  final DateTime lastSynced;
  final bool isAvailable;
}
```

### fromTvIndex (JSON)
O JSON index (`tv_index.json`) contém todos os metadados pré-resolvidos:
```dart
factory PauloFlixContent.fromTvIndex({
  required Map<String, dynamic> json,
  required String baseHost,
});
```
- `path` → `folderName`
- `title` → `displayName`
- `poster` / `fanart` → URLs absolutas via `baseHost`
- `genre` (array) → `genres`
- `original_title`, `year`, `tmdb_id`
- `episode_count`, `rating`, `status`

### fromNfo (Kodi)
Fallback para quando o servidor tem NFO mas não há JSON index:
```dart
factory PauloFlixContent.fromNfo({
  required String folderName, String serverUrl,
  required KodiShowNfo nfo,
  String? fallbackPosterUrl, String? fallbackFanartUrl,
});
```

---

## PauloFlixMovie

Modelo de filme PauloFlix. Cada filme é individual (não há mais coleções).
A URL direta do vídeo vem do campo `file` do JSON index, eliminando
qualquer necessidade de scraping HTML.

> **Fábricas:**
> - `fromMovieIndex()` — fonte **primária** (JSON index)
> - `fromNfo()` — fallback (Kodi NFO)
> - `fromTmdb()` — legado (não usado no sync principal)
> - `fromMap()` — desserialização do banco

```dart
class PauloFlixMovie {
  final int? id;
  final String folderName;          // path no JSON index
  final String displayName;         // title
  final String serverUrl;           // URL da pasta no servidor
  final String? imageUrl;           // Poster (resolvido via baseHost)
  final String? bannerUrl;          // Fanart
  final String? description;
  final double? score;              // rating
  final List<String> genres;        // JSON array no banco
  final String? releaseDate;
  final int? runtime, year, tmdbId;
  final int availableMovieCount;
  final DateTime lastSynced;
  final bool isAvailable;

  /// URL direta do vídeo, do campo `file` do `movie_index.json`.
  final String? videoUrl;

  /// Legendas externas do campo `subtitles` do JSON index.
  /// Cada [ExternalSubtitleEntry] já tem URL absoluta.
  final List<ExternalSubtitleEntry>? subtitles;
}
```

### fromMovieIndex (JSON)
```dart
factory PauloFlixMovie.fromMovieIndex({
  required Map<String, dynamic> json,
  required String baseHost,
});
```
- `path` → `folderName`
- `title`, `description`, `poster`, `fanart`, `genres[]`
- `year`, `release_date`, `runtime`, `tmdb_id`
- **`file`** → `videoUrl` (URL absoluta via `baseHost`)
- **`subtitles[]`** → `subtitles` (cada `file` resolvido para URL absoluta)
- `available_movie_count`

### ExternalSubtitleEntry
Representação bruta de legenda vinda do `movie_index.json`:
```dart
class ExternalSubtitleEntry {
  final String file;  // URL absoluta do .srt (resolvida em fromMovieIndex)
  final String lang;  // Código do servidor: "pob", "eng", "spa"...
  final String name;  // Nome do arquivo: "sub.srt"
}
```
Conteúdo do `movie_index.json`:
```json
{"file": "/movies/.../sub.srt", "lang": "pob", "name": "sub.srt"}
```
A resolução para `SubtitleTrackInfo` (usado pelo player) é feita na
`_resolveSubtitlesFromJson()` do `PauloFlixMovieDetailScreen`, que mapeia
`pob` → `pt-BR`, `eng` → `en`, etc.

---

## Modelos de Persistência

### WatchlistAnime
```dart
class WatchlistAnime {
  final int? id;
  final String animeId, title, coverImage, myAnimeListUrl;
  final DateTime addedAt;
}
```
Persistência: tabela `watchlist_items` (Drift). Reatividade via `Stream<List<WatchlistAnime>>`.

### DownloadItem
```dart
class DownloadItem {
  final String id, animeId, animeName, episodeNumber, episodeTitle;
  final String videoUrl, thumbnailUrl;
  final DownloadQuality quality;
  DownloadStatus status;
  double progress;
  int bytesDownloaded, totalBytes;
  String? filePath, error;
  final DateTime createdAt;
  DateTime? completedAt;
}
```
Persistência: tabela `downloads` (Drift). Gerenciado pelo `DownloadService` + `DownloadsRepository`.

```dart
enum DownloadStatus { queued, downloading, paused, completed, failed, cancelled }
enum DownloadQuality { auto, low, medium, high }
```

### PauloFlixSeason / PauloFlixEpisode (episode progress)
```dart
class PauloFlixSeason {
  final String name, url;
  final int number;
}

class PauloFlixEpisode {
  final int number;
  final String title, url;
  final int? fileSize;
}
```
Persistência: tabelas `paulo_flix_seasons` e `paulo_flix_episodes` (Drift).
Progresso do usuário: tabela `episode_progress`.

---

## Modelos NFO (Kodi)

```dart
class KodiShowNfo {
  final String? title, plot, posterThumb, bannerThumb, fanartThumb;
  final List<String> genres;
  final int? year;
  final double? rating;
}

class KodiEpisodeNfo {  // schema V2
  final int? seasonNumber, episodeNumber, runtime;
  final String? title, originalTitle, plot, outline;
  final DateTime? aired;
  final double? rating;
}

class KodiSeasonNfo {
  final int? seasonNumber;
  final String? plot, posterThumb;
}
```

---

## Modelos de Cache


