# 📱 PauloFlix - Documentação Técnica

## Visão Geral

**PauloFlix** é um aplicativo Flutter de streaming de anime que oferece uma experiência premium inspirada em plataformas como Netflix, Disney+ e HBO Max. O app consome múltiplas fontes de dados para fornecer informações ricas sobre animes e permite assistir a episódios de diversas fontes.

---

## 🏗️ Arquitetura do Projeto

### Estrutura de Diretórios

```
lib/
├── main.dart                       # Ponto de entrada, boot (AppDatabase, JWT, DownloadService)
├── app.dart                        # MaterialApp, MultiProvider, go_router
├── l10n/                           # Internacionalização (PT/EN)
├── routing/
│   ├── app_router.dart             # go_router (rotas + ShellRoute)
│   └── route_data.dart             # Typed route extras
├── core/
│   ├── constants/
│   │   ├── api_constants.dart      # URLs, endpoints (incl. tvIndexUrl, movieIndexUrl)
│   │   └── app_constants.dart      # SharedPreferences keys
│   ├── database/                   # Drift — fonte de verdade
│   │   ├── app_database.dart       # @DriftDatabase (7 tabelas)
│   │   ├── connection/connection.dart  # LazyDatabase + path resolution
│   │   └── tables/                 # WatchlistItems, Downloads, PauloFlixContent,
│   │                                # PauloFlixMovies, PauloFlixSeasons,
│   │                                # PauloFlixEpisodes, EpisodeProgress
│   ├── errors/                     # Tratamento de erros
│   ├── logger/                     # Logging
│   ├── network/                    # Infraestrutura de rede
│   └── utils/                      # genre_codec, url_codec, performance_config,
│                                    # responsive, tv_detector, text_utils
├── domain/                         # Camada de domínio (pura, sem dependências externas)
│   ├── models/                     # Modelos de domínio
│   │   ├── anime.dart, episode.dart
│   │   ├── pauloflix_content.dart, pauloflix_movie.dart
│   │   ├── pauloflix_models.dart (season, episode)
│   │   └── ...
│   └── repositories/              # Interfaces dos repositories (5)
├── data/                           # Implementações de dados
│   ├── models/                     # Modelos de API externa
│   │   ├── jikan_models.dart, anilist_models.dart
│   │   ├── introdb_models.dart, tmdb_models.dart
│   ├── repositories/              # Implementações Drift (5 impls)
│   │   ├── *repository_impl.dart
│   └── services/                   # Services de I/O, scraping, sync
│       ├── auth/                   # AuthenticatedHttpClient, JwtTokenManager
│       ├── kodi/                   # KodiNfoParser, KodiNfoModels, PauloFlixNfoEnricher
│       ├── pauloflix_service.dart          # Sync JSON index (TV)
│       ├── pauloflix_movies_service.dart   # Sync JSON index (Movies)
│       ├── paulo_flix_episode_sync_service.dart  # Sync episodes on-demand
│       ├── download_service.dart            # Fila HTTP + persistência
│       ├── jikan_service.dart, anilist_service.dart
│       ├── introdb_service.dart, tmdb_service.dart
│       ├── anime_service.dart, episode_thumbnail_service.dart
│       └── search_history_service.dart, tv_api_key_server.dart
└── ui/                             # Interface do usuário
    ├── core/
    │   ├── themes/                 # AppTheme, AppColors, NetflixTheme, TVTheme
    │   ├── utils/                  # Responsive, PerformanceConfig, TVDetector
    │   ├── view_models/            # LocaleViewModel
    │   └── widgets/                # AnimeCard, NetflixCard, NetflixCarousel,
    │                                # FocusableWidget, ShimmerLoading, etc.
    ├── home/                       # HomeScreen, AnimeDetailScreen, GenreAnimesScreen
    ├── navigation/                 # MainNavigationScreen (ShellRoute)
    ├── pauloflix/                  # PauloFlix (TV shows)
    ├── pauloflix_movies/           # PauloFlix Movies
    ├── player/                     # VideoPlayerScreen, ModernEpisodeListScreen
    ├── search/                     # SearchScreen, SourceSelectionScreen
    ├── settings/                   # SettingsScreen
    ├── watchlist/                  # WatchlistScreen
    └── downloads/                  # DownloadsScreen
```

---

## 🎨 Sistema de Design

### Paleta de Cores (Netflix/Disney+ Style)

