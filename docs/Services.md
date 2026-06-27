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
│  │  JSON Index Sync  │  │  Services de Scraping/Stream  │   │
│  │  (fonte primária) │  │  (fallback on-demand)         │   │
│  │  pauloflix*_svc   │  │  jikan_service, tmdb_service  │   │
│  └──────────────────┘  │  anilist_service, aniskip_svc │   │
│                        │  anime_service, download_svc  │   │
│                        └───────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Fluxo de dados principal (Sync):**
1. App faz GET de `tv_index.json` / `movie_index.json` do servidor PauloFlix
2. Parseia o JSON → `PauloFlixContent` / `PauloFlixMovie` (com metadados completos)
3. Salva no banco Drift via repositories (UPSERT)
4. UI lê do banco via ViewModels → reativo via `Stream`

**Fluxo legado (fallback on-demand):**
- Episódios/seasons: scraping HTML do file server (quando não há JSON)
- Metadados de animes (Jikan API): usado apenas pela tela de busca/animes externos
- Metadados de filmes (TMDB): **não é mais usado** para o sync principal

---

## PauloFlixService

Serviço principal de sincronização de **animes PauloFlix** (TV shows).

### URL Base
```
https://media.oliveira.braga.nom.br/tvshows/
```

### Sincronização via JSON Index

**Endpoint:** `GET /tvshows/tv_index.json`

