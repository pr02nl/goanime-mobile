# 📱 PauloFlix - Documentação Técnica

## Visão Geral

**PauloFlix** é um aplicativo Flutter de streaming de anime que oferece uma experiência premium inspirada em plataformas como Netflix, Disney+ e HBO Max. O app consome múltiplas fontes de dados para fornecer informações ricas sobre animes e permite assistir a episódios de diversas fontes.

---

## 🏗️ Arquitetura do Projeto

### Estrutura de Diretórios

```
lib/
├── main.dart                    # Ponto de entrada e models principais
├── l10n/
│   └── app_localizations.dart   # Internacionalização (PT/EN)
├── models/
│   ├── jikan_models.dart        # Modelos da API Jikan (MyAnimeList)
│   ├── anilist_models.dart      # Modelos da API AniList
│   ├── aniskip_models.dart      # Modelos da API AniSkip
│   └── watchlist_anime.dart     # Modelo para watchlist local
├── screens/
│   ├── main_navigation_screen.dart  # Navegação principal (bottom nav)
│   ├── home_screen.dart         # Tela inicial com banners e seções
│   ├── search_screen.dart       # Busca com filtros de gênero
│   ├── episode_list_screen.dart   # Lista de episódios do anime
│   ├── video_player_screen.dart   # Player de vídeo com AniSkip
│   ├── watchlist_screen.dart    # Lista de animes salvos
│   ├── downloads_screen.dart    # Gerenciamento de downloads
│   ├── settings_screen.dart     # Configurações do app
│   ├── source_selection_screen.dart  # Escolha da fonte de streaming
│   └── genre_animes_screen.dart # Animes por gênero
├── services/
│   ├── jikan_service.dart       # API Jikan (dados de animes)
│   ├── anilist_service.dart     # API AniList (metadados ricos)
│   ├── aniskip_service.dart     # API AniSkip (pular intro/outro)
│   ├── download_service.dart    # Gerenciamento de downloads
│   ├── watchlist_service.dart   # Persistência de watchlist
│   ├── search_history_service.dart  # Histórico de busca
│   ├── episode_thumbnail_service.dart   # Thumbnails de episódios
│   └── locale_service.dart      # Gerenciamento de idioma
├── theme/
│   └── app_colors.dart          # Paleta de cores (Netflix-style)
├── utils/
│   ├── performance_config.dart  # Otimizações de performance
│   └── responsive.dart          # Utilitários responsivos
├── widgets/
│   ├── anime_card.dart          # Card de anime
│   ├── anime_section.dart       # Seção horizontal de animes
│   ├── download_button.dart     # Botão de download
│   ├── watchlist_button.dart    # Botão de watchlist
│   ├── skip_button.dart         # Botão de pular intro/outro
│   ├── shimmer_loading.dart     # Efeito de loading
│   ├── responsive_anime_card.dart   # Card responsivo
│   └── genre_glyph_icon.dart    # Ícones de gênero
└── google_video_proxy.dart      # Proxy para streaming Google Video
```

---

## 🎨 Sistema de Design

### Paleta de Cores (Netflix/Disney+ Style)

