# 🌐 APIs Integradas - Documentação Detalhada

## 1. Jikan API (MyAnimeList Unofficial)

### Base URL
```
https://api.jikan.moe/v4
```

### Endpoints Utilizados

#### Temporada Atual
```
GET /seasons/now?limit=15
```
Retorna animes da temporada atual em exibição.

#### Top Animes
```
GET /top/anime?limit=15
```
Retorna os animes mais bem avaliados.

#### Busca por Gênero
```
GET /anime?genres={genre_id}&limit=15&order_by=score&sort=desc
```
Retorna animes filtrados por gênero ordenados por score.

#### Busca por Nome
```
GET /anime?q={query}&limit=20
```
Busca animes por título.

### IDs de Gêneros (JikanGenreIds)
| ID | Gênero |
|----|--------|
| 1 | Action |
| 2 | Adventure |
| 4 | Comedy |
| 8 | Drama |
| 10 | Fantasy |
| 14 | Horror |
| 7 | Mystery |
| 22 | Romance |
| 24 | Sci-Fi |
| 36 | Slice of Life |
| 30 | Sports |
| 37 | Supernatural |

### Rate Limiting
- 3 requisições por segundo
- Implementação em batches de 3 requisições com delay de 400ms entre batches

---

## 2. AniList API (GraphQL)

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
    title {
      romaji
      english
      native
    }
    coverImage {
      extraLarge
      large
      medium
      color
    }
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

#### Busca por MAL ID
```graphql
query ($malId: Int) {
  Media(idMal: $malId, type: ANIME) { ... }
}
```

#### Busca por AniList ID
```graphql
query ($id: Int) {
  Media(id: $id, type: ANIME) { ... }
}
```

### Limpeza de Títulos
A API implementa limpeza inteligente de títulos para melhorar resultados:
- Remove tags como `[AnimeFire]`, `[AllAnime]`
- Remove indicadores de idioma (`dublado`, `legendado`, `dub`, `sub`)
- Remove "Todos os Episodios"
- Remove indicadores de temporada/episódio
- Remove conteúdo entre parênteses com info de idioma
- Remove sufixos especiais após `:`

---

## 3. AllAnime API (GraphQL)

### Base URL
```
https://api.allanime.day/api
```

### Queries GraphQL

#### Busca de Animes
```graphql
query($search: SearchInput, $limit: Int, $page: Int, $translationType: VaildTranslationTypeEnumType, $countryOrigin: VaildCountryOriginEnumType) {
  shows(search: $search, limit: $limit, page: $page, translationType: $translationType, countryOrigin: $countryOrigin) {
    edges {
      _id
      name
      englishName
      availableEpisodes
      thumbnail
      __typename
    }
  }
}
```

#### Lista de Episódios (Simples)
```graphql
query ($showId: String!) {
  show(_id: $showId) {
    _id
    availableEpisodesDetail
  }
}
```

#### Lista de Episódios (Detalhada)
```graphql
query ($showId: String!) {
  show(_id: $showId) {
    _id
    thumbnail
    episodeInfos
    availableEpisodesDetail
  }
}
```

#### Streaming de Episódio
```graphql
query ($showId: String!, $translationType: VaildTranslationTypeEnumType, $episodeString: String!) {
  episode(showId: $showId, translationType: $translationType, episodeString: $episodeString) {
    episodeString
    sourceUrls
    notes
    videoId
  }
}
```

### Resolução de URLs de Vídeo
O serviço extrai URLs de diferentes fontes:
- MP4 (link direto)
- HLS (m3u8)
- Google Video (com proxy)
- Blogger (fallback)

---

## 4. AniSkip API

### Base URL
```
https://api.aniskip.com/v2
```

### Endpoint
```
GET /skip-times/{anime_id}/{episode_number}
```

### Parâmetros
- `types[]`: `['op', 'ed']` - Tipos de skip (opening, ending)
- `episodeLength`: Duração do episódio em segundos

### Exemplo de Resposta
```json
{
  "found": true,
  "results": [
    {
      "interval": {
        "startTime": 34.5,
        "endTime": 124.2
      },
      "skipType": "op",
      "episodeLength": "1440"
    },
    {
      "interval": {
        "startTime": 1320.0,
        "endTime": 1410.5
      },
      "skipType": "ed",
      "episodeLength": "1440"
    }
  ],
  "message": "Successfully found skip times",
  "statusCode": 200
}
```

### Estratégia de Busca
1. Tenta com MAL ID se disponível
2. Se falhar, tenta com AniList ID
3. Retorna empty se nenhum ID funcionar

---

## 📊 Resumo de APIs

| API | Protocolo | Uso Principal | Cache |
|-----|-----------|---------------|-------|
| Jikan | REST | Dados de animes, rankings | 30 min |
| AniList | GraphQL | Metadados, imagens | N/A |
| AllAnime | GraphQL | Streaming de episódios | N/A |
| AniSkip | REST | Skip intro/outro | N/A |

---

## 🔒 Headers e Configurações

### User Agents
```dart
// AllAnime
'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0'

// Google Video (iOS simulation)
'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1'
```

### Referers
```dart
AllAnime: 'https://allanime.to'
Google Video: 'https://www.blogger.com'
```
