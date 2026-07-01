# 🔧 Serviços - Documentação Detalhada

## Visão Geral da Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    Camada de UI (Widgets)                    │
├─────────────────────────────────────────────────────────────┤
│                    ViewModels (Provider)                     │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Repositories (Drift)                     │   │
│  │  watchlist_repository_impl  │  pauloflix_repository   │   │
│  │  downloads_repository_impl  │  pauloflix_movies_repo  │   │
│  │  paulo_flix_episode_progress_repository_impl          │   │
│  └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌───────────────────────────────┐   │
│  │  JSON Index Sync  │  │  Serviços Auxiliares          │   │
│  │  (fonte primária) │  │  introdb_svc, download_svc,   │
│  └──────────────────┘  └───────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Fluxo de dados principal (Sync):**
1. App faz GET de `tv_index.json` / `movie_index.json` do servidor PauloFlix
2. Parseia o JSON → `PauloFlixContent` / `PauloFlixMovie` (com metadados completos)
3. Salva no banco Drift via repositories (UPSERT)
4. UI lê do banco via ViewModels → reativo via `Stream`

**Serviços externos removidos:** Jikan, AniList, TMDB, AnimeFire, Kitsu e GoogleVideoProxy foram removidos — os JSON indexes fornecem todos os metadados necessários (título, descrição, poster, fanart, rating, gêneros, thumbnails de episódios, URLs diretas de vídeo).

---

## PauloFlixService

Serviço principal de sincronização de **animes PauloFlix** (TV shows).

### URL Base
```
https://media.oliveira.braga.nom.br/tvshows/
```

### Sincronização via JSON Index

**Endpoint:** `GET /tvshows/tv_index.json`

O servidor gera server-side um JSON index (`tv_index.json`) contendo todos os metadados de todos os shows.

**Estrutura do JSON index:**
```json
{
  "shows": [
    {
      "path": "Hunter x Hunter (2011)",
      "title": "Hunter x Hunter (2011)",
      "original_title": "Hunter × Hunter",
      "description": "...",
      "poster": "/tvshows/Hunter x Hunter (2011)/poster.jpg",
      "fanart": "/tvshows/Hunter x Hunter (2011)/fanart.jpg",
      "banner": "/tvshows/Hunter x Hunter (2011)/banner.jpg",
      "rating": 9.1,
      "genre": ["Action", "Adventure", "Fantasy"],
      "status": "Finished",
      "year": "2011",
      "episode_count": 148,
      "tmdb_id": 46298,
      "seasons": [
        {
          "season": 1,
          "folderName": "Season 01",
          "episodes": [
            {
              "episode": 1,
              "title": "Departure",
              "file": "/tvshows/Hunter x Hunter (2011)/Season 01/S01E001.mkv",
              "thumb": "/tvshows/Hunter x Hunter (2011)/Season 01/S01E001-thumb.jpg",
              "aired": "2011-10-02",
              "rating": 8.5,
              "plot": "...",
              "nfo": { "runtime": "23", "originaltitle": "..." }
            }
          ]
        }
      ]
    }
  ]
}
```

### Métodos Principais

#### `syncContent({repository, onProgress, onError, episodeRepository})`
Sincronização completa de todos os shows a partir do JSON index:
1. GET `tv_index.json`
2. Converte JSON para `List<PauloFlixContent>` via `fromTvIndex()`
3. Salva em batch no banco via `repository.saveBatch()`
4. Se `episodeRepository` for fornecido, popula seasons/episódios diretamente do JSON
5. Marca como indisponível shows que sumiram do servidor
6. Callbacks de progresso (`onProgress`) e erro (`onError`)


---

## PauloFlixMoviesService

Serviço de sincronização de **filmes PauloFlix**.

### URL Base
```
https://media.oliveira.braga.nom.br/movies/
```

### Sincronização via JSON Index (única fonte)

**Endpoint:** `GET /movies/movie_index.json`

O JSON index (`movie_index.json`) é a **única fonte** de dados. Todo scraping HTML foi removido — cada filme no JSON tem URL direta do vídeo (`file`) e legendas (`subtitles`).

**Estrutura do JSON index:**
```json
{
  "movies": [
    {
      "path": "2012 (2009)",
      "title": "2012",
      "description": "...",
      "poster": "/movies/2012 (2009)/poster.jpg",
      "fanart": "/movies/2012 (2009)/fanart.jpg",
      "genres": ["Ação", "Aventura"],
      "rating": 5.8,
      "year": 2009,
      "runtime": 158,
      "tmdb_id": 14161,
      "file": "/movies/2012 (2009)/2012.2009.1080p.mp4",
      "subtitles": [
        { "file": "/movies/2012 (2009)/sub.srt", "lang": "pob", "name": "sub.srt" },
        { "file": "/movies/2012 (2009)/eng.srt", "lang": "eng", "name": "eng.srt" }
      ]
    }
  ]
}
```

