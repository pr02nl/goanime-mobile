# 🔧 Serviços - Documentação Detalhada

## JikanService

Serviço principal para dados de animes via Jikan API (MyAnimeList).

### Características
- Cache em memória (30 minutos)
- Cache persistente via SharedPreferences
- Carregamento paralelo otimizado
- Rate limiting automático

### Métodos Principais

#### `loadHomeData({bool forceRefresh = false})`
Carrega todos os dados da home em paralelo:
- Season animes (temporada atual)
- Top animes
- Animes por gênero (Action, Romance, Comedy, Fantasy)

**Otimização**: Divide 6 requisições em 2 batches com delay de 400ms

#### `getSeasonAnimes()`
Retorna animes da temporada atual com cache.

#### `getTopAnimes()`
Retorna top animes por score com cache.

#### `getAnimesByGenre(int genreId)`
Retorna animes filtrados por gênero com cache.

#### `searchAnime(String query)`
Busca animes por título.

---

## AniListService

Serviço para metadados enriquecidos via AniList GraphQL API.

### Funcionalidades
- Busca por título com limpeza inteligente
- Busca por MAL ID
- Busca por AniList ID
- Limpeza automática de títulos para melhores resultados

### Métodos Principais

#### `fetchAnimeFromAniList(String animeName)`
Busca anime por nome com limpeza de título.

#### `fetchAnimeByMalId(int malId)`
Busca anime específico pelo MAL ID.

#### `fetchAnimeById(int anilistId)`
Busca anime específico pelo AniList ID.

### Limpeza de Títulos
Remove automaticamente:
- Tags de fonte (`[AnimeFire]`)
- Indicadores de idioma
- Sufixos de episódios/temporadas
- Conteúdo entre parênteses

---

## AniSkipService

Serviço para pular intro e outro automaticamente.

### Funcionalidades
- Busca timestamps de opening e ending
- Estratégia multi-ID (MAL → AniList)
- Integração com o player de vídeo

### Métodos Principais

#### `getSkipTimesMultiStrategy({int? malId, int? anilistId, required int episodeNumber, int? episodeLengthSeconds})`
Busca skip times tentando múltiplas estratégias:
1. Tenta com MAL ID
2. Se falhar, tenta com AniList ID
3. Retorna vazio se ambos falharem

### Estrutura de Retorno
```dart
SkipTimes {
  Skip? op;  // Opening
  Skip? ed;  // Ending
}

Skip {
  double start;  // Tempo inicial em segundos
  double end;    // Tempo final em segundos
}
```

---

## DownloadService

Serviço de gerenciamento de downloads para offline.

### Características
- Singleton pattern
- Persistência em SQLite
- Downloads concorrentes configuráveis
- Progresso em tempo real
- Controle de fila (pausar, cancelar, retomar)

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
Adiciona episódio à fila de download.

#### `startDownload(String id)`
Inicia download específico.

#### `pauseDownload(String id)`
Pausa download em andamento.

#### `cancelDownload(String id)`
Cancela e remove download.

#### `deleteDownload(String id)`
Remove download concluído (arquivo + metadados).

#### `retryDownload(String id)`
Tenta novamente download falho.

---

## WatchlistService

Serviço de gerenciamento da lista de animes para assistir depois.

### Persistência
- SQLite com tabela `watchlist`
- Schema: id, animeId, title, coverImage, myAnimeListUrl, addedAt

### Métodos Principais

#### `addToWatchlist(WatchlistAnime anime)`
Adiciona anime à watchlist.

#### `removeFromWatchlist(String animeId)`
Remove anime da watchlist.

#### `isInWatchlist(String animeId)`
Verifica se anime está na watchlist.

#### `getWatchlist()`
Retorna todos os animes da watchlist ordenados por data de adição.

#### `clearWatchlist()`
Remove todos os itens da watchlist.

---

## SearchHistoryService

Serviço de histórico de busca.

### Persistência
- SharedPreferences
- Máximo 20 itens
- FIFO (primeiro a entrar, primeiro a sair quando cheio)

### Métodos Principais

#### `addSearch(String query)`
Adiciona busca ao histórico (remove duplicados).

#### `getSearchHistory()`
Retorna lista de buscas recentes.

#### `clearHistory()`
Limpa todo o histórico.

#### `removeSearch(String query)`
Remove item específico do histórico.

---

## LocaleService

Serviço de gerenciamento de idioma.

### Idiomas Suportados
- `pt_BR` - Português (Brasil) - Padrão
- `en_US` - Inglês (Estados Unidos)

### Persistência
- SharedPreferences (chave: `app_locale`)

### Métodos Principais

#### `setLocale(Locale locale)`
Altera idioma do aplicativo.

#### `getLocale()`
Retorna locale atual.

---

## EpisodeThumbnailService

Serviço para obter thumbnails de episódios.

### Fontes de Thumbnails
1. AniList streamingEpisodes (bônus, raramente disponível)
2. Thumbnail do anime como fallback

### Métodos Principais

#### `fetchEpisodeThumbnails({int? anilistId, int? malId, String? animeThumbnail})`
Busca thumbnails de episódios de todas as fontes disponíveis.

