# 🌐 APIs Integradas - Documentação Detalhada

## 0. PauloFlix JSON Index (Fonte Única de Dados)

**Base URL:** `https://media.oliveira.braga.nom.br`

O JSON index é a **única fonte de dados** do PauloFlix. Todo o scraping HTML foi eliminado — os metadados, URLs de vídeo e legendas vêm exclusivamente dos arquivos `tv_index.json` e `movie_index.json`.

### Autenticação
Toda request injeta:
```
Authorization: Bearer <JWT_Ed25519>
```

---

### TV Shows Index
```
GET /tvshows/tv_index.json
```

Índice JSON de todos os shows. Substitui completamente o scraping HTML + Jikan API.

**Estrutura resumida:**
```json
{
  "updated_at": "2026-06-27T13:53:47Z",
  "total_shows": 27,
  "shows": [
    {
      "title": "DAN DA DAN",
      "original_title": "ダンダダン",
      "sort_title": "Dan Da Dan",
      "path": "Dan Da Dan",
      "year": "2024",
      "rating": 8.539,
      "plot": "...",
      "genre": ["Animação", "Action & Adventure"],
      "status": "Returning Series",
      "poster": "/tvshows/Dan Da Dan/poster.jpg",
      "fanart": "/tvshows/Dan Da Dan/fanart.jpg",
      "nfo": { ... },
      "seasons": [
        {
          "season": 1,
          "episodes": [
            {
              "episode": 1,
              "title": "É assim que o amor começa, tá ligado?",
              "plot": "...",
              "aired": "2024-10-04",
              "rating": 8.462,
              "file": "/tvshows/Dan Da Dan/Season%2001/S01E01.mkv",
              "thumb": "/tvshows/Dan Da Dan/Season%2001/S01E01-thumb.jpg",
              "nfo": { ... }
            }
          ]
        }
      ]
    }
  ]
}
```

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `title` | `string` | Título principal |
| `path` | `string` | Nome da pasta (identificador único) |
| `year` | `string` | Ano de lançamento |
| `rating` | `number` | Rating 0-10 |
| `plot` | `string` | Sinopse |
| `genre` | `string[]` | Array de gêneros |
| `status` | `string` | `"Returning Series"` / `"Ended"` |
| `poster` | `string` | Path relativo do poster |
| `fanart` | `string` | Path relativo do fanart |
| `seasons[].episodes[].file` | `string` | **URL relativa do vídeo** (resolvida com baseHost) |
| `seasons[].episodes[].thumb` | `string` | Thumbnail do episódio |
| `seasons[].episodes[].nfo` | `object` | Metadados Kodi NFO do episódio |
| `nfo` | `object` | Metadados Kodi NFO do show (rating, votes, etc.) |

---

### Movies Index
```
GET /movies/movie_index.json
```

Índice JSON de todos os filmes. Substitui completamente o scraping HTML + TMDB API. Cada filme é uma entry individual (sem coleções).

**Estrutura resumida:**
```json
{
  "updated_at": "2026-06-27T13:53:47Z",
  "total_movies": 348,
  "movies": [
    {
      "title": "2012",
      "original_title": "2012",
      "sort_title": "2012",
      "path": "2012 (2009)",
      "year": "2009",
      "rating": 5.9,
      "plot": "Bilhões de habitantes da Terra não estão cientes...",
      "genre": ["Ficção científica"],
      "director": "Roland Emmerich",
      "poster": "/movies/2012 (2009)/poster.jpg",
      "fanart": "/movies/2012 (2009)/fanart.jpg",
      "file": "/movies/2012 (2009)/2012.2009.Open.Matte.1080p.WEBRip.x265.10bit-KONTRAST.mp4",
      "subtitles": [
        { "file": "/movies/2012 (2009)/legenda.srt", "lang": "por", "name": "Português" },
        { "file": "/movies/2012 (2009)/legenda_eng.srt", "lang": "eng", "name": "English" }
      ],
      "nfo": { ... }
    }
  ]
}
```

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `title` | `string` | Título principal |
| `original_title` | `string` | Título original |
| `path` | `string` | Nome da pasta (identificador único) |
| `year` | `string` | Ano de lançamento |
| `rating` | `number` | Rating 0-10 |
| `plot` | `string` | Sinopse |
| `genre` | `string[]` | Array de gêneros |
| `director` | `string` | Diretor |
| `poster` | `string` | Path relativo do poster |
| `fanart` | `string` | Path relativo do fanart |
| `file` | `string?` | **URL relativa do vídeo** (resolvida com baseHost). `null` se indisponível |
| `subtitles` | `array?` | Legendas externas. Cada entry: `{ file, lang, name }`.
  - `file`: path relativo do `.srt`/`.vtt`
  - `lang`: código ISO 639-1 (`"por"`, `"eng"`, `"jpn"`)
  - `name`: nome legível (`"Português"`, `"English"`)
  `null` se o filme não tiver legendas externas |
