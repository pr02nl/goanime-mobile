# 🎨 Componentes de Interface - Documentação

## Telas (Screens)

### MainNavigationScreen
Tela principal de navegação com bottom navigation bar customizado.

**Características:**
- `IndexedStack` para preservar estado das abas
- Bottom navigation flutuante com glassmorphism
- Ícones Ionicons com animação de escala
- Suporte a voltar para Home ao pressionar back

**Abas:**
1. Home (Ionicons.home)
2. Search (Ionicons.search)
3. Watchlist (Ionicons.bookmark)
4. Downloads (Ionicons.download)
5. Settings (Ionicons.settings)

---

### HomeScreen
Tela inicial com layout inspirado em Netflix/Disney+.

**Características:**
- Banner hero com carrossel automático (PageView)
- Seções horizontais de animes
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

### EpisodeListScreen
Lista de episódios de um anime.

**Características:**
- Grid view ou list view (toggle)
- Thumbnails de episódios com fade-in
- Informações de AniList (score, status, episódios)
- Botão de download por episódio
- Pull-to-refresh

**Layout:**
- Grid: 2 colunas (tablets 3 colunas)
- List: Cards verticais com thumbnail
- Header com cover image do anime

---

### VideoPlayerScreen
Player de vídeo com recursos premium.

**Características:**
- Player nativo (media_kit)
- AniSkip integration (botão de pular intro/outro)
- Fallback WebView para iOS
- Google Video proxy para contornar restrições
- Loading overlay com skeleton
- Error handling com retry

**AniSkip:**
- Detecção automática de intro/outro
- Botão flutuante com animação
- Auto-hide após 15 segundos
- Labels dinâmicas ("Skip Intro", "Skip Outro")

---

### WatchlistScreen
Lista de animes salvos para assistir depois.

**Características:**
- Grid de cards
- Empty state com CTA
- Swipe to delete
- Clear all com confirmação
- Animações de entrada

---

### DownloadsScreen
Gerenciamento de downloads offline.

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

### SettingsScreen
Configurações do aplicativo.

**Características:**
- Switch de idioma (PT/EN)
- Toggle de tema (Dark only)
- Opções de download
- Clear cache
- Sobre / Créditos

---

## Widgets Reutilizáveis

### AnimeCard
Card padrão para exibição de anime.

**Props:**
```dart
AnimeCard({
  required JikanAnime anime,
  required VoidCallback onTap,
  double? width,
  double? height,
})
```

**Características:**
- Aspect ratio 2:3
- CachedNetworkImage com placeholder
- Fade-in animation
- Rating badge (score)

---

### ResponsiveAnimeCard
Versão responsiva do AnimeCard.

**Características:**
- Ajusta tamanho baseado na largura da tela
- Layout adaptativo para tablets

---

### AnimeSection
Seção horizontal de animes (estilo Netflix).

**Props:**
```dart
AnimeSection({
  required String title,
  required IconData icon,
  required List<JikanAnime> animes,
  bool isLoading = false,
  String? sectionId,
  int? genreId,
})
```

**Características:**
- Header com título e ícone
- Lista horizontal scrollável
- Botão "Ver Todos"
- Shimmer loading
- Navigation para GenreAnimesScreen

---

### ShimmerLoading
Efeito de loading skeleton.

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

---

### DownloadButton
Botão de download de episódio.

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

## Tema (Theme)

### AppColors
Paleta de cores centralizada.

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

---

## Responsividade

### Responsive Utilities

**Breakpoints:**
- Mobile: < 600px
- Tablet: 600px - 900px
- Desktop: > 900px

**Funções:**
```dart
// Responsive
bool isMobile(BuildContext context)
bool isTablet(BuildContext context)
bool isDesktop(BuildContext context)

// Grid columns
int getCrossAxisCount(BuildContext context)

// Spacing
EdgeInsets getResponsivePadding(BuildContext context)
```

---

## Animações

### Durações Padrão (PerformanceConfig)
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
