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
- Remove tags como `[AnimeFire]`
- Remove indicadores de idioma (`dublado`, `legendado`, `dub`, `sub`)
- Remove "Todos os Episodios"
- Remove indicadores de temporada/episódio
- Remove conteúdo entre parênteses com info de idioma
- Remove sufixos especiais após `:`

---

## 3. AniSkip API

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
| AniSkip | REST | Skip intro/outro | N/A |

---

## 🔒 Headers e Configurações

### User Agents
```dart
// Google Video (iOS simulation)
'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1'
```

### Referers
```dart
Google Video: 'https://www.blogger.com'
```