| `nfo` | `object` | Metadados Kodi NFO (rating, runtime, studio, etc.) |

> **Nota:** Coleções foram eliminadas. Cada entry representa **um filme por pasta**. O campo `file` contém a URL direta do vídeo — sem necessidade de scraping on-demand.

---

## 1. AniList API (GraphQL)

**Uso:** Enriquecimento de metadados de animes (imagens, scores, sinopses).

### Base URL
```
https://graphql.anilist.co
```

### Queries GraphQL

#### Busca por Título
```graphql
query ($search: String) {
  Media(search: $search, type: ANIME) {
    id
    idMal
    title { romaji english native }
    coverImage { extraLarge large medium color }
    bannerImage
    description
    episodes
    status
    season
    seasonYear
    averageScore
    popularity
    genres
    format
  }
}
```

#### Busca por MAL ID / AniList ID
```graphql
query ($malId: Int) { Media(idMal: $malId, type: ANIME) { ... } }
query ($id: Int) { Media(id: $id, type: ANIME) { ... } }
```

### Limpeza de Títulos
Remove tags como `[AnimeFire]`, indicadores de idioma, sufixos de episódios/temporadas.

---

## 3. TheIntroDB API

**Uso:** Pular intro/outro automaticamente no player de vídeo.

### Base URL
```
https://api.theintrodb.org/v3
```

### Endpoint
```
GET /v3/media?tmdb_id={tmdb_id}&season_number={season_number}&episode_number={episode_number}
```

### Funcionalidades
- Cache em memória (respostas por `tmdbId`)
- Suporte a séries (TV) com `season_number` e `episode_number`
- Retorna segmentos de intro, créditos, recap e preview
- Timeout de 10s por requisição

---

## 4. TMDB API (The Movie Database)

**Uso:** **Não é mais usado no sync principal de filmes** (substituído pelo JSON index). Mantido como fallback para busca manual e compatibilidade.

### Base URL
```
https://api.themoviedb.org/3
```

### Autenticação
API Key v3 configurada pelo usuário em Settings → API Keys. Enviada via `Authorization: Bearer`.

### Endpoints
```
GET /search/movie?query={title}&language=pt-BR
GET /movie/{id}?language=pt-BR
```

---

## 5. AnimeFire (Streaming)

**Uso:** Fonte de streaming de episódios (URLs de vídeo).

### Base URL
```
https://animefire.plus
```

---

## 6. Repositórios de Progresso (Internos — Drift)

Os repositórios de progresso são **interfaces internas** implementadas
sobre Drift (SQLite). A UI consome métodos assíncronos e streams
reativos para exibir overlays de progresso nos cards sem polling.

---

### PauloFlixEpisodeProgressRepository (Animes)

**Arquivo:** `lib/domain/repositories/paulo_flix_episode_progress_repository.dart`

Responsável pelo progresso de episódios de animes (com seasons e múltiplos
episódios por temporada).

#### `getStatsForContent(int contentId)`
```dart
Future<PauloFlixProgressStats> getStatsForContent(int contentId);
```

Estatísticas agregadas de UM anime. Única query SQL com `COUNT(*)`
e `SUM(CASE ...)` nas tabelas `paulo_flix_episodes` +
`paulo_flix_seasons`. Retorna `PauloFlixProgressStats` com zeros
se o anime ainda não tem episódios sincronizados.

#### `getProgressStatsForContents(List<int> contentIds)` ⭐
```dart
Future<Map<int, PauloFlixProgressStats>> getProgressStatsForContents(
  List<int> contentIds,
);
```

**Batch** — estatísticas de múltiplos animes em UMA query apenas, usando
`IN` clause parametrizado (`?1, ?2, ...`). Retorna mapa `contentId → stats`.
Usado pela seção "Continue assistindo" e tela See All para exibir overlays
nos cards sem N queries individuais.

