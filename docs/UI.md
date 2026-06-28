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
Tela inicial com layout inspirado em Netflix/Disney+.

**Arquivo:** `lib/ui/home/widgets/home_screen.dart`

**Características:**
- Banner hero com carrossel automático (PageView)
- Seções horizontais de animes (Jikan API)
- Seção PauloFlix animes e filmes (do banco Drift)
- Pull-to-refresh
- FAB animado (voltar ao topo)
- Header com blur effect

**Seções:**
1. **Destaques da Temporada** - Animes em exibição (Jikan API)
2. **Top Animes** - Mais bem avaliados
3. **Ação** - Gênero Action
4. **Romance** - Gênero Romance
5. **Comédia** - Gênero Comedy
6. **Fantasia** - Gênero Fantasy

**Otimizações:**
- `AutomaticKeepAliveClientMixin` para manter estado
- Pre-cache de imagens de banner
- Shimmer loading durante carregamento

---

### SearchScreen
Tela de busca com histórico e filtros.

**Arquivo:** `lib/ui/search/widgets/search_screen.dart`

**Características:**
- Search bar com focus node
- Debounce de 500ms para busca automática
- Histórico de buscas (até 20 itens)
- Sugestões baseadas no histórico
- Filtros de gênero com ícones
- Animes em alta (trending)

**Filtros de Gênero:**
- Action (Icons.flash_on)
- Adventure (Icons.explore)
- Comedy (Icons.emoji_emotions)
- Drama (Icons.theater_comedy)
- Fantasy (Icons.auto_awesome)
- Horror (Icons.dark_mode)
- Mystery (Icons.search)
- Romance (Icons.favorite)
- Sci-Fi (Icons.rocket_launch)
- Slice of Life (Icons.wb_sunny)
- Sports (Icons.sports_soccer)
- Supernatural (Icons.auto_fix_high)

---

### AnimeDetailScreen
Tela de detalhe de anime (Jikan + AniList).

**Arquivo:** `lib/ui/home/widgets/anime_detail_screen.dart`

**Características:**
- Banner + poster do anime
- Sinopse, score, gêneros, status
- Botão de assistir → EpisodeListScreen
- WatchlistButton integrado

---

### GenreAnimesScreen
Lista de animes filtrados por gênero.

**Arquivo:** `lib/ui/home/widgets/genre_animes_screen.dart`

**Características:**
- Gradient header customizado por gênero
- Grid responsivo de cards
- Paginação via Jikan API

---

### EpisodeListScreen / ModernEpisodeListScreen
Lista de episódios de um anime (fonte externa, não PauloFlix).

**Arquivo (legado):** `lib/ui/player/widgets/episode_list_screen.dart`
**Arquivo (moderno):** `lib/ui/player/widgets/modern_episode_list_screen.dart`

**Características:**
- Grid view (2 colunas) ou list view (toggle)
- Thumbnails de episódios com fade-in
- Informações de AniList (score, status, episódios)
- Botão de download por episódio
- Pull-to-refresh

---

### ModernVideoPlayerScreen
Player de vídeo principal (media_kit).

**Arquivo:** `lib/ui/player/widgets/video_player_screen.dart`

**Características:**
- Player nativo (media_kit)
- AniSkip integration (botão de pular intro/outro)
- Fallback WebView para iOS
- Google Video proxy para contornar restrições
- Legendas `.srt` (prioridade PT-BR)
- Loading overlay com skeleton
- Error handling com retry

**AniSkip:**
- Detecção automática de intro/outro
- Botão flutuante com animação
- Auto-hide após 15 segundos
- Labels dinâmicas ("Skip Intro", "Skip Outro")

---

### BloggerWebViewScreen
Fallback WebView para streaming no iOS.

**Arquivo:** `lib/ui/player/widgets/blogger_webview_screen.dart`

---

### WatchlistScreen
Lista de animes salvos para assistir depois.

**Arquivo:** `lib/ui/watchlist/widgets/watchlist_screen.dart`

**Características:**
- Grid de cards
- Empty state com CTA
- Swipe to delete
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

**Tabs:**
- **Active**: Downloads em andamento, pausados ou na fila
- **Completed**: Downloads finalizados

---

### PauloFlixEpisodeListScreen
Lista de episódios/seasons de um show PauloFlix (via scraping on-demand).

**Arquivo:** `lib/ui/pauloflix/widgets/pauloflix_episode_list_screen.dart`

**Características:**
- Seasons em abas (tab bar)
- Episódios em grid por season
- Thumbnails do servidor (se disponíveis)
- Progresso do usuário (assistido, posição)
- Botão de download por episódio
- Sync on-demand via `PauloFlixEpisodeSyncService`

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
- Coleções com banner custom + sub-filmes clicáveis
- TV: grid adaptativo (6 colunas), D-pad navigation

---

