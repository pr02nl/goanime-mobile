# 📦 Modelos de Dados - Documentação

> **⚠️ Nota sobre persistência:** os modelos `PauloFlixContent`, `PauloFlixMovie`,
> `WatchlistAnime` e `DownloadItem` são os **modelos de domínio**
> consumidos pelos 4 repositories (Fase 3). A serialização em SQLite
> (Drift) usa tipos nativos: `genres` é **JSON** (não CSV), datas
> como `DateTimeColumn` (Drift converte para INTEGER epoch-seconds
> automaticamente), enums `DownloadStatus`/`DownloadQuality` via
> `intEnum<>`. Ver `docs/DATABASE_REFACTORING.md`.

## Jikan API Models

### JikanAnime
Modelo principal de anime da Jikan API.

```dart
class JikanAnime {
  final int malId;              // ID do MyAnimeList
  final String title;           // Título principal
  final String? titleEnglish;   // Título em inglês
  final String? titleJapanese;  // Título em japonês
  final String imageUrl;        // URL da imagem (WebP preferido)
  final String? largImageUrl;   // URL da imagem grande
  final String? synopsis;       // Sinopse
  final double? score;          // Nota média (0-10)
  final int? episodes;        // Número de episódios
  final String? status;       // Status (Finished, Ongoing, etc)
  final String? rating;       // Classificação etária
  final List<JikanGenre> genres; // Lista de gêneros
  final int? year;              // Ano de lançamento
  final String? season;         // Estação (winter, spring, summer, fall)
}
```

**Prioridade de Imagens**: WebP > JPG (para melhor qualidade e compressão)

### JikanGenre
```dart
class JikanGenre {
  final int malId;    // ID do gênero
  final String name;  // Nome do gênero
  final String type;  // Tipo (anime/manga)
}
```

### JikanResponse<T>
Wrapper genérico para respostas paginadas.
```dart
class JikanResponse<T> {
  final List<T> data;
  final JikanPagination? pagination;
}
```

### JikanPagination
```dart
class JikanPagination {
  final int lastVisiblePage;
  final bool hasNextPage;
  final int currentPage;
}
```

### IDs de Gêneros
```dart
class JikanGenreIds {
  static const int action = 1;
  static const int adventure = 2;
  static const int comedy = 4;
  static const int drama = 8;
  static const int fantasy = 10;
  static const int horror = 14;
  static const int mystery = 7;
  static const int romance = 22;
  static const int sciFi = 24;
  static const int sliceOfLife = 36;
  static const int sports = 30;
  static const int supernatural = 37;
}
```

---

## AniList API Models

### AniListResponse
Wrapper da resposta GraphQL.
```dart
class AniListResponse {
  final MediaData data;
}
```

### MediaData
```dart
class MediaData {
  final MediaDetails media;
}
```

### MediaDetails
Modelo enriquecido de anime.
```dart
class MediaDetails {
  final int id;                 // ID AniList
  final int? idMal;             // ID MyAnimeList
  final MediaTitle title;       // Títulos em múltiplos idiomas
  final CoverImage coverImage;  // Imagens de capa
  final String? bannerImage;    // Imagem de banner
  final String? description;    // Descrição HTML
  final int? episodes;          // Número de episódios
  final String? status;         // Status
  final String? season;         // Estação
  final int? seasonYear;        // Ano da estação
  final double? averageScore;   // Score médio (0-100)
  final int? popularity;        // Ranking de popularidade
  final List<String> genres;    // Lista de gêneros (strings)
  final MediaFormat? format;    // Formato (TV, Movie, OVA, etc)
}
```

### MediaTitle
```dart
class MediaTitle {
  final String? romaji;   // Título em romaji
  final String? english;  // Título em inglês
  final String? native;   // Título em japonês
  
  String get preferred => english ?? romaji ?? native ?? 'Unknown';
}
```

### CoverImage
```dart
class CoverImage {
  final String? extraLarge;
  final String? large;
  final String? medium;
  final String? color;  // Cor predominante (hex)
  
  String get best => extraLarge ?? large ?? medium ?? '';
}
```

