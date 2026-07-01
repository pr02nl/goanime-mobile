# PauloFlix Design System

## Brand Identity
PauloFlix is a premium streaming platform for anime and movies. The design prioritizes **content-first** viewing — deep black backgrounds make posters and video content pop, while vibrant accent colors (cyan, purple, pink) provide clear interactive affordances. The UI is inspired by Netflix, Disney+, and HBO Max, adapted for mobile, tablet, and Android TV.

---

## Colors

### Backgrounds
| Token | Hex | Uso |
|-------|:---:|-----|
| `background-base` | `#000000` | Canvas principal — fundo puro preto |
| `background-light` | `#0A0A0A` | Preto quase sólido para elevação sutil |
| `background-surface` | `#141414` | Cards, modais, seções secundárias |
| `background-surface-light` | `#1E1E1E` | Superfície elevada (containers, inputs) |
| `background-hover` | `#282828` | Hover state de cards e itens |

### Text
| Token | Hex | Uso |
|-------|:---:|-----|
| `text-primary` | `#FFFFFF` | Títulos, texto de alto contraste |
| `text-secondary` | `#B3B3B3` | Descrições, metadados, links secundários |
| `text-tertiary` | `#808080` | Detalhes menores, estados disabled |
| `text-disabled` | `#4D4D4D` | Texto desabilitado |

### Brand & Accents
| Token | Hex | Uso |
|-------|:---:|-----|
| `brand-primary` | `#00BCD4` | **Cyan 500** — interação principal, elementos interativos |
| `brand-primary-light` | `#4DD0E1` | Cyan 300 — hover, light variants |
| `brand-primary-dark` | `#0097A7` | Cyan 700 — pressed states |
| `brand-primary-glow` | `#00E5FF` | Cyan A400 — brilho, foco TV |
| `brand-secondary` | `#7C4DFF` | **Deep Purple A200** — destaques, conteúdo premium |
| `brand-secondary-light` | `#B47CFF` | Purple A100 |
| `brand-secondary-dark` | `#651FFF` | Purple A400 |
| `brand-accent` | `#FF4081` | **Pink A200** — CTAs, ações principais |
| `brand-accent-light` | `#FF80AB` | Pink A100 |
| `brand-accent-dark` | `#F50057` | Pink A400 |

### Netflix Legacy (Compatibilidade)
| Token | Hex | Uso |
|-------|:---:|-----|
| `netflix-red` | `#E50914` | Vermelho Netflix legado (botões, logo) |
| `netflix-red-dark` | `#B20710` | Hover do vermelho Netflix |
| `netflix-red-light` | `#F40612` | Variação mais clara |

### Status
| Token | Hex | Uso |
|-------|:---:|-----|
| `status-success` | `#4CAF50` | Verde — completo, sucesso |
| `status-warning` | `#FFC107` | Âmbar — aviso |
| `status-error` | `#F44336` | Vermelho — erro |
| `status-info` | `#2196F3` | Azul — informativo |

### Feature-specific
| Token | Hex | Uso |
|-------|:---:|-----|
| `quality-tag` | `#9C27B0` | Tag de qualidade (Purple 500) |
| `speed-tag` | `#2196F3` | Tag de velocidade (Blue 500) |
| `cloud-tag` | `#4CAF50` | Tag de cloud (Green 500) |
| `live-indicator` | `#FF5252` | Indicador ao vivo (Red A200) |

### Content-type Accent Colors
| Constante | Hex | Uso |
|-----------|:---:|-----|
| `AppColors.moviesAccent` | `#DC2626` | Vermelho identidade para filmes (barras, badges, loading indicators) |
| `AppColors.animeAccent` | `#6366F1` | Roxo identidade para animes (barras, badges, loading indicators) |

### Overlays Específicos por Contexto
| Contexto | Cor da Barra | Badge Completo |
|----------|:------------:|:--------------:|
| **Filmes** | `AppColors.moviesAccent` (`#DC2626`) | Verde `CompletedBadge` |
| **Animes** | `AppColors.animeAccent` (`#6366F1`) | Verde `CompletedBadge` |