### PauloFlixMovieDetailScreen
Tela de detalhe de filme ou coleção.

**Arquivo:** `lib/ui/pauloflix_movies/widgets/pauloflix_movie_detail_screen.dart`

**Características:**
- Filme individual: backdrop + poster + sinopse + botão Assistir
- Coleção: banner + lista de sub-filmes clicáveis
- Reutiliza `ModernVideoPlayerScreen` para reprodução (sem AniSkip)
- Suporte a legendas `.srt` (prioridade PT-BR, detectada via `inspectFolder`)
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
- Configuração de API Key TMDB
- Sobre / Créditos

---

## Widgets Reutilizáveis

### AnimeCard
Card padrão para exibição de anime (Jikan + estilo Netflix opcional).

**Arquivo:** `lib/ui/core/widgets/anime_card.dart`

**Props:**
```dart
AnimeCard({
  required JikanAnime anime,
  required VoidCallback onTap,
  bool useNetflixStyle = true,
  double? width,
  double? height,
})
```

**Características:**
- Aspect ratio 2:3
- CachedNetworkImage com placeholder
- Fade-in animation
- Rating badge (score)
- Netflix style: hover effects com scale, gradient overlay

---

### ResponsiveAnimeCard
Versão responsiva do AnimeCard.

**Arquivo:** `lib/ui/core/widgets/responsive_anime_card.dart`

**Características:**
- Ajusta tamanho baseado na largura da tela
- Layout adaptativo para tablets

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

**Uso:**
```dart
ShimmerLoading(
  child: Container(
    width: 120,
    height: 180,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)
```

---

### WatchlistButton
Botão de adicionar/remover da watchlist.

**Arquivo:** `lib/ui/core/widgets/watchlist_button.dart`

**Props:**
```dart
WatchlistButton({
  required String animeId,
  required String title,
  required String coverImage,
  required String myAnimeListUrl,
})
```

**Características:**
- Animação de pulse ao adicionar
- Ícone muda de bookmark_outline para bookmark
- Snackbar de confirmação
- Provider reativo (via WatchlistRepository.watch())

---

### DownloadButton
Botão de download de episódio.

**Arquivo:** `lib/ui/downloads/widgets/download_button.dart`

**Props:**
```dart
DownloadButton({
  required String animeId,
  required String animeName,
  required String episodeNumber,
  required String episodeTitle,
  required String videoUrl,
  required String thumbnailUrl,
})
```

**Estados:**
- **Idle**: Ícone de download
- **Queued**: Ícone de fila
- **Downloading**: Progress indicator
- **Paused**: Ícone de pause
- **Completed**: Ícone de check
- **Failed**: Ícone de erro com retry

---

### SkipButton
Botão de pular intro/outro (AniSkip).

**Arquivo:** `lib/ui/core/widgets/skip_button.dart`

**Props:**
```dart
SkipButton({
  required String label,
  required VoidCallback onPressed,
  required AnimationController animationController,
})
```

**Características:**
- Animação de slide-in
- Auto-hide após 15 segundos
- Label dinâmica
- Contador regressivo (opcional)

---

### GenreGlyphIcon
Ícones de gênero customizados.

**Arquivo:** `lib/ui/core/widgets/genre_glyph_icon.dart`

**Gêneros Suportados:**
- Action (espada)
- Adventure (bússola)
- Comedy (máscara)
- Drama (máscara triste)
- Fantasy (varinha)
- Horror (caveira)
- Mystery (lupa)
- Romance (coração)
- Sci-Fi (foguete)
- Slice of Life (casa)
- Sports (bola)
- Supernatural (estrela)

---

### ContentTypeSelector
Pill seletor "Animes | Filmes" no AppBar do MainNavigationScreen.

**Arquivo:** `lib/ui/core/widgets/content_type_selector.dart`

**Props:**
```dart
ContentTypeSelector({
  required ContentType currentType,
  required ValueChanged<ContentType> onTypeChanged,
})
```

**Características:**
- Toggle animado entre Animes e Filmes
- Visual pill com transição suave

---

### ProgressOverlay
Widget de overlay de progresso para cards, unificando a exibição entre filmes (tema vermelho) e animes (tema roxo).

**Arquivo:** `lib/ui/core/widgets/progress_overlay.dart`

**Uso:**
```dart
NetflixCard(
  overlayWidget: ProgressOverlay.build(
    ratio: 0.5,
    isCompleted: false,
    accentColor: Color(0xFFDC2626), // vermelho filmes
    fractionText: '3/12',            // opcional, usado em animes
  ),
)
```

**Comportamento:**
| `isCompleted` | `ratio` | Resultado |
|:---:|:---:|---|
| `true` | qualquer | Badge verde "✓ Completo" |
| `false` | `> 0` | Barra de progresso + `fractionText` opcional |
| `false` | `== 0` | `null` (sem overlay) |

