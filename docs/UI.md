# 🎨 Componentes de Interface - Documentação

## Telas (Screens)

### MainNavigationScreen
Tela principal de navegação com bottom navigation bar customizado.

**Arquivo:** `lib/ui/navigation/main_navigation_screen.dart`

**Características:**
- `IndexedStack` para preservar estado das abas
- Bottom navigation flutuante com glassmorphism
- Ícones Ionicons com animação de escala
- Suporte a voltar para Home ao pressionar back
- ContentTypeSelector (pill "Animes | Filmes") no AppBar

**Abas:**
1. Home (Ionicons.home)
2. Search (Ionicons.search)
3. Watchlist (Ionicons.bookmark)
4. Downloads (Ionicons.download)
5. Settings (Ionicons.settings)

---

### HomeScreen
Tela inicial exibindo conteúdo PauloFlix.

**Arquivo:** `lib/ui/home/widgets/home_screen.dart`

**Características:**
- Seção PauloFlix (animes do banco Drift)
- Pull-to-refresh (re-sync do conteúdo)

---

### SearchScreen
Tela de busca — hub de navegação para as telas de busca PauloFlix.

**Arquivo:** `lib/ui/search/widgets/search_screen.dart`

**Características:**
- Opções de busca: PauloFlix (animes), PauloFlix (filmes)
- Redireciona para `/pauloflix-search`, `/pauloflix-movies-search`

---

### ModernVideoPlayerScreen
Player de vídeo principal (media_kit).

**Arquivo:** `lib/ui/player/widgets/video_player_screen.dart`

**Características:**
- Player nativo (media_kit)
- TheIntroDB integration (botão de pular intro/outro)
- Legendas `.srt` (prioridade PT-BR)
- Loading overlay com skeleton
- Error handling com retry
- Auto-play próximo episódio (PauloFlix)

**TheIntroDB:**
- Detecção automática de intro/outro via api.theintrodb.org
- Botão flutuante com animação
- Auto-hide após 15 segundos
- Labels dinâmicas ("Skip Intro", "Skip Outro")

**Progresso:**
- Grava posição a cada 5s + ao sair
- Retoma de onde parou (≥ 10%)
- Marca como completo (≥ 90%)

---


### WatchlistScreen
Lista de animes salvos para assistir depois.

**Arquivo:** `lib/ui/watchlist/widgets/watchlist_screen.dart`

**Características:**
- Grid de cards
- Empty state com CTA
- Clear all com confirmação
- Animações de entrada

---

### DownloadsScreen
Gerenciamento de downloads offline.

**Arquivo:** `lib/ui/downloads/widgets/downloads_screen.dart`

**Características:**
- Tabs: Active / Completed
- Progresso em tempo real
- Ações: Pause, Resume, Cancel, Retry, Delete
- Preview do vídeo baixado
- Settings para limitar downloads concorrentes

---

### PauloFlixEpisodeListScreen
Lista de episódios/seasons de um show PauloFlix (lê do banco Drift, populado pelo sync do JSON index).

**Arquivo:** `lib/ui/pauloflix/widgets/pauloflix_episode_list_screen.dart`

**Características:**
- Seasons em abas (tab bar)
- Episódios em grid por season
- Thumbnails do servidor (se disponíveis)
- Progresso do usuário (assistido, posição)
- Botão de download por episódio
- Dados reativos via streams Drift (`watchSeasonsForContent`, `watchEpisodesForSeason`)

---

### PauloFlixSearchScreen
Busca de animes PauloFlix no banco local.

**Arquivo:** `lib/ui/pauloflix/widgets/pauloflix_search_screen.dart`

**Características:**
- Busca por título em tempo real
- Grid responsivo com resultados
- Empty state quando sem resultados
- TV: grid adaptativo, D-pad navigation

---

### PauloFlixSeeAllScreen
Lista completa + sync de animes PauloFlix.

**Arquivo:** `lib/ui/pauloflix/widgets/pauloflix_see_all_screen.dart`

**Características:**
- Grid de todos os shows disponíveis
- Botão sync (dispara `PauloFlixService.syncContent`)
- Barra de progresso durante sync
- Pull-to-refresh
- TV: D-pad navigation

---

### PauloFlixMoviesHomeScreen
Tela principal da área de Filmes do PauloFlix.

**Arquivo:** `lib/ui/pauloflix_movies/widgets/pauloflix_movies_home_screen.dart`

**Características:**
- Grid responsivo de filmes com posters do servidor (JSON index)
- Busca em tempo real
- Sync manual via botão refresh (dispara `PauloFlixMoviesService.syncContent`)
- TV: grid adaptativo (6 colunas), D-pad navigation

---

### PauloFlixMovieDetailScreen
Tela de detalhe de filme.

**Arquivo:** `lib/ui/pauloflix_movies/widgets/pauloflix_movie_detail_screen.dart`

**Características:**
- Backdrop + poster + sinopse + botão Assistir
- Reutiliza `VideoPlayerScreen` para reprodução
- Suporte a legendas `.srt` (prioridade PT-BR)
- TV: FocusableWidget nos sub-filmes

---

### PauloFlixMoviesSearchScreen
Busca de filmes PauloFlix.

**Arquivo:** `lib/ui/pauloflix_movies/widgets/pauloflix_movies_search_screen.dart`