### Gradientes
| Gradiente | Cores | Uso |
|-----------|-------|-----|
| `primary-gradient` | Cyan → Dark Cyan | Botões, destaques |
| `secondary-gradient` | Deep Purple → Dark Purple | Conteúdo premium |
| `accent-gradient` | Pink → Dark Pink | CTAs |
| `hero-gradient` | Cyan → Deep Purple | Banners hero |
| `overlay-gradient` | Transparent → Black (4 stops) | Overlay em imagens hero |
| `fade-gradient` | Black → Transparent → Black | Efeito de fade horizontal |

---

## Typography

### Fonte Principal
**Netflix Sans** (Fallback: Helvetica Neue, Helvetica, Arial, sans-serif)

### Escala Mobile / Tablet
| Style | Size | Weight | Uso |
|-------|:----:|:------:|-----|
| `display-large` / `h1` | 32px | Bold | Hero titles |
| `display-medium` / `h2` | 28px | Bold | Títulos de seção principais |
| `display-small` / `h3` | 24px | Bold | Títulos de seção |
| `headline-medium` / `h4` | 20px | SemiBold | Subtítulos |
| `title-large` | 18px | SemiBold | Títulos de card |
| `title-medium` | 16px | Medium | Títulos de item |
| `body-large` | 16px | Regular | Corpo de texto |
| `body-medium` | 14px | Regular | Corpo secundário, descrições |
| `label-large` | 14px | Medium | Labels, botões |

### Escala TV (30-40% maior)
| Style | Size | Weight |
|-------|:----:|:------:|
| Headline | 48px | Bold |
| Title | 40px | Bold |
| X-Large | 32px | SemiBold |
| Large | 28px | SemiBold |
| Medium | 24px | SemiBold |
| Regular | 20px | Normal |
| Small | 16px | Normal |

### Cores de Texto
- **Dark mode:** `text-primary` (`#FFFFFF`) / `text-secondary` (`#B3B3B3`)
- **Light mode:** `Colors.black87` / `Colors.black54`

---

## Spacing & Grid

### Base Unit: **4px** (NetflixTheme tokens)

| Token | Value | Uso |
|-------|:-----:|-----|
| `NetflixTheme.xs` | 4px | Micro-espaçamentos |
| `NetflixTheme.sm` | 8px | Entre cards, padding pequeno |
| `NetflixTheme.md` | 16px | Padding padrão de seções |
| `NetflixTheme.lg` | 24px | Padding largo, entre seções |
| `NetflixTheme.xl` | 32px | Padding de página |
| `NetflixTheme.xxl` | 48px | Margens grandes |

### TV Spacing
| Token | Value |
|-------|:-----:|
| `TVTheme.spacingSmall` | 12px |
| `TVTheme.spacingRegular` | 20px |
| `TVTheme.spacingMedium` | 28px |
| `TVTheme.spacingLarge` | 36px |
| `TVTheme.spacingXLarge` | 48px |

### Border Radius
| Token | Value | Uso |
|-------|:-----:|-----|
| `NetflixTheme.radiusSm` | 4px | Botões, badges pequenos |
| `NetflixTheme.radiusMd` | 8px | Cards, containers |
| `NetflixTheme.radiusLg` | 12px | Modais, diálogos |
| `NetflixTheme.radiusXl` | 16px | Cards de TV, search bars |

---

## Breakpoints Responsivos

| Device | Width | Grid Columns | Card Width |
|--------|:-----:|:------------:|:----------:|
| **Phone** | < 600px | 2 | 120px |
| **Tablet** | 600px – 1200px | 4 | 150px |
| **TV** | 1200px – 1920px | 6 | 190px |
| **Quest / Ultra-wide** | > 1920px | 8 | 200px |

### Alturas de Componentes por Device
| Componente | Phone | Tablet | TV |
|------------|:-----:|:------:|:--:|
| Banner hero | 260px | 340px | 450px |
| Seção horizontal | 230px | 290px | 360px |
| Card (grid) | 200px | 250px | 300px |

---

## Animações