**Cor da barra:** Controlada por `accentColor`. Vermelho (`#DC2626`) para filmes, Roxo (`#6366F1` = `AppColors.primary`) para animes.

**Testes:** `test/ui/core/widgets/progress_overlay_test.dart` — 10 testes cobrindo null, badge, barra, cores, fractionText.

---

### CompletedBadge
Badge verde "✓ Completo" com 3 variantes pré-definidas.

**Arquivo:** `lib/ui/core/widgets/completed_badge.dart`

**Variantes:**
| Construtor | Tamanho | Fundo | Borda | Uso |
|---|---|---|---|---|
| `.cardOverlay()` | Pequeno (font 9) | Sólido (90%) | Nenhuma | Overlay em cards (`ProgressOverlay`) |
| `.heroBanner()` | Grande (font 13) | Sólido (90%) | `greenAccent` sutil | Canto do hero banner |
| `.detailScreen()` | Médio (font 12) | Translúcido (20%) | `green` | Linha de metadados na tela de detalhes |

```dart
// Card overlay (cards na grid/carrossel)
CompletedBadge.cardOverlay()

// Hero banner (canto superior direito)
CompletedBadge.heroBanner()

// Tela de detalhes (ao lado dos metadados)
CompletedBadge.detailScreen()
```

---

### FocusableWidget
Wrapper genérico para adicionar suporte a D-pad (TV).

**Arquivo:** `lib/ui/core/widgets/focusable_widget.dart`

**Props:**
```dart
FocusableWidget({
  required Widget child,
  required VoidCallback onSelect,
  double scaleAmount = 1.05,
})
```

---

### TVGridView / TVSafeTextField
Widgets otimizados para Android TV.

**Arquivos:**
- `lib/ui/core/widgets/tv_grid_view.dart` — Grid com navegação D-pad
- `lib/ui/core/widgets/tv_safe_text_field.dart` — TextField seguro para TV

---

### PauloFlixBadge
Badge azul para conteúdo PauloFlix (animes).

**Arquivo:** `lib/ui/core/widgets/pauloflix_badge.dart`

---

### PauloFlixMoviesBadge
Badge vermelho para conteúdo PauloFlix Movies (filmes).

**Arquivo:** `lib/ui/core/widgets/pauloflix_movies_badge.dart`

**Props:**
```dart
PauloFlixMoviesBadge({
  bool isCollection = false,
})
```

**Características:**
- Vermelho cinema quando filme individual
- Indicador de coleção quando `isCollection: true`

---

### PauloFlixSection
Seção horizontal de animes PauloFlix no HomeScreen.

**Arquivo:** `lib/ui/pauloflix/widgets/pauloflix_section.dart`

---

### PauloFlixMoviesSection
Seção horizontal de filmes PauloFlix no HomeScreen.

**Arquivo:** `lib/ui/pauloflix_movies/widgets/pauloflix_movies_section.dart`

---

## Tema (Theme)

### AppColors
Paleta de cores centralizada.

**Arquivo:** `lib/ui/core/themes/app_colors.dart`

**Categorias:**
- Primary (Cyan): Interação principal
- Secondary (Purple): Destaques secundários
- Accent (Pink): CTAs e ações
- Background: Puro preto (#000000)
- Surface: Cinza escuro (#141414)
- Text: Branco e tons de cinza
- Status: Success, Warning, Error, Info

**Gradientes:**
- `getPrimaryGradient()`: Cyan gradient
- `getSecondaryGradient()`: Purple gradient
- `getHeroGradient()`: Cyan + Purple

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

**Funções:**
```dart
bool isMobile(BuildContext context)
bool isTablet(BuildContext context)
bool isDesktop(BuildContext context)
int getCrossAxisCount(BuildContext context)
EdgeInsets getResponsivePadding(BuildContext context)
```

---

## Animações

### Durações Padrão (PerformanceConfig)

**Arquivo:** `lib/ui/core/utils/performance_config.dart`

```dart
fastAnimation: Duration(milliseconds: 150)
mediumAnimation: Duration(milliseconds: 250)
slowAnimation: Duration(milliseconds: 400)
```

### Animações Comuns
- **Fade**: Opacity transitions
- **Scale**: Card hover effects
- **Slide**: Skip button entrance
- **Shimmer**: Loading skeletons

---

## Internacionalização (i18n)

### AppLocalizations
Suporte a PT-BR e EN-US.

**Arquivo:** `lib/l10n/app_localizations.dart`

**Categorias de Strings:**
- Common (appName, search, settings, etc)
- Home (trending, topAnime, genres)
- Search (placeholders, filters)
- Episode List (episodes, status, actions)
- Video Player (controls, errors)
- Watchlist (add, remove, empty)
- Downloads (status, actions)

**Uso:**
```dart
final l10n = AppLocalizations.of(context);
text: l10n.searchAnime,
```