---

## PauloFlixDatabaseService

Serviço de persistência para conteúdo PauloFlix.

### Persistência
- SQLite com tabela `pauloflix_content`
- Schema: id, folderName, displayName, serverUrl, imageUrl, bannerUrl, description, score, genres, status, episodeCount, malId, anilistId, lastSynced, isAvailable

### Métodos Principais

#### `saveContent(PauloFlixContent content)`
Salva ou atualiza conteúdo PauloFlix.

#### `saveBatch(List<PauloFlixContent> contents)`
Salva múltiplos itens em batch (transação).

#### `getAllContent()`
Retorna todos os conteúdos disponíveis.

#### `searchByName(String query)`
Busca por nome (LIKE).

#### `getByFolderName(String folderName)`
Busca por folderName exato.

#### `getByMalId(int malId)`
Busca por MAL ID.

#### `markAsUnavailable(String folderName)`
Marca conteúdo como indisponível.

#### `getStats()`
Retorna estatísticas (total, available, withMetadata).

---

## TmdbService

Cliente para a API v3 do The Movie Database (https://api.themoviedb.org/3).

### Características
- Singleton
- Cache em memória (30 minutos) por query
- Rate throttle: 25 req/s (limite TMDB é 50 req/s)
- Idioma padrão: `pt-BR`

### Configuração
A chave de API (v3) é configurada pelo usuário em Settings → API Keys e persistida via SharedPreferences. Lida no boot pelo `main.dart` antes de qualquer tela carregar.

### Autenticação
Conforme [doc oficial](https://developer.themoviedb.org/reference/intro/getting-started), o cliente envia a chave via `Authorization: Bearer *** Bearer Token também funciona com a api_key v3). Headers obrigatórios `accept: application/json` são incluídos em toda request.

### Métodos Principais

#### `configureFromSettings()`
Carrega a chave persistida em SharedPreferences no boot do app.

#### `setApiKey(String? key)`
Define a chave em memória diretamente (uso em testes / reset).

#### `clear()`
Limpa caches + chave em memória (logout / reconfig).

#### `isConfigured`
`true` se a chave de API estiver presente e não vazia.

#### `searchMovies(String query, {int? year, int? primaryReleaseYear, String? region, int page, int limit})`
Busca filmes pelo título. Suporta todos os parâmetros oficiais:
- `query` (obrigatório)
- `year` (filtro permissivo por ano)
- `primary_release_year` (filtro estrito por data de estreia)
- `region` (ISO 3166-1 — ex. "BR")
- `page` (paginação)
- `limit` (cliente — quantos resultados retornar)

#### `getMovieDetails(int tmdbId, {List<String> appendToResponse})`
Detalhe completo de um filme. Suporta `append_to_response` para reduzir requests (até 20 sub-endpoints em uma chamada — ex: `['credits', 'videos']`).

Retorna `null` em caso de erro genérico; lança `TmdbAuthException` ou `TmdbRateLimitException` quando aplicável.

#### `matchInResults(List<TmdbMovie> results, String query)`
Prefere match exato → match parcial (contains) → primeiro resultado.

### Exceções
```dart
sealed class TmdbException implements Exception { ... }
class TmdbNotConfiguredException extends TmdbException { ... }
class TmdbAuthException extends TmdbException { ... }       // 401
class TmdbRateLimitException extends TmdbException { ... }  // 429
class TmdbRequestException extends TmdbException { ... }   // 5xx, timeout, network
```

Códigos HTTP (doc oficial):
- `200` — Sucesso
- `401` — Chave inválida/expirada (caller deve pedir reconfiguração)
- `429` — Rate limit atingido (caller deve aguardar antes de retentar)
- 5xx — Erro de servidor (caller pode retentar com backoff)

### Endpoints utilizados
- `GET /search/movie?api_key=KEY&query=TITLE&language=pt-BR&year=YEAR`
- `GET /movie/{id}?api_key=KEY&language=pt-BR`

### Imagens
Base URL: `https://image.tmdb.org/t/p/`
- Poster: `w500`
- Backdrop: `w1280`

---

## PauloFlixMoviesService

Serviço de scraping do PauloFlix Movies (HTTP file server) com enriquecimento TMDB.

### Servidor
URL base: `http://100.95.105.113:8300/movies/`

### Persistência
Delegada a `PauloFlixMoviesDatabaseService` (SQLite `pauloflix_movies.db`).

### Algoritmo de limpeza de nome (CRÍTICO)
Os nomes das pastas/arquivos são bagunçados (com tags de qualidade, codecs, grupos). A função estática `cleanMovieName(String)` aplica 4 passes:

1. Remove extensão (`.mkv`/`.mp4`/...)
2. Remove ano entre parênteses/colchetes: `(2010)`, `[1985]`
3. Remove tags (case-insensitive) em ordem:
   - Qualidade: 1080p, 720p, 4K, BluRay, WEB-DL, Open.Matte, Directors.Cut, ...
   - Codecs: x264, x265, HEVC, AV1, 10bit, ...
   - Áudio: DUAL, Dublado, 5.1, AAC, ...
   - Grupos: WWW.BLUDV.COM, GalaxyRG, YTS.MX, KONTRAST, ...
4. Normaliza múltiplos espaços, remove pontos e caracteres especiais

**Saídas esperadas:**
- `"A Origem (2010) 1080p - 210GJI.mp4"` → `"A Origem"`
- `"Amadeus.1984.Directors.Cut.1080p.BluRay.H264.AAC-RARBG.mkv"` → `"Amadeus"`
- `"Deadpool.and.Wolverine.2024...GalaxyRG[TGx]"` → `"Deadpool and Wolverine"`

### Detecção de tipo (filme vs coleção)
- Pasta contém `.mkv`/`.mp4` direto → **filme individual**
- Pasta contém apenas sub-pastas → **coleção** (banner + lista de sub-filmes)
- Vazia → marcada como removida

### Detecção de legenda (.srt)
Quando a pasta do filme contém arquivos `.srt`, o algoritmo escolhe o
melhor candidato por idioma (PT-BR tem prioridade):

1. **PT-BR explícito**: `.pob.srt`, `.pt-br.srt`, `.por.srt`
2. **Forced PT-BR**: `.pob.forced.srt`, `.pt-br.forced.srt`
3. **PT genérico**: `.pt.srt`
4. **Idioma conhecido**: `.eng.srt`, `.en.srt`, `.spa.srt`, `.es.srt`, etc.
5. **Qualquer `.srt`** como fallback (assumido pt-BR)

A URL da legenda escolhida vai junto no objeto `PauloFlixMovieFile` que é
passada para o player via `Episode.subtitleUrl`. O
`ModernVideoPlayerScreen` carrega via `media_kit.Player.setSubtitleTrack`
depois de `Media.open(...)`.

Se a legenda não carregar (erro de rede ou formato), a reprodução do
vídeo continua normalmente — silenciar a falha evita derrubar o filme.

### Métodos Principais

#### `fetchRootFolders()`
Lista todas as pastas raiz de `/movies/`.

#### `inspectFolder(folderName, folderUrl)`
Detecta se a pasta é filme individual, coleção. Extrai título da pasta,
ano via `(YYYY)`, e (se houver) URL da legenda `.srt`.

#### `extractYearFromFolder(String folderName)`
Regex `\((19|20)\d{2}\)` no nome da pasta. Retorna `null` se ausente.

#### `cleanTitleForTmdb(String folderName)`
Limpa o nome da pasta para produzir título buscável no TMDB (remove
tags de qualidade/codec/grupo, normaliza espaços).

#### `syncContent({onProgress, onError})`
Sincronização completa:
1. Marca como indisponível o que não está mais no servidor
2. Enriquece com TMDB apenas o que é novo OU está sem imagem
3. Salva em batch via `PauloFlixMoviesDatabaseService`
4. Emite progresso via `onProgress`
5. Manda erro via `onError`

#### `fetchMovieFile(String folderUrl)`
Resolve URL final do `.mkv`/`.mp4` e (se houver) a URL do `.srt` na mesma
pasta; retorna `PauloFlixMovieFile?`.

---

## PauloFlixMoviesDatabaseService

SQLite para filmes PauloFlix (`pauloflix_movies.db`, separado do banco de animes).

### Schema
```
id, folderName, displayName, serverUrl, imageUrl, bannerUrl,
description, score, genres, releaseDate, runtime, year, tmdbId,
isCollection, availableMovieCount, lastSynced, isAvailable
```

### Métodos
Espelha `PauloFlixDatabaseService` mas adaptado para filmes (inclui `isCollection` e `availableMovieCount`). Ver `PauloFlixMoviesDatabaseService` source.

---

## ApiKeySettingsService

Persiste chaves de API do usuário em SharedPreferences.

### Métodos
- `getTmdbApiKey()` / `setTmdbApiKey(key)` / `clearTmdbApiKey()` / `isTmdbConfigured()`

---

## Resumo de Persistência

> **⚠️ Estado atual:** coexistência de 4 bancos SQLite brutos + 1 banco Drift
> gerado mas não exercitado + 1 helper zumbi. Ver
> [`DATABASE_REFACTORING.md`](./DATABASE_REFACTORING.md) para o plano de
> unificação em **1 banco Drift único** com repositories.

|| Serviço | Tecnologia | Chave/Arquivo |
||---------|------------|---------------|
|| JikanService | Memória + SharedPreferences | `jikan_home_data_cache` |
|| DownloadService | SQLite (sqlite3 FFI) | `downloads.db` |
|| WatchlistService | SQLite (sqlite3 FFI) | `watchlist.db` |
|| PauloFlixDatabaseService | SQLite (sqlite3 FFI) | `pauloflix.db` |
|| PauloFlixMoviesDatabaseService | SQLite (sqlite3 FFI) | `pauloflix_movies.db` |
|| DatabaseHelper | SQLite (sqlite3 FFI) | `anime.db` (zumbi write-only) |
|| AppDatabase (Drift) | Drift (gerado) | `pauloflix.db` (não instanciado) |
|| SearchHistoryService | SharedPreferences | `search_history` |
|| LocaleService | SharedPreferences | `app_locale` |