### Durações
| Token | Duration | Uso |
|-------|:--------:|-----|
| `fastAnimation` / `fastDuration` | 150ms | Micro-interações, hover states |
| `mediumAnimation` / `mediumDuration` | 250–300ms | Transições de cards, expansões |
| `slowAnimation` / `slowDuration` | 400–500ms | Transições de tela, hero |

### Curvas
| Token | Curve | Uso |
|-------|-------|-----|
| `defaultCurve` | `easeInOutCubic` | Transições padrão |
| `fastCurve` | `easeOutCubic` | Entradas rápidas |
| `slowCurve` | `easeInOut` | Transições suaves |

### Efeitos Comuns
- **Card hover**: Scale 1.05x com `easeInOutCubic` 300ms
- **Shimmer loading**: Skeleton pulse animation
- **Skip button**: Slide-in com fade
- **Bottom nav**: Escala suave no ícone selecionado

---

## Shadows

| Token | Blur | Offset | Opacity | Uso |
|-------|:----:|:------:|:-------:|-----|
| `cardShadow` | 8px | (0, 4) | 30% black | Cards padrão |
| `elevatedCardShadow` | 16px | (0, 8) | 50% black | Hover state de cards |
| TV focus elevation | — | — | — | `focusElevation: 8px` |

---

## Componentes Compartilhados

### NetflixCard
Card de poster com hover effect, overlay de título e suporte a TV.

```dart
NetflixCard({
  required String imageUrl,
  String title = '',
  bool showTitle = false,
  bool showRating = false,
  bool isTV = false,
  Widget? overlayWidget,   // ProgressOverlay ou CompletedBadge
  VoidCallback? onTap,
})
```

### NetflixCarousel
Carrossel horizontal com navegação por setas.

```dart
NetflixCarousel({
  required String title,
  required List<Widget> items,
  bool isTV = false,
  double viewportFraction = 0.35,
})
```

### NetflixHeroCard
Banner hero com gradiente e botões de ação.

```dart
NetflixHeroCard({
  required String imageUrl,
  required String title,
  String? subtitle,
  String? description,
  List<Widget>? actions,
})
```

### ProgressOverlay
Overlay de progresso unificado entre filmes (vermelho) e animes (roxo).

```dart
// Static method
ProgressOverlay.build({
  required double ratio,         // 0.0 a 1.0
  required bool isCompleted,
  Color accentColor = Color(0xFFDC2626),  // vermelho filmes
  String? fractionText,         // "3/12" para animes
})
```

**Comportamento:**
| `isCompleted` | `ratio` | Resultado |
|:---:|:---:|---|
| `true` | qualquer | `CompletedBadge.cardOverlay()` |
| `false` | `> 0` | Barra `accentColor` + `fractionText` opcional |
| `false` | `== 0` | `null` (sem overlay) |

### CompletedBadge
Badge verde "✓ Completo" com 3 variantes.

| Construtor | Tamanho | Fundo | Borda | Uso |
|------------|:-------:|:-----:|:-----:|-----|
| `.cardOverlay()` | font 9 | Sólido 90% | Nenhuma | Overlay em cards |
| `.heroBanner()` | font 13 | Sólido 90% | greenAccent | Canto do banner hero |
| `.detailScreen()` | font 12 | Translúcido 20% | green | Metadados em detalhes |

```dart
CompletedBadge.cardOverlay()
CompletedBadge.heroBanner()
CompletedBadge.detailScreen()

// Custom
CompletedBadge(
  padding: EdgeInsets.all(8),
  backgroundColor: Colors.purple,
  borderRadius: 8,
  icon: Icons.star,
  iconColor: Colors.amber,
  ...
)
```

### FocusableWidget
Wrapper genérico para navegação D-pad (Android TV).

```dart
FocusableWidget({
  required Widget child,
  required VoidCallback onSelect,
  double scaleAmount = 1.05,
  double borderRadius = 6,
  EdgeInsets focusPadding = EdgeInsets.zero,
})
```

### ShimmerLoading
Efeito skeleton para loading states.

```dart
ShimmerLoading({
  required Widget child,
})
```

### SkipButton (TheIntroDB)
Botão para pular intro/outro com animação, integrado com a API TheIntroDB.

```dart
SkipButton({
  required String label,
  required VoidCallback onPressed,
  required AnimationController animationController,
})
```