### Métodos

#### `configure(http.Client client)`
Injeta o HTTP client com autenticação JWT. Chamado **uma vez** no boot do app (`main.dart`).

#### `syncContent({repository, onProgress, onError})`
Único método público. Sincronização completa de todos os filmes:
1. GET `movie_index.json`
2. Converte JSON para `List<PauloFlixMovie>` via `fromMovieIndex()`
   - `file` → `videoUrl` (URL absoluta via `baseHost`)
   - `subtitles[]` → `subtitles` (cada `file` resolvido para URL absoluta)
3. Salva em batch no banco via `repository.saveBatch()` (UPSERT)
4. Marca filmes que sumiram do servidor como indisponíveis

---

## DownloadService

Serviço de gerenciamento de downloads para offline.

### Características
- Injetado via `DownloadService.withRepository(repo, {httpClient})`
- Persistência via `DownloadsRepository` (Drift) — fonte de verdade
- Downloads concorrentes configuráveis (1-5)
- Progresso em tempo real via `ChangeNotifier`
- Controle de fila (pausar, cancelar, retomar)
- HTTP client injetável (em produção: `AuthenticatedHttpClient` com JWT)
- URLs diretas PauloFlix (MKV/MP4) — sem resolução de URL externa

### Estados de Download
```dart
enum DownloadStatus {
  queued,      // Na fila
  downloading, // Em progresso
  paused,      // Pausado
  completed,   // Concluído
  failed,      // Falhou
  cancelled,   // Cancelado
}
```

### Métodos Principais

#### `addDownload({...})`
Adiciona episódio à fila de download. Salva via repository + dispara `_processQueue()`.

#### `pauseDownload(String id)` / `resumeDownload(String id)`
Pausa/retoma download específico.

#### `cancelDownload(String id)`
Cancela e remove arquivo parcial.

#### `deleteDownload(String id)`
Remove do banco + deleta arquivo local.

#### `retryDownload(String id)`
Reseta status para `queued` e re-processa fila.

---

## IntroDbService

Serviço para consulta de segmentos de intro/outro via TheIntroDB API.

### URL Base
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

---

## SearchHistoryService

Serviço de histórico de busca via SharedPreferences.

### Configuração
- Máximo 20 itens
- FIFO quando cheio
- Persistência em SharedPreferences

---

## AuthenticatedHttpClient

Wrapper `http.Client` que injeta `Authorization: Bearer <JWT>` em toda request.

### Uso
- Injetado no boot do app (`main.dart`) para:
  - `DownloadService.withRepository(_, httpClient: authClient)`
  - `PauloFlixService.configure(authClient)`
  - `PauloFlixMoviesService.configure(authClient)`
- Fallback: `http.Client()` puro sem auth (usado em testes)

---

## Resumo dos Services Ativos

| Service | Camada | Tecnologia | Persiste? |
|---------|--------|-----------|-----------|
| `PauloFlixService` | Sync | HTTP + JSON index (única fonte) | Via `PauloFlixRepository` (Drift) |
| `PauloFlixMoviesService` | Sync | HTTP + JSON index (única fonte) | Via `PauloFlixMoviesRepository` (Drift) |
| `DownloadService` | Streaming | HTTP + Drift (fila + persistência) | Via `DownloadsRepository` (Drift) |
| `IntroDbService` | API externa | HTTP (TheIntroDB API) | Sim (memória) |
| `SearchHistoryService` | Persistência | SharedPreferences | Sim |

## Resumo de Persistência

|| Camada | Tecnologia | Arquivo |
|| ------ | ---------- | ------- |
|| Banco de dados | Drift | `core/database/app_database.dart` |
|| Repositories (5) | Drift | `data/repositories/*repository_impl.dart` |
|| Sync shows + films | HTTP + JSON index | `data/services/pauloflix*_service.dart` |
|| TheIntroDB API | HTTP | `data/services/introdb_service.dart` |
|| Downloads (fila HTTP) | HTTP + Drift | `data/services/download_service.dart` |
|| Episode/season progress | Drift (SQLite) | `data/services/episode_progress_service.dart` |
|| Movie progress | Drift (SQLite) | `data/services/movie_progress_service.dart` |
|| Image precache | HTTP | `data/services/image_precache_service.dart` |
|| Search history | SharedPreferences | `data/services/search_history_service.dart` |
|| JWT auth | HTTP client wrapper | `data/services/auth/authenticated_http_client.dart` |
