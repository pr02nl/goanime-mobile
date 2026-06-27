# 🎬 PauloFlix Movies — Documentação

## Visão Geral

Área dedicada a filmes no PauloFlix, espelhando o PauloFlix de animes, com:

- **Servidor de arquivos**: `https://media.oliveira.braga.nom.br/movies/` (PauloFlix — file server)
- **Provedor de metadados**: JSON index (`movie_index.json`) — gerado server-side, contém metadados completos (título, descrição, poster, fanart, gêneros, rating, etc.)
- **Banco local**: Drift (tabela `paulo_flix_movies` no banco unificado `pauloflix.db`)
- **Toggle**: pill no action bar do `MainNavigationScreen` para alternar entre Animes e Filmes
- **Sincronização**: uma única request HTTP (`movie_index.json`), elimina chamadas externas e rate limiting

## Sincronização (JSON Index) — FLUXO PRINCIPAL

### Como funciona

1. App faz GET de `https://media.oliveira.braga.nom.br/movies/movie_index.json`
2. Parseia o JSON → `List<PauloFlixMovie>` via `PauloFlixMovie.fromMovieIndex()`
3. Salva em batch no banco via `PauloFlixMoviesRepository.saveBatch()`
4. Marca como indisponível filmes que sumiram do servidor

### Estrutura do JSON Index

```json
{
  "movies": [
    {
      "path": "A Origem (2010)",
      "title": "A Origem",
      "description": "Sinopse do filme...",
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

**Paths relativos** são resolvidos com o `baseHost` (`https://media.oliveira.braga.nom.br`) para formar URLs absolutas.

### Vantagens sobre o fluxo anterior (HTML scraping + TMDB)

| Aspecto | Antes | Agora |
|---------|-------|-------|
| Requisições HTTP | N scraping HTML + N TMDB API | 1 GET do JSON index |
| API key TMDB | Necessária (configurada pelo usuário) | Não precisa |
| Metadados | Parciais (dependia de match TMDB) | Completos (pré-resolvidos server-side) |
| Rate limiting | 50 req/s (TMDB), throttled a 25 | Nenhum |
| Velocidade de sync | Minutos (200+ filmes) | Segundos |
| Confiabilidade | Match imperfeito (nomes bagunçados) | Pré-resolvido, sem ambiguidade |

## Estrutura de Pastas no Servidor

```
/movies/
  ├── A Origem (2010)/              ← Filme individual
  │   ├── A Origem (2010) 1080p - xxx.mp4
  │   └── *.srt (legenda)
  ├── Amadeus/
  │   └── Amadeus.1984.Directors.Cut....mkv
  └── Coleção Harry Potter 2001-2011/   ← Coleção
      ├── Harry Potter e a Pedra Filosofal 2001/
      └── ...
```

**Detecção na tela de detalhe (on-demand via `inspectFolder`):**
- Tem `.mkv`/`.mp4` direto → **filme individual**
- Tem apenas sub-pastas com vídeos → **coleção** (banner + sub-filmes)
- Vazia → marcada como removida

## Detecção de Legenda (.srt)

Quando a pasta do filme contém arquivos `.srt`, a prioridade (via `_rankAllSubtitles`):

1. **PT-BR explícito**: `.pob.srt`, `.pt-br.srt`, `.por.srt` (score 100)
2. **Forced PT-BR**: `.pob.forced.srt`, `.pt-br.forced.srt` (score 95)
3. **PT genérico**: `.pt.srt` (score 90)
4. **Idioma conhecido**: `.eng.srt`, `.en.srt`, `.spa.srt`, etc. (score 80)
5. **Qualquer `.srt`** como fallback (score 50, assumido pt-BR)

## Especificações Técnicas

### Modelos

- `PauloFlixMovie` — modelo de domínio (pb com coleção)
- `PauloFlixMovieItem` — filme único (dentro de coleção ou isolado)
- `PauloFlixMovieRaw` — resultado do scraping on-demand
- `PauloFlixMovieFile` — arquivo de vídeo + subtitles
- `PauloFlixMovieSubfolder` — sub-pasta dentro de coleção