Baseada em fundo preto puro (#000000) com acentos vibrantes:

| Cor | Hex | Uso |
| --- | --- | --- |
| Primary (Cyan) | `#00BCD4` | Botões, destaques, interação |
| Secondary (Purple) | `#7C4DFF` | Premium, conteúdo especial |
| Accent (Pink) | `#FF4081` | CTAs, ações importantes |
| Surface | `#141414` | Cards (estilo Netflix) |
| Text Primary | `#FFFFFF` | Texto principal |
| Text Secondary | `#B3B3B3` | Texto secundário |

---

## 🌐 APIs Integradas

### 1. **PauloFlix JSON Index** (sync principal)
- **TV:** `GET /tvshows/tv_index.json` — índice completo de shows
- **Movies:** `GET /movies/movie_index.json` — índice completo de filmes
- Substitui scraping HTML + APIs externas como fonte primária

### 2. **AniList API** (GraphQL) — Metadados enriquecidos
### 3. **TheIntroDB API** — Skip intro/outro
### 4. **TMDB API** — Fallback de metadados

---

## 💾 Persistência Local

**Banco único** (`pauloflix.db`) gerenciado por **Drift**, com **7 tabelas** e migrations versionadas.

| Tabela | Conteúdo |
| ------ | -------- |
| `watchlist_items` | Animes salvos para assistir depois |
| `downloads` | Metadados de downloads de episódios |
| `paulo_flix_content` | Cache de animes PauloFlix |
| `paulo_flix_movies` | Cache de filmes PauloFlix |
| `paulo_flix_seasons` | Seasons dos shows |
| `paulo_flix_episodes` | Episódios com metadados |
| `episode_progress` | Progresso do usuário por episódio |

**SharedPreferences:**
- Cache de dados da Home (30 min)
- Histórico de busca
- Preferências de idioma
- API key do TMDB

---

## 🎬 Funcionalidades do Player de Vídeo

### Tecnologias
- **media_kit**: Player nativo Flutter de alta performance
- **Google Video Proxy**: Para contornar restrições de referrer
- **TheIntroDB**: Pular intro/outro automaticamente
- **Fallback WebView**: Para iOS quando o player nativo falha

### Recursos
- Qualidade adaptativa (Google Video, Blogger)
- Download para offline
- Legendas `.srt` (prioridade PT-BR)

---

## 📦 Dependências Principais

| Pacote | Versão | Propósito |
| ------ | ------ | --------- |
| media_kit | ^1.2.6 | Player de vídeo nativo |
| media_kit_video | ^2.0.1 | Widget de vídeo |
| media_kit_libs_video | ^1.0.7 | Bibliotecas nativas |
| drift | ^2.34.0 | ORM type-safe (persistência principal) |
| go_router | ^17.3.0 | Navegação type-safe |
| provider | ^6.1.5+1 | State management |
| http | ^1.6.0 | Requisições HTTP |
| html | ^0.15.6 | Parsing HTML (fallback scraping) |
| xml | ^7.0.1 | Parsing NFO (Kodi) |
| dio | ^5.7.0 | HTTP client com interceptors |
| cached_network_image | ^3.4.1 | Cache de imagens |
| cryptography_plus | ^3.0.0 | JWT Ed25519 signing |

---

## 🔄 Fluxo de Dados

```
1. Boot (main.dart)
   ├── JwtTokenManager.initialize()          → Auth JWT
   ├── AppDatabase()                         → Drift (migration automática)
   ├── DownloadService.withRepository(...)    → Fila de downloads
   └── configure(authClient) → PauloFlixService, PauloFlixMoviesService

2. Sync de Shows (PauloFlixService.syncContent)
   GET tv_index.json → parse → repository.saveBatch() → Drift

3. Sync de Filmes (PauloFlixMoviesService.syncContent)
   GET movie_index.json → parse → repository.saveBatch() → Drift

4. Player
   VideoPlayerScreen → IntroDbService (skip times) + Streaming
```

## 📄 Documentação Detalhada

- [Services.md](./Services.md) — Detalhes dos services ativos
- [Models.md](./Models.md) — Estrutura de dados e factories
- [APIs.md](./APIs.md) — Documentação das APIs integradas
- [UI.md](./UI.md) — Componentes de interface
- [PAULOFLIX_MOVIES.md](./PAULOFLIX_MOVIES.md) — Detalhes da área de filmes
- [TV_SUPPORT.md](./TV_SUPPORT.md) — Suporte a Android TV
- [NETFLIX_REFACTORING.md](./NETFLIX_REFACTORING.md) — Netflix UI/UX
- [archive/DATABASE_REFACTORING.md](./archive/DATABASE_REFACTORING.md) — Histórico da refatoração do banco (5 fases concluídas)
