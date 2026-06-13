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

## Resumo de Persistência

| Serviço | Tecnologia | Chave/Arquivo |
|---------|------------|---------------|
| JikanService | Memória + SharedPreferences | `jikan_home_data_cache` |
| DownloadService | SQLite | `downloads.db` |
| WatchlistService | SQLite | `watchlist.db` |
| SearchHistoryService | SharedPreferences | `search_history` |
| LocaleService | SharedPreferences | `app_locale` |