Baseada em fundo preto puro (#000000) com acentos vibrantes:

| Cor                | Hex       | Uso                          |
| ------------------ | --------- | ---------------------------- |
| Primary (Cyan)     | `#00BCD4` | Botões, destaques, interação |
| Secondary (Purple) | `#7C4DFF` | Premium, conteúdo especial   |
| Accent (Pink)      | `#FF4081` | CTAs, ações importantes      |
| Surface            | `#141414` | Cards (estilo Netflix)       |
| Text Primary       | `#FFFFFF` | Texto principal              |
| Text Secondary     | `#B3B3B3` | Texto secundário             |

### Tipografia e Layout

- Design **content-first**: conteúdo em destaque, UI minimalista
- Banners hero com carrossel automático (PageView)
- Cards com aspect ratio 2:3 (pôster de anime)
- Bottom navigation flutuante com glassmorphism

---

## 🌐 APIs Integradas

### 1. **Jikan API** (MyAnimeList)

- **Base URL**: `https://api.jikan.moe/v4`
- **Uso**: Dados de animes, top rankings, temporadas, gêneros
- **Cache**: 30 minutos em memória + persistente (SharedPreferences)
- **Otimização**: Carregamento paralelo em batches (rate limiting)

### 2. **AniList API** (GraphQL)

- **Base URL**: `https://graphql.anilist.co`
- **Uso**: Metadados enriquecidos, imagens de capa, banners, scores
- **Funcionalidades**:
  - Busca por título (com limpeza inteligente)
  - Busca por MAL ID
  - Busca por AniList ID

### 3. **AniSkip API**

- **Base URL**: `https://api.aniskip.com/v2`
- **Uso**: Timestamps para pular intro e outro automaticamente
- **Estratégia**: Tenta MAL ID primeiro, depois AniList ID

---

## 💾 Persistência Local

> **⚠️ Estado atual:** 4 bancos SQLite brutos + 1 Drift não exercitado + 1 helper
> zumbi. Plano de unificação em [`DATABASE_REFACTORING.md`](./DATABASE_REFACTORING.md)
> (alvo: 1 banco Drift único com migrations versionadas).

### SQLite (sqlite3)

|| Tabela      | Banco                | Propósito                           |
|| ----------- | -------------------- | ----------------------------------- |
|| `anime`     | `anime.db`           | Cache de nomes de anime **(zumbi write-only — a remover)** |
|| `watchlist` | `watchlist.db`       | Animes salvos para assistir depois  |
|| `downloads` | `downloads.db`       | Metadados de downloads de episódios |
|| `pauloflix_content` | `pauloflix.db` | Cache de animes PauloFlix           |
|| `pauloflix_movies` | `pauloflix_movies.db` | Cache de filmes PauloFlix    |

### Drift (gerado, não instanciado)

`AppDatabase` declarado em `lib/core/database/app_database.dart` referencia as
tabelas `WatchlistItems`, `Downloads`, `PauloFlixContent`. Nenhuma instanciação
em runtime — ver `DATABASE_REFACTORING.md` para reativação.

### SharedPreferences

- Cache de dados da Home (30 minutos)
- Histórico de busca
- Preferências de idioma

---

## 🎬 Funcionalidades do Player de Vídeo

### Tecnologias

- **media_kit**: Player nativo Flutter de alta performance (substitui video_player + chewie)
- **Google Video Proxy**: Para contornar restrições de referrer

### Recursos Premium

1. **AniSkip Integration**: Botão flutuante para pular intro/outro
   - Detecção automática baseada no tempo do vídeo
   - Auto-hide após 15 segundos
   - Suporte a MAL ID e AniList ID

2. **Qualidade Adaptativa**: Seleção automática de servidor (Google Video, Blogger)

3. **Fallback WebView**: Para iOS quando o player nativo falha

4. **Download para Offline**: Baixar episódios para assistir sem internet

---

## ⚡ Otimizações de Performance

### Cache de Imagens

```dart
// Cache aumentado para 200MB
PaintingBinding.instance.imageCache.maximumSize = 500;
PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;
```

### Carregamento da Home

- **Paralelização**: 6 requisições em 2 batches (rate limit Jikan)
- **Cache em memória**: Dados persistem durante a sessão
- **Cache persistente**: SharedPreferences para inicialização rápida
- **Pre-cache de imagens**: Thumbnails do banner carregadas antecipadamente

### Listas Otimizadas

- `AutomaticKeepAliveClientMixin` para manter estado das abas
- `IndexedStack` na navegação principal para preservar estado
- Shimmer loading em vez de spinners tradicionais

---

## 🌍 Internacionalização

Suporte a dois idiomas:

- **Português (PT-BR)** - Idioma padrão
- **Inglês (EN-US)**

Implementação customizada via `AppLocalizations` com traduções inline.

---

## 📦 Dependências Principais

| Pacote               | Versão   | Propósito                                        |
| -------------------- | -------- | ------------------------------------------------ |
| media_kit            | ^1.2.6   | Player de vídeo/audio nativo de alta performance |
| media_kit_video      | ^2.0.1   | Widget de vídeo para media_kit                   |
| media_kit_libs_video | ^1.0.7   | Bibliotecas nativas de vídeo                     |
| http                 | ^1.1.0   | Requisições HTTP                                 |
| html                 | ^0.15.4  | Parsing de HTML                                  |
| sqlite3              | ^3.3.3   | Banco de dados local (FFI)                       |
| cached_network_image | ^3.3.1   | Cache de imagens                                 |
| shared_preferences   | ^2.2.2   | Preferências locais                              |
| provider             | ^6.1.1   | State management                                 |
| webview_flutter      | ^4.5.0   | Fallback de vídeo                                |
| ionicons             | ^0.2.2   | Ícones Ionic                                     |
| lucide_icons         | ^0.257.0 | Ícones Lucide                                    |
| bottom_navy_bar      | ^6.0.0   | Nav bar customizada                              |

---

## 🔄 Fluxo de Dados

```
1. Home Screen
   ↓
JikanService.loadHomeData() → Cache → UI (Banner + Seções)

2. Busca
   ↓
SearchScreen → JikanService.searchAnime() → Resultados

3. Seleção de Anime
   ↓
SourceSelectionScreen → AniListService (metadados)
   ↓
EpisodeListScreen → Episode thumbnail fetching

4. Player
   ↓
VideoPlayerScreen → AniSkipService (skip times) + Streaming
```

---

## 🚀 Pontos Fortes do Projeto

1. **Arquitetura limpa** com separação clara de responsabilidades
2. **Múltiplas fontes de dados** com fallback inteligente
3. **Sistema de cache robusto** (memória + persistente)
4. **UI premium** inspirada em grandes plataformas de streaming
5. **Experiência offline** com downloads locais
6. **AniSkip integrado** para UX superior no player
7. **Internacionalização** pronta para expansão

---

## 📝 Notas Técnicas

- **SDK**: Dart ^3.9.2
- **Padrão de estado**: Provider (ChangeNotifier)
- **Tema**: Dark mode obrigatório (Netflix-style)
- **Plataformas**: Android, iOS (com tratamento especial para streaming no iOS)
- **Performance**: Otimizado para 60fps com caching agressivo

---

## 📄 Arquivos de Documentação Detalhada

- [APIs.md](./APIs.md) - Documentação das APIs integradas
- [Services.md](./Services.md) - Detalhes dos serviços
- [Models.md](./Models.md) - Estrutura de dados
- [UI.md](./UI.md) - Componentes de interface
- [IMPROVEMENT_PLAN.md](./IMPROVEMENT_PLAN.md) - Plano completo de melhorias técnicas (MVVM, Provider, go_router, drift, freezed, Repository Pattern) - **Alinhado com [recomendações oficiais do Flutter](https://docs.flutter.dev/app-architecture/guide)**