O servidor gera server-side um JSON index (`tv_index.json`) contendo todos os metadados de todos os shows. Este JSON substituiu o scraping HTML + Jikan API como fonte primária de dados.

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
      "mal_id": 11061,
      "anilist_id": 11061,
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
              "nfo": {
                "runtime": "23",
                "originaltitle": "..."
              }
            }
          ]
        }
      ]
    }
  ]
}
```

### Vantagens do JSON Index sobre o scraping HTML + Jikan

| Aspecto | Antes (HTML + Jikan) | Agora (JSON Index) |
|---------|---------------------|-------------------|
| Requisições HTTP | N scraping HTML + N Jikan API (rate limited) | 1 GET do JSON index |
| Rate limiting | 3 req/s (Jikan) | Nenhum |
| TTL/cache | 30 min (Jikan) | Sem TTL (fonte da verdade) |
| Metadados | Parciais (título, imagem, score) | Completos (título, descrição, poster, fanart, rating, gêneros, status, year, tmdbId, + seasons/episódios) |
| Episódios | Scraping separado por season | Inclusos no mesmo JSON |
| Imagens | URL externa (Jikan) | URL do próprio servidor |

### Métodos Principais

#### `syncContent({repository, onProgress, onError, episodeRepository})`
Sincronização completa de todos os shows a partir do JSON index:
1. GET `tv_index.json`
2. Converte JSON para `List<PauloFlixContent>` via `fromTvIndex()`
3. Salva em batch no banco via `repository.saveBatch()`
4. Se `episodeRepository` for fornecido, popula seasons/episódios diretamente do JSON
5. Marca como indisponível shows que sumiram do servidor
6. Callbacks de progresso (`onProgress`) e erro (`onError`)

#### `fetchShowSeasons(String showUrl)`
Scraping HTML da pasta do show (mantido para compatibilidade). Extrai seasons da lista `<a href>`.

#### `fetchSeasonEpisodes(String seasonUrl)`
Scraping HTML da pasta da season (mantido para compatibilidade). Extrai episódios por extensão de vídeo (`.mkv`, `.mp4`, etc.).

---

## PauloFlixMoviesService

Serviço de sincronização de **filmes PauloFlix**.

### URL Base
```
https://media.oliveira.braga.nom.br/movies/
```

### Sincronização via JSON Index

**Endpoint:** `GET /movies/movie_index.json`

Mesmo padrão do `PauloFlixService`. O JSON index (`movie_index.json`) contém metadados completos de todos os filmes, eliminando a necessidade de scraping HTML + TMDB.

**Estrutura do JSON index:**
```json
{
  "movies": [
    {
      "path": "A Origem (2010)",
      "title": "A Origem",
      "description": "...",
      "poster": "/movies/A Origem (2010)/poster.jpg",
      "fanart": "/movies/A Origem (2010)/fanart.jpg",
      "genres": ["Ação", "Ficção Científica"],
      "rating": 8.8,
      "year": 2010,
      "release_date": "2010-07-16",
      "runtime": 148,
      "tmdb_id": 27205,
      "is_collection": false,
      "available_movie_count": 1
    }
  ]
}
```

### Vantagens sobre o fluxo TMDB

| Aspecto | Antes (HTML + TMDB) | Agora (JSON Index) |
|---------|--------------------|--------------------|
| Requisições | N scraping HTML + N TMDB (rate limited 50 req/s) | 1 GET do JSON index |
| API key | Necessária (TMDB v3) | Não precisa |
| Metadados | Parciais (dependia de match TMDB) | Completos (pré-resolvidos) |
| Velocidade | Minutos (200+ filmes × TMDB rate limit) | Segundos |

### Métodos Principais

#### `syncContent({repository, onProgress, onError})`
Sincronização completa de todos os filmes a partir do JSON index:
1. GET `movie_index.json`
2. Converte JSON para `List<PauloFlixMovie>` via `fromMovieIndex()`
3. Salva em batch no banco via `repository.saveBatch()`
4. Marca como indisponível filmes que sumiram do servidor

#### `inspectFolder(folderName, folderUrl)`
Scraping on-demand de uma pasta de filme (usado pela tela de detalhe). Detecta:
- Filme individual (contém `.mkv`/`.mp4`)
- Coleção (contém sub-pastas com vídeos)
- Vazio (marcado como indisponível)
- Extrai arquivos de legenda `.srt` (prioridade PT-BR)

#### `cleanTitleForTmdb(String folderName)`
Limpa nome de pasta para busca TMDB (mantido para compatibilidade — não usado no sync principal).

#### `fetchMovieFile(String folderUrl)`
Retorna `PauloFlixMovieFile?` com URL do vídeo e legendas da pasta.

---

## DownloadService

Serviço de gerenciamento de downloads para offline.

### Características
- **Não é mais singleton** — injetado via `DownloadService.withRepository(repo, {httpClient})`
- Persistência via `DownloadsRepository` (Drift) — fonte de verdade
- Downloads concorrentes configuráveis (1-5)
- Progresso em tempo real via `ChangeNotifier`
- Controle de fila (pausar, cancelar, retomar)
- HTTP client injetável (em produção: `AuthenticatedHttpClient` com JWT)

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

### Qualidades Suportadas
```dart
enum DownloadQuality {
  auto,   // Auto-detectar
  low,    // 480p
  medium, // 720p
  high,   // 1080p
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
Remove do banco (via `_repository.delete(id)`) + deleta arquivo local.

#### `retryDownload(String id)`
Reseta status para `queued` e re-processa fila.

---

## PauloFlixEpisodeSyncService

Serviço de sincronização on-demand de seasons + episodes.

### Responsabilidades
- Scraping HTML do file server (listings `<a href>`) para extrair seasons/episodes de um show
- Integração com `PauloFlixNfoEnricher` para enriquecer episodes com:
  - `.nfo` files (`S01E001.nfo`, `season.nfo`) → plot, originalTitle, outline, rating, runtime
  - Thumbnails (`S01E001-thumb.jpg`)
- Reatividade: upsert preserva progresso do usuário (`positionSeconds`, `isCompleted`)
- Reconciliação: `reconcileSeasonEpisodes()` remove seasons/episodes que sumiram do servidor (mas preserva os que têm progresso)

### Arquitetura

| Camada | Responsabilidade |
|--------|-----------------|
| `PauloFlixEpisodeSyncService` | Orquestrador: fetch HTML → upsert no banco |
| `PauloFlixNfoEnricher` | HTTP fetcher de NFOs/thumbs do servidor |
| `KodiNfoParser` | Parser XML puro (sem Flutter) de `tvshow.nfo`, `movie.nfo`, `episodedetails.nfo`, `season.nfo` |
| `PauloFlixEpisodeProgressRepository` | Persistência via Drift (tabelas `paulo_flix_seasons`, `paulo_flix_episodes`) |

### Métodos Principais

#### `syncSeasonEpisodes({contentId, contentServerUrl, enricher})`
Sync upsert de seasons/episodes de um show:
1. Fetch + parse seasons (HTTP)
2. Para cada season:
   a. (Opcional) Listing unificado via enricher (episodeNumbers, thumbUrls, images, hasSeasonNfo)
   b. Upsert season
   c. (Opcional) N NFOs paralelos via enricher → descrições + metadados V2
   d. Fetch + parse episodes (HTTP)
   e. Upsert cada episode preservando progresso
   f. Atualiza episodeCount

#### `reconcileSeasonEpisodes({contentId, contentServerUrl, enricher})`
Sync + reconciliação: remove seasons/episodes ausentes do servidor **que não têm progresso do usuário**. Retorna `SeasonEpisodesReconciliationStats`.

---

## PauloFlixNfoEnricher

Orquestrador HTTP para enriquecimento via arquivos NFO/JPG do servidor.

### Responsabilidades
- GET `tvshow.nfo` / `movie.nfo` / `season.nfo` → parse via `KodiNfoParser`
- GET `SXXEYYY-thumb.jpg` do listing da season
- GET `SXXEYYY.nfo` com fallback de zero-padding (3-dígitos → 2-dígitos → sem padding)
- Detecção de `poster.jpg` / `fanart.jpg` no listing (show e season)
- Resolução de URLs (absoluta vs path relativo)

### Métodos
- `fetchShowNfo(showUrl)` → `KodiShowNfo?`
- `fetchMovieNfo(folderUrl)` → `KodiShowNfo?`
- `fetchSeasonNfo(seasonUrl)` → `KodiSeasonNfo?`
- `fetchEpisodeNfo(seasonUrl, seasonNumber, episodeNumber)` → `KodiEpisodeNfo?`
- `fetchSeasonListing(seasonUrl)` → record unificado (episodeNumbers, thumbUrls, images, hasSeasonNfo, episodeNfoFilenames)
- `fetchShowNfoWithImages(showUrl)` → record (nfo + DetectedShowImages)

### Tratamento de Erros
Todos os métodos envolvem HTTP em `try`/`catch` e retornam `null` / vazio em qualquer falha. NUNCA propagam exceção.

---

## KodiNfoParser

Parser XML puro (sem Flutter) para arquivos NFO do Kodi.

### Suporte
- `parseShow(String xmlBody)` — root `<tvshow>` → `KodiShowNfo?`
- `parseMovie(String xmlBody)` — root `<movie>` → `KodiShowNfo?`
- `parseEpisode(String xmlBody)` — root `<episodedetails>` → `KodiEpisodeNfo?`
- `parseSeasonNfo(String xmlBody)` — root `<season>` → `KodiSeasonNfo?`

### Schema V2 (KodiEpisodeNfo)
```
originalTitle, outline, aired (DateTime), rating (double), runtime (int)
```
5 campos novos além dos V1 (season, episode, title, plot, thumb).

---

## JikanService

Serviço para dados de animes via Jikan API (MyAnimeList). **Usado apenas pela tela Home (animes externos) — o sync PauloFlix não usa mais.**

### URL Base
```
https://api.jikan.moe/v4
```

### Características
- Cache em memória (30 minutos) + cache persistente via SharedPreferences
- Rate limiting automático (3 req/s)
- Carregamento em 2 batches de 3 requisições com delay de 400ms entre batches

### Métodos Principais

#### `loadHomeData({bool forceRefresh = false})`
Carrega dados da Home em paralelo: temporada atual + top animes + 4 gêneros.

#### `getTopAnimes()`, `getCurrentSeasonAnimes()`, `getAnimesByGenre(genreId)`, `searchAnimes(query)`, etc.
Métodos individuais com cache em memória.

---

## AniListService

Serviço para metadados via AniList GraphQL API.

### URL Base
```
https://graphql.anilist.co
```

### Funcionalidades
- Busca por título (com limpeza inteligente de tags como `[AnimeFire]`, indicadores de idioma)
- Busca por MAL ID
- Busca por AniList ID

---

## AniSkipService

Serviço para pular intro/outro automaticamente.

### URL Base
```
https://api.aniskip.com/v2
```

### Endpoint
```
GET /skip-times/{anime_id}/{episode_number}?types[]=op&types[]=ed
```

### Estratégia
1. Tenta com MAL ID
2. Se falhar, tenta com AniList ID
3. Retorna vazio se ambos falharem

---

## TmdbService

Cliente para a API v3 do TMDB. **Não é mais usado no sync de filmes PauloFlix** (substituído pelo JSON index). Mantido para compatibilidade.

### URL Base
```
https://api.themoviedb.org/3
```

### Características
- Cache em memória (30 minutos)
- Rate throttle: 25 req/s
- Autenticação via `Authorization: Bearer` (API key v3 configurada pelo usuário)

---

## EpisodeThumbnailService

Serviço para obter thumbnails de episódios de fontes externas (AniList streamingEpisodes).

### Fontes
1. AniList streamingEpisodes (raro)
2. Thumbnail do anime como fallback

---

## SearchHistoryService

Serviço de histórico de busca via SharedPreferences.

### Configuração
- Máximo 20 itens
- FIFO quando cheio
- Persistência em SharedPreferences

---

## ApiKeySettingsService

Persiste chaves de API do usuário em SharedPreferences.

### Chaves
- `tmdb_api_key` — chave v3 do TMDB (configurada pelo usuário em Settings)

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
| `PauloFlixService` | Sync | HTTP + JSON index + HTML scraping (on-demand) | Via `PauloFlixRepository` (Drift) |
| `PauloFlixMoviesService` | Sync | HTTP + JSON index + HTML scraping (on-demand) | Via `PauloFlixMoviesRepository` (Drift) |
| `PauloFlixEpisodeSyncService` | Sync | HTTP + HTML scraping + NFO | Via `PauloFlixEpisodeProgressRepository` (Drift) |
| `PauloFlixNfoEnricher` | Sync | HTTP | Não |
| `DownloadService` | Streaming | HTTP + Drift (fila + persistência) | Via `DownloadsRepository` (Drift) |
| `JikanService` | API externa | HTTP (Jikan API) | Cache SharedPreferences |
| `AniListService` | API externa | GraphQL HTTP | Não |
| `AniSkipService` | API externa | HTTP (AniSkip API) | Não |
| `TmdbService` | API externa | HTTP (TMDB API) | Não |
| `SearchHistoryService` | Persistência | SharedPreferences | Sim |
| `EpisodeThumbnailService` | Streaming | HTTP (AniList) | Não |
| `ApiKeySettingsService` | Persistência | SharedPreferences | Sim |

## Resumo de Persistência

|| Camada | Tecnologia | Arquivo |
|| ------ | ---------- | ------- |
|| Banco de dados | Drift | `core/database/app_database.dart` |
|| Repositories (4) | Drift | `data/repositories/*repository_impl.dart` |
|| Sync shows + films | HTTP + JSON index | `data/services/pauloflix*_service.dart` |
|| Sync episodes | HTTP + HTML scraping | `data/services/paulo_flix_episode_sync_service.dart` |
|| NFO enrichment | HTTP + XML parsing | `data/services/kodi/pauloflix_nfo_enricher.dart` |
|| Kodi NFO parser | XML (package:xml) | `data/services/kodi/kodi_nfo_parser.dart` |
|| Animes API (Jikan) | HTTP + cache 30min | `data/services/jikan_service.dart` |
|| AniList API | GraphQL HTTP | `data/services/anilist_service.dart` |
|| AniSkip API | HTTP | `data/services/aniskip_service.dart` |
|| TMDB API | HTTP (fallback) | `data/services/tmdb_service.dart` |
|| Downloads (fila HTTP) | HTTP + Drift | `data/services/download_service.dart` |
|| Search history | SharedPreferences | `data/services/search_history_service.dart` |
|| TV API key | HTTP server | `data/services/tv_api_key_server.dart` |
|| JWT auth | HTTP client wrapper | `data/services/auth/authenticated_http_client.dart` |