### Badges
| Componente | Arquivo | Descrição |
|------------|---------|-----------|
| `PauloFlixBadge` | `pauloflix_badge.dart` | Badge azul "PauloFlix" para animes |
| `PauloFlixMoviesBadge` | `pauloflix_movies_badge.dart` | Badge vermelho "PauloFlix" para filmes |
| `ProgressOverlay` | `progress_overlay.dart` | Overlay de progresso (ver descrição acima) |
| `CompletedBadge` | `completed_badge.dart` | Badge ✓ verde completo |

### Outros Widgets
| Componente | Arquivo |
|------------|---------|
| `AnimeCard` / `ResponsiveAnimeCard` | `anime_card.dart` / `responsive_anime_card.dart` |
| `ContentTypeSelector` | `content_type_selector.dart` |
| `GenreGlyphIcon` | `genre_glyph_icon.dart` |
| `LetterIndex` | `letter_index.dart` |
| `LogoWidget` | `logo_widget.dart` |
| `PaginatedLetterGrid` | `paginated_letter_grid.dart` |
| `SeeAllCard` | `see_all_card.dart` |
| `TVGridView` | `tv_grid_view.dart` |
| `TVSafeTextField` | `tv_safe_text_field.dart` |
| `WatchlistButton` | `watchlist_button.dart` |

---

## TV-Specific Tokens

### Dimensões de Componentes
| Token | Value |
|-------|:-----:|
| `buttonHeight` | 56px |
| `buttonMinWidth` | 160px |
| `cardBorderRadius` | 16px |
| `iconSizeSmall` | 28px |
| `iconSizeRegular` | 32px |
| `iconSizeLarge` | 40px |

### Foco (D-pad Navigation)
| Token | Value |
|-------|-------|
| `focusColor` | `AppColors.primary` (`#00BCD4`) |
| `focusBorderColor` | `AppColors.primaryGlow` (`#00E5FF`) |
| `focusBorderWidth` | 4px |
| `focusElevation` | 8px |

### Botões (TV)
- **Elevated Button**: `56px` height, `160px` min-width, `16px` border-radius
- **Outlined Button**: Mesmo sizing, `2px` solid `#00BCD4` border
- **Text Button**: Padding horizontal `28px`, vertical `12px`

---

## Temas

### Dark Theme (Padrão)
- **Scaffold BG**: `#000000`
- **Surface**: `#141414`
- **Primary**: `#00BCD4` (Cyan) — sobrescreve o NetflixRed
- **Secondary**: `#7C4DFF` (Purple)
- **Text**: Branco puro #FFFFFF

### Light Theme
- **Scaffold BG**: White
- **Primary**: `#00BCD4` (Cyan)
- **Text**: `Colors.black87` / `Colors.black54`

---

## Arquivos de Referência

| Arquivo | O que define |
|---------|-------------|
| `lib/ui/core/themes/app_colors.dart` | Paleta completa de cores |
| `lib/ui/core/themes/netflix_theme.dart` | Tokens Netflix (spacing, radius, shadows, animations) |
| `lib/ui/core/themes/tv_theme.dart` | Tokens TV (fontes, componentes, foco) |
| `lib/ui/core/themes/app_theme.dart` | Tema unificado (Netflix + TV + PauloFlix) |
| `lib/ui/core/utils/responsive.dart` | Breakpoints, grid columns, card sizes |
| `lib/ui/core/utils/performance_config.dart` | Durações de animação |
| `lib/ui/core/widgets/` | 22 widgets compartilhados |

---

## Testes de Design System

| Teste | Arquivo | Cobertura |
|-------|---------|:---------:|
| `ProgressOverlay.build()` | `test/.../progress_overlay_test.dart` | 10 testes (null, badge, barra, cores, fractionText) |
| `CompletedBadge` 3 variantes | `test/.../completed_badge_test.dart` | 16 testes (cardOverlay, heroBanner, detailScreen, custom) |
| `MovieProgressState.buildOverlayWidget` | `test/.../movie_progress_state_test.dart` | 5 testes (null, vazio, barra, badge, delegação) |