**Características:**
- Busca por título (filtra em tempo real no banco local)
- Grid responsivo com resultados
- Empty state quando sem resultados

---

### SettingsScreen
Configurações do aplicativo.

**Arquivo:** `lib/ui/settings/widgets/settings_screen.dart`

**Características:**
- Switch de idioma (PT/EN)
- Toggle de tema (Dark only)
- Opções de download
- Clear cache
- Sobre / Créditos

---

## Widgets Reutilizáveis

---

### NetflixCard / NetflixHeroCard / NetflixCarousel
Componentes Netflix-style.

**Arquivos:**
- `lib/ui/core/widgets/netflix_card.dart` — Card com hover effects e scale animation
- `lib/ui/core/widgets/netflix_hero_card.dart` — Banner hero com gradiente e botões de ação
- `lib/ui/core/widgets/netflix_carousel.dart` — Carrossel horizontal com navigation buttons

**Características:**
- Suporte a TV navigation (FocusableWidget)
- Animação suave (300ms easeInOutCubic)
- Shadow dinâmica (elevada no hover)
- Rating badge estilizado
- Gradient overlay para legibilidade

---

### ShimmerLoading
Efeito de loading skeleton.

**Arquivo:** `lib/ui/core/widgets/shimmer_loading.dart`

---

### WatchlistButton
Botão de adicionar/remover da watchlist.

**Arquivo:** `lib/ui/core/widgets/watchlist_button.dart`

**Características:**
- Animação de pulse ao adicionar
- Ícone muda de bookmark_outline para bookmark
- Snackbar de confirmação

---

### DownloadButton
Botão de download de episódio.

**Arquivo:** `lib/ui/downloads/widgets/download_button.dart`

**Estados:**
- **Idle**: Ícone de download
- **Queued**: Ícone de fila
- **Downloading**: Progress indicator
- **Paused**: Ícone de pause
- **Completed**: Ícone de check
- **Failed**: Ícone de erro com retry

---

### SkipButton
Botão de pular intro/outro (TheIntroDB).

**Arquivo:** `lib/ui/core/widgets/skip_button.dart`

**Características:**
- Animação de slide-in
- Auto-hide após 15 segundos
- Label dinâmica
- Contador regressivo (opcional)

---

### ContentTypeSelector
Pill seletor "Animes | Filmes" no AppBar do MainNavigationScreen.

**Arquivo:** `lib/ui/core/widgets/content_type_selector.dart`

---

### ProgressOverlay
Widget de overlay de progresso para cards, unificando a exibição entre filmes (tema vermelho) e animes (tema roxo).

**Arquivo:** `lib/ui/core/widgets/progress_overlay.dart`

**Comportamento:**
| `isCompleted` | `ratio` | Resultado |
|:---:|:---:|---|
| `true` | qualquer | Badge verde "✓ Completo" |
| `false` | `> 0` | Barra de progresso + `fractionText` opcional |
| `false` | `== 0` | `null` (sem overlay) |

---

### CompletedBadge
Badge verde "✓ Completo" com 3 variantes pré-definidas.

**Arquivo:** `lib/ui/core/widgets/completed_badge.dart`

---

### FocusableWidget / TVGridView / TVSafeTextField
Widgets otimizados para Android TV.

**Arquivos:**
- `lib/ui/core/widgets/focusable_widget.dart` — Focus + D-pad
- `lib/ui/core/widgets/tv_grid_view.dart` — Grid com navegação D-pad
- `lib/ui/core/widgets/tv_safe_text_field.dart` — TextField seguro para TV

---

### PauloFlixBadge / PauloFlixMoviesBadge
Badges de conteúdo.

**Arquivos:**
- `lib/ui/core/widgets/pauloflix_badge.dart` — Badge azul para animes
- `lib/ui/core/widgets/pauloflix_movies_badge.dart` — Badge vermelho para filmes

---

### PauloFlixSection / PauloFlixMoviesSection
Seções horizontais.

**Arquivos:**
- `lib/ui/pauloflix/widgets/pauloflix_section.dart` — Seção de animes
- `lib/ui/pauloflix_movies/widgets/pauloflix_movies_section.dart` — Seção de filmes

---

## Tema (Theme)

### AppColors
Paleta de cores centralizada.

**Arquivo:** `lib/ui/core/themes/app_colors.dart`

### AppTheme / NetflixTheme / TVTheme

**Arquivos:**
- `lib/ui/core/themes/app_theme.dart` — Tema unificado (Netflix + TV)
- `lib/ui/core/themes/netflix_theme.dart` — Cores e animações Netflix
- `lib/ui/core/themes/tv_theme.dart` — Fontes e espaçamentos TV

---

## Responsividade

### Responsive Utilities

**Arquivo:** `lib/ui/core/utils/responsive.dart`

**Breakpoints:**
- Mobile: < 600px
- Tablet: 600px - 900px
- Desktop: > 900px

---

## Animações

### Durações Padrão (PerformanceConfig)

**Arquivo:** `lib/ui/core/utils/performance_config.dart`

```dart
fastAnimation: Duration(milliseconds: 150)
mediumAnimation: Duration(milliseconds: 250)
slowAnimation: Duration(milliseconds: 400)
```

---

## Internacionalização (i18n)

### AppLocalizations
Suporte a PT-BR e EN-US.

**Arquivo:** `lib/l10n/app_localizations.dart`
