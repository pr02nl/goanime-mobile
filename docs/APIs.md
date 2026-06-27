# 🌐 APIs Integradas - Documentação Detalhada

## 0. PauloFlix JSON Index (Sync Principal)

**Base URL:** `https://media.oliveira.braga.nom.br`

### TV Shows Index
```
GET /tvshows/tv_index.json
```
Índice JSON completo de todos os shows do PauloFlix TV. Substitui o scraping HTML + Jikan API como fonte primária de dados.

**Resposta:** JSON com array `shows[]` contendo metadados completos (título, descrição, poster, fanart, rating, gêneros, seasons/episódios, etc.). Ver `docs/Services.md` para a estrutura detalhada.

### Movies Index
```
GET /movies/movie_index.json
```
Índice JSON completo de todos os filmes do PauloFlix Movies. Substitui o scraping HTML + TMDB API como fonte primária.

**Resposta:** JSON com array `movies[]` contendo metadados completos (título, descrição, poster, fanart, gêneros, rating, runtime, etc.).

---

## 1. Jikan API (MyAnimeList Unofficial)

**Uso:** Apenas para a tela Home (animes externos) e busca. **Não é mais usado pelo sync PauloFlix.**

### Base URL
```
https://api.jikan.moe/v4
```

### Endpoints Utilizados

#### Temporada Atual
```
GET /seasons/now?limit=15
```

#### Top Animes
```
GET /top/anime?limit=15
```

#### Busca por Gênero
```
GET /anime?genres={genre_id}&limit=15&order_by=score&sort=desc
```

#### Busca por Nome
```
GET /anime?q={query}&limit=20
```

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
- Cache em memória (30 min) + persistente (SharedPreferences)

---

## 2. AniList API (GraphQL)

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

## 3. AniSkip API

**Uso:** Pular intro/outro automaticamente no player de vídeo.

### Base URL
```
https://api.aniskip.com/v2
```

### Endpoint
```
GET /skip-times/{anime_id}/{episode_number}?types[]=op&types[]=ed&episodeLength={seconds}
```

### Estratégia de Busca
1. Tenta com MAL ID se disponível
2. Se falhar, tenta com AniList ID
3. Retorna empty se nenhum ID funcionar

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

## 📊 Resumo de APIs

| API | Protocolo | Uso Principal | Cache |
|-----|-----------|---------------|-------|
| PauloFlix JSON Index (TV) | HTTPS | Sync de shows (fonte primária) | Drift |
| PauloFlix JSON Index (Movies) | HTTPS | Sync de filmes (fonte primária) | Drift |
| Jikan | REST | Home/Busca de animes externos | 30 min |
| AniList | GraphQL | Metadados de animes | N/A |
| AniSkip | REST | Skip intro/outro | N/A |
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
