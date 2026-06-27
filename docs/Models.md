# 📦 Modelos de Dados - Documentação

> **Persistência:** Drift com 7 tabelas. `genres` é **JSON serializado** (não CSV).
> Ver `docs/Services.md` para a arquitetura completa.

## Jikan API Models

### JikanAnime

Modelo principal de anime da Jikan API (usado apenas pela Home/Busca externa).

```dart
class JikanAnime {
  final int malId;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final String imageUrl;          // WebP preferido
  final String? largImageUrl;
  final String? synopsis;
  final double? score;
  final int? episodes;
  final String? status;
  final String? rating;
  final List<JikanGenre> genres;
  final int? year;
  final String? season;
}
```

### JikanResponse<T>, JikanPagination, JikanGenreIds
Wrapper de resposta paginada. IDs de gêneros (Action=1, Adventure=2, Comedy=4, etc.)

---

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
> - `fromJikan()` — legado (não usado no sync principal)
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
  final int? malId;               // MyAnimeList ID
  final int? anilistId;           // AniList ID
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
- `original_title`, `year`, `tmdb_id`, `mal_id`, `anilist_id`
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

Modelo de filme PauloFlix (pode ser filme individual ou coleção).

> **Fábricas:**
> - `fromMovieIndex()` — fonte **primária** (JSON index)
> - `fromNfo()` — fallback (Kodi NFO)
> - `fromTmdb()` — legado (não usado no sync principal)
> - `fromMap()` — desserialização do banco

```dart
class PauloFlixMovie {
  final int? id;
  final String folderName;
  final String displayName;
  final String serverUrl;
  final String? imageUrl, bannerUrl, description;
  final double? score;
  final List<String> genres;
  final String? releaseDate;
  final int? runtime, year, tmdbId;
  final bool isCollection;
  final int availableMovieCount;
  final DateTime lastSynced;
  final bool isAvailable;
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
- `is_collection`, `available_movie_count`

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

### HomeData (JikanService)
```dart
class HomeData {
  final List<JikanAnime> seasonAnimes, topAnimes;
  final List<JikanAnime> actionAnimes, romanceAnimes, comedyAnimes, fantasyAnimes;
  final DateTime loadedAt;
  bool get isExpired => difference > 30 min;
}
```