### MediaFormat (Enum)
```dart
enum MediaFormat {
  tv, tvShort, movie, special, ova, ona, 
  music, manga, novel, oneShot, unknown;
}
```

---

## AniSkip API Models

### SkipTimes
Container para tempos de skip.
```dart
class SkipTimes {
  final Skip? op;  // Opening
  final Skip? ed;  // Ending
  
  bool get hasSkipTimes => op != null || ed != null;
}
```

### Skip
Intervalo de tempo para pular.
```dart
class Skip {
  final double start;  // Tempo inicial (segundos)
  final double end;    // Tempo final (segundos)
  
  bool isInRange(double currentSeconds) {
    return currentSeconds >= start && currentSeconds <= end;
  }
}
```

### SkipInterval
```dart
class SkipInterval {
  final double startTime;
  final double endTime;
}
```

### SkipTimesResult
Resultado individual da API.
```dart
class SkipTimesResult {
  final SkipInterval interval;
  final String type;           // 'op' ou 'ed'
  final String episodeLength;  // Duração total do episódio
}
```

### SkipTimesResponse
Resposta completa da API.
```dart
class SkipTimesResponse {
  final bool found;           // Se encontrou skip times
  final List<SkipTimesResult> results;
  final String message;
  final int statusCode;
  
  SkipTimes toSkipTimes();  // Converte para modelo interno
}
```

---

## Modelos Internos

### Anime (Main.dart)
Modelo principal unificado do app.
```dart
class Anime {
  final String name;              // Nome do anime
  final String url;               // URL da fonte
  final String? fallbackImageUrl; // Imagem de fallback
  MediaDetails? aniListData;      // Dados do AniList
  bool isLoadingAniList = false;  // Flag de carregamento
  
  // Getters derivados
  String get imageUrl => aniListData?.coverImage.best ?? fallbackImageUrl ?? '';
  String get bannerUrl => aniListData?.bannerImage ?? '';
  String get description => aniListData?.description ?? '';
  int? get malId => aniListData?.idMal;
  int? get anilistId => aniListData?.id;
  List<String> get genres => aniListData?.genres ?? [];
  String? get status => aniListData?.status;
  int? get episodeCount => aniListData?.episodes;
  double? get averageScore => aniListData?.averageScore;
}
```

### AnimeSource (Enum)
```dart
enum AnimeSource { animeFire }
```

### Episode
```dart
class Episode {
  final String number;      // Número/identificador do episódio
  final String url;         // URL para acessar o episódio
  final String? thumbnail;    // Thumbnail do episódio
  final String? title;        // Título do episódio
  final String? description;  // Descrição do episódio
}
```

### StreamEpisodeListItem
Versão enriquecida de episódio.
```dart
class StreamEpisodeListItem {
  final String episodeNumber;
  final String? thumbnailUrl;
  final String? title;
  final String? description;
  final String? url;
  final Duration? duration;
  final DateTime? airDate;
  
  Episode toEpisode();  // Converte para Episode básico
}
```

### VideoData
```dart
class VideoData {
  final String src;    // URL do vídeo
  final String label;  // Label da qualidade (eg: "720p")
}
```

### VideoResponse
```dart
class VideoResponse {
  final List<VideoData> data;        // Lista de URLs de vídeo
  final Map<String, dynamic> resposta; // Metadados adicionais
}
```

### VideoStreamResult
Resultado processado de streaming.
```dart
class VideoStreamResult {
  final String url;
  final Map<String, String> headers;
  final bool isGoogleVideo;
  
  bool get hasHeaders => headers.isNotEmpty;
}
```

---

### PauloFlixContent

Modelo de conteúdo PauloFlix (animes do file server) com metadados do Jikan.

> **Persistência (Fase 3):** `genres` agora é **JSON serializado** (não
> CSV), preservando vírgulas dentro de nomes de gênero como "Slice of Life"
> e "Action, Adventure". Drift `TextColumn` `genres_json`. Ver
> `lib/core/utils/genre_codec.dart`.