### Schema do Banco (Drift)

```dart
// lib/core/database/tables/pauloflix_movies.dart
class PauloFlixMovies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get folderName => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get serverUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get score => real().nullable()();
  TextColumn get genresJson => text().nullable()(); // JSON array
  TextColumn get releaseDate => text().nullable()();
  IntColumn get runtime => integer().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get tmdbId => integer().nullable()();
  BoolColumn get isCollection => boolean().withDefault(const Constant(false))();
  IntColumn get availableMovieCount => integer().withDefault(const Constant(0))();
  IntColumn get lastSynced => integer()(); // epoch seconds
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
}
```

### Arquivos

| Camada | Arquivo | Função |
|--------|---------|--------|
| Models | `lib/domain/models/pauloflix_movie.dart` | Modelo unificado (filme OU coleção) |
| Models | `lib/domain/models/pauloflix_movie_item.dart` | Filme único (dentro de coleção ou isolado) |
| Models | `lib/domain/models/pauloflix_movie_types.dart` | Tipos auxiliares (`PauloFlixMovieRaw`, `PauloFlixMovieFile`, `SubtitleTrackInfo`) |
| Services | `lib/data/services/pauloflix_movies_service.dart` | Sync JSON index + scraping on-demand |
| Services | `lib/data/services/tmdb_service.dart` | TMDB (fallback, não usado no sync principal) |
| Services | `lib/data/services/kodi/pauloflix_nfo_enricher.dart` | NFO enrichment (opcional) |
| Services | `lib/data/services/kodi/kodi_nfo_parser.dart` | Parser NFO (opcional) |
| Repository | `lib/domain/repositories/pauloflix_movies_repository.dart` | Interface |
| Repository | `lib/data/repositories/pauloflix_movies_repository_impl.dart` | Implementação Drift |
| Provider | `lib/ui/pauloflix_movies/view_models/pauloflix_movies_provider.dart` | State management |
| Badge | `lib/ui/core/widgets/pauloflix_movies_badge.dart` | Badge vermelho cinema |
| Section | `lib/ui/core/widgets/pauloflix_movies_section.dart` | Carrossel estilo Netflix |
| Home | `lib/ui/pauloflix_movies/widgets/pauloflix_movies_home_screen.dart` | Grid + busca + sync |
| Detail | `lib/ui/pauloflix_movies/widgets/pauloflix_movie_detail_screen.dart` | Filme OU coleção |
| Search | `lib/ui/pauloflix_movies/widgets/pauloflix_movies_search_screen.dart` | Busca em tempo real |

### Algoritmo de Limpeza de Nomes (on-demand, `inspectFolder`)

Usado apenas pela tela de detalhe (scraping on-demand). O nome da pasta é limpo para busca TMDB:

1. Remove extensão (`.mkv`/`.mp4`)
2. Remove ano entre parênteses: `(2010)`, `[1985]`
3. Remove tags decorativas (case-insensitive):
   - Qualidade: `1080p`, `720p`, `4K`, `BluRay`, `WEB-DL`, `Open.Matte`, `Directors.Cut`, etc.
   - Codecs: `x264`, `x265`, `HEVC`, `AV1`, `10bit`, etc.
   - Áudio: `DUAL`, `Dublado`, `5.1`, `AAC`, etc.
   - Grupos: `WWW.BLUDV.COM`, `GalaxyRG`, `YTS.MX`, `KONTRAST`, `RARBG`, etc.
4. Normaliza: múltiplos espaços → 1, remove pontuação

**Nota:** Este algoritmo **não é mais usado no sync principal** (o JSON index já vem com títulos limpos). Foi mantido para compatibilidade com o fluxo de detalhe on-demand.

### Convenções

- ✅ Comentários em português
- ✅ `package:provider` para state management
- ✅ Drift para persistência (via repository)
- ✅ `debugPrint` com prefixo `[PauloFlix Movies]` para rastreio
- ✅ `ChangeNotifier` providers
