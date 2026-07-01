# 📱 PauloFlix - Documentação Técnica

## Visão Geral

**PauloFlix** é um aplicativo Flutter de streaming que consome exclusivamente o catálogo PauloFlix via JSON indexes (`tv_index.json` / `movie_index.json`). Os índices fornecem todos os metadados (título, descrição, poster, fanart, rating, gêneros, thumbnails, URLs diretas de vídeo), eliminando a necessidade de APIs externas.

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
│   │   ├── api_constants.dart      # URLs do servidor PauloFlix + IntroDB
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
│   │   └── introdb_models.dart     # TheIntroDB API models
│   ├── repositories/              # Implementações Drift (5 impls)
│   │   └── *repository_impl.dart
│   └── services/                   # Services de I/O, sync
│       ├── auth/                   # AuthenticatedHttpClient, JwtTokenManager
│       ├── kodi/                   # KodiNfoParser, KodiNfoModels, PauloFlixNfoEnricher
│       ├── pauloflix_service.dart          # Sync JSON index (TV)
│       ├── pauloflix_movies_service.dart   # Sync JSON index (Movies)
│       ├── paulo_flix_episode_sync_service.dart  # Sync episodes on-demand
│       ├── download_service.dart            # Fila HTTP + persistência
│       ├── introdb_service.dart            # TheIntroDB API
│       └── search_history_service.dart
└── ui/                             # Interface do usuário
    ├── core/
    │   ├── themes/                 # AppTheme, AppColors, NetflixTheme, TVTheme
    │   ├── utils/                  # Responsive, PerformanceConfig, TVDetector
    │   ├── view_models/            # LocaleViewModel
    │   └── widgets/                # NetflixCard, NetflixCarousel, FocusableWidget,
    │                                # ShimmerLoading, SkipButton, etc.
    ├── home/                       # HomeScreen
    ├── navigation/                 # MainNavigationScreen (ShellRoute)
    ├── pauloflix/                  # PauloFlix (TV shows)
    ├── pauloflix_movies/           # PauloFlix Movies
    ├── player/                     # VideoPlayerScreen
    ├── search/                     # SearchScreen
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
- Fonte **única** de dados — substitui todas as APIs externas

### 2. **TheIntroDB API** — Skip intro/outro
- Única API externa mantida

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
- Preferências de idioma

---

## 🎬 Funcionalidades do Player de Vídeo

### Tecnologias
- **media_kit**: Player nativo Flutter de alta performance
- **TheIntroDB**: Pular intro/outro automaticamente

### Recursos
- Download para offline
- Legendas `.srt` (prioridade PT-BR)
- Progresso de playback (salvo a cada 5s + no dispose)

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