#### `getInProgressContents({int limit = 12})`
```dart
Future<List<PauloFlixContent>> getInProgressContents({int limit = 12});
```

Lista animes com progresso em andamento, ordenados por `lastWatched DESC`.
Filtra: `positionSeconds > 0 && !isCompleted`.

#### `watchInProgressContents({int limit = 12})`
```dart
Stream<List<PauloFlixContent>> watchInProgressContents({int limit = 12});
```

**Stream reativa** da lista de animes em andamento. Aciona ao
adicionar/resetar/assistir episódios. Usado pelo carrossel "Continue
assistindo" da home para atualizar sem polling.

#### `updateProgress(...)`
```dart
Future<void> updateProgress({
  required int seasonId,
  required int episodeNumber,
  required int positionSeconds,
  int? durationSeconds,
});
```

Grava progresso do episódio. Se `positionSeconds / durationSeconds >= 0.9`,
marca `episode.isCompleted = true` e recalcula `season.isCompleted`
(cascade). Chamado pelo player a cada 5s + no dispose.

---

### PauloFlixMovieProgressRepository (Filmes)

**Arquivo:** `lib/domain/repositories/paulo_flix_movie_progress_repository.dart`

Responsável pelo progresso de filmes (1 progresso por `folderName`, sem
seasons/episódios).

#### `updateProgress(...)`
```dart
Future<void> updateProgress({
  required String folderName,
  required String serverUrl,
  required String displayName,
  String? imageUrl,
  String? videoUrl,
  required int positionSeconds,
  int? durationSeconds,
});
```

Grava progresso do filme. Se `positionSeconds / durationSeconds >= 0.9`,
marca `isCompleted = true`. Se o record não existe, cria com metadados.

#### `getAllProgress()`
```dart
Future<List<PauloFlixMovieProgressRecord>> getAllProgress();
```

Retorna TODO progresso salvo (em andamento + completo), sem limite.
Usado pela home de filmes para construir o mapa `folderName → progress`
e exibir overlays nos cards.

#### `watchAllProgress()` ⭐
```dart
Stream<List<PauloFlixMovieProgressRecord>> watchAllProgress();
```

**Stream reativa** de TODO progresso salvo. Aciona ao
adicionar/resetar/assistir filmes. Usado pela home de filmes para
manter os overlays dos cards atualizados reativamente.

#### `getInProgressMovies({int limit = 12})`
```dart
Future<List<PauloFlixMovieProgressRecord>> getInProgressMovies({
  int limit = 12,
});
```

Lista filmes em andamento, ordenados por `lastWatched DESC`.
Filtra: `positionSeconds > 0 && !isCompleted`.

#### `watchInProgressMovies({int limit = 12})`
```dart
Stream<List<PauloFlixMovieProgressRecord>> watchInProgressMovies({
  int limit = 12,
});
```

**Stream reativa** da lista de filmes em andamento. Usado pelo carrossel
"Continue assistindo" de filmes.

---

## 📊 Resumo de APIs

| API | Protocolo | Uso Principal | Cache |
|-----|-----------|---------------|-------|
| PauloFlix JSON Index (TV) | HTTPS | Sync de shows (fonte primária) | Drift |
| PauloFlix JSON Index (Movies) | HTTPS | Sync de filmes (fonte primária) | Drift |
| PauloFlixEpisodeProgressRepository | Drift (SQLite) | Progresso de episódios (animes) | Drift |
| PauloFlixMovieProgressRepository | Drift (SQLite) | Progresso de filmes | Drift |
| AniList | GraphQL | Metadados de animes | N/A |
| TheIntroDB | REST | Skip intro/outro | Sim (memória) |
| TMDB | REST | Fallback de metadados | 30 min |
| AnimeFire | Web scraping | Streaming de episódios | N/A |

---

## 🔒 Headers e Configurações

### Autenticação JWT
Desde a migração Tailscale → HTTPS+JWT, toda request ao servidor PauloFlix injeta:
```
Authorization: Bearer <JWT_Ed25519>
```
Implementado via `AuthenticatedHttpClient` (wrapper do `http.Client`).

### User Agents (streaming externo)
```dart
// Google Video (iOS simulation)
'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1'
```

### Referers
```dart
Google Video: 'https://www.blogger.com'
```