```dart
class PauloFlixContent {
  final int? id;
  final String folderName;        // Nome da pasta no servidor
  final String displayName;       // Nome formatado para exibição
  final String serverUrl;         // URL completa no servidor
  final String? imageUrl;         // URL da imagem (do Jikan)
  final String? bannerUrl;        // URL do banner (do Jikan)
  final String? description;      // Descrição (do Jikan)
  final double? score;            // Score (do Jikan)
  final List<String> genres;      // Gêneros (do Jikan)
  final String? status;           // Status (do Jikan)
  final int? episodeCount;        // Número de episódios (do Jikan)
  final int? malId;               // MAL ID (do Jikan)
  final int? anilistId;           // AniList ID (do Jikan)
  final DateTime lastSynced;      // Última sincronização
  final bool isAvailable;         // Se o conteúdo ainda está disponível
}
```

### Fábricas

#### `PauloFlixContent.fromJikan()`
Cria a partir de dados do Jikan.

#### `PauloFlixContent.fromMap()`
Cria a partir de Map (do banco).

### Métodos

#### `toMap()`
Converte para Map para persistência.

---

## Modelos de Persistência

### WatchlistAnime

> **Persistência:** tabela `watchlist_items` (Drift). Coluna `addedAt` é
> `DateTimeColumn` (Drift converte para INTEGER epoch-seconds). Removido
> da Fase 1 o banco legado `watchlist.db` (sqlite3 FFI). O `WatchlistNotifier`
> foi removido na Fase 4 (substituído pelo `Stream<List<WatchlistAnime>>`
> do `WatchlistRepository`).
```dart
class WatchlistAnime {
  final int? id;              // ID local (SQLite)
  final String animeId;       // ID do anime (MyAnimeList)
  final String title;         // Título
  final String coverImage;    // URL da capa
  final String myAnimeListUrl; // URL do MyAnimeList
  final DateTime addedAt;     // Data de adição
}
```

### DownloadItem

> **Persistência (Fase 3):** tabela `downloads` (Drift) com colunas
> `downloadId` UNIQUE, `quality`/`status` como `intEnum<>` (mapeados dos
> enums em `core/database/tables/downloads.dart`). Campos `progress`/
> `bytesDownloaded`/`totalBytes` têm `withDefault(0)`. Datas
> `createdAt`/`completedAt` são `DateTimeColumn` (Drift converte para
> INTEGER epoch-seconds). O `DownloadService` (fila HTTP) agora usa
> `DownloadsRepository` por trás — Fase 4 mantém um ctor legado como
> fallback de segurança.
```dart
class DownloadItem {
  final String id;                    // ID único (animeId_episodeNumber)
  final String animeId;               // ID do anime
  final String animeName;             // Nome do anime
  final String episodeNumber;         // Número do episódio
  final String episodeTitle;          // Título do episódio
  final String videoUrl;              // URL do vídeo
  final String thumbnailUrl;          // URL da thumbnail
  final DownloadQuality quality;      // Qualidade solicitada
  DownloadStatus status;              // Status atual
  double progress;                    // Progresso (0.0 - 1.0)
  int bytesDownloaded;                // Bytes baixados
  int totalBytes;                     // Total de bytes
  String? filePath;                   // Caminho do arquivo local
  String? error;                      // Mensagem de erro (se falhou)
  final DateTime createdAt;           // Data de criação
  DateTime? completedAt;              // Data de conclusão
}
```

### Enums de Download
```dart
enum DownloadStatus {
  queued, downloading, paused, 
  completed, failed, cancelled
}

enum DownloadQuality {
  auto, low, medium, high
}
```

---

## Modelos de Cache

### HomeData (JikanService)
```dart
class HomeData {
  final List<JikanAnime> seasonAnimes;
  final List<JikanAnime> topAnimes;
  final List<JikanAnime> actionAnimes;
  final List<JikanAnime> romanceAnimes;
  final List<JikanAnime> comedyAnimes;
  final List<JikanAnime> fantasyAnimes;
  final DateTime loadedAt;
  
  bool get isExpired => DateTime.now().difference(loadedAt).inMinutes > 30;
}
```

### _CacheEntry<T> (JikanService - interno)
```dart
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  
  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 30;
}
```
