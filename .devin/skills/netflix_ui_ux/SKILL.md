---
name: netflix-ui-ux
description: Create Netflix-inspired responsive Flutter UI/UX with premium design, smooth animations, and multi-platform support
argument-hint: "[component] [options]"
allowed-tools:
  - read
  - write
  - edit
  - grep
  - glob
  - find_file_by_name
  - exec
triggers:
  - user
  - model
---

# Netflix UI/UX Design Skill

## Descrição
Skill especializada em criar interfaces Flutter responsivas inspiradas no Netflix, focando em design premium, animações suaves e experiência de usuário imersiva.

## Características Principais

### 🎨 Design Visual Netflix
- **Tema Escuro Premium**: Fundo preto puro (#000000) com gradientes sutis
- **Cores de Accent**: Vermelho (#E50914) para ações principais, branco para texto
- **Cards Imersivos**: Hover effects com scale, shadow e gradient overlays
- **Tipografia Limpa**: Fontes sans-serif modernas com hierarquia visual clara

### 📱 Responsividade Multi-Plataforma
- **Mobile**: Layout compacto com swipe gestures
- **Tablet**: Grid adaptativo com mais colunas
- **TV**: Navegação por D-pad com focus management
- **Web**: Layout fluido com breakpoints inteligentes

### ✨ Animações e Transições
- **Hero Carousel**: Transições suaves com parallax
- **Card Interactions**: Scale animation no hover/tap
- **Page Transitions**: Fade/Slide animations entre telas
- **Loading States**: Shimmer effects elegantes

## Componentes Netflix-Inspirados

### 1. Hero Section
```dart
// Banner principal com imagem de fundo, gradiente e CTA
NetflixHero(
  backgroundImage: 'url',
  title: 'Anime Title',
  description: 'Synopsis',
  onPlay: () {},
  onMyList: () {},
)
```

### 2. Horizontal Carousel
```dart
// Lista horizontal de cards com scroll suave
NetflixCarousel(
  title: 'Trending Now',
  items: animeList,
  itemBuilder: (anime) => AnimeCard(anime),
)
```

### 3. Anime Card
```dart
// Card com hover effect, scale animation e metadata
NetflixCard(
  imageUrl: 'url',
  title: 'Title',
  rating: 8.5,
  onTap: () {},
)
```

### 4. Navigation Bar
```dart
// Bottom navigation com icons e active states
NetflixBottomNav(
  currentIndex: 0,
  onTap: (index) {},
)
```

## Padrões de Responsividade

### Breakpoints
```dart
// Mobile: < 600px
// Tablet: 600px - 1200px  
// TV/Desktop: > 1200px

static const double mobileBreakpoint = 600;
static const double tabletBreakpoint = 1200;
```

### Layout Adaptativo
```dart
// Grid columns por dispositivo
final gridColumns = screenWidth < 600 ? 2 
                  : screenWidth < 1200 ? 4 
                  : 6;

// Card sizes por dispositivo
final cardWidth = screenWidth < 600 ? 120.0
                : screenWidth < 1200 ? 150.0
                : 190.0;
```

## Animações Recomendadas

### Curve Animations
```dart
// Curvas de animação estilo Netflix
static const Curve netflixCurve = Curves.easeInOutCubic;
static const Duration fastAnimation = Duration(milliseconds: 200);
static const Duration mediumAnimation = Duration(milliseconds: 300);
static const Duration slowAnimation = Duration(milliseconds: 500);
```

### Hover Effects
```dart
// Scale animation no hover
MouseRegion(
  cursor: SystemMouseCursors.click,
  onEnter: (_) => setState(() => _isHovered = true),
  onExit: (_) => setState(() => _isHovered = false),
  child: AnimatedScale(
    scale: _isHovered ? 1.05 : 1.0,
    duration: fastAnimation,
    curve: netflixCurve,
    child: card,
  ),
)
```

## Cores e Tema

### Netflix Color Palette
```dart
class NetflixColors {
  static const Color primary = Color(0xFFE50914); // Netflix Red
  static const Color background = Color(0xFF000000); // Pure Black
  static const Color surface = Color(0xFF141414); // Dark Gray
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB3B3B3); // Light Gray
  static const Color overlay = Color(0x80000000); // Semi-transparent black
}
```

### Gradient Overlays
```dart
// Gradiente para melhorar legibilidade
BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.7),
      Colors.black,
    ],
  ),
)
```

## Padrões de Navegação

### TV Navigation
```dart
// Focus management para TV
Focus(
  autofocus: true,
  onKey: (node, event) {
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // Navigate to next item
    }
    return KeyEventResult.ignored;
  },
  child: focusableWidget,
)
```

### Mobile Gestures
```dart
// Swipe gestures para mobile
GestureDetector(
  onHorizontalDragEnd: (details) {
    if (details.primaryVelocity! > 0) {
      // Swipe right
    } else {
      // Swipe left
    }
  },
  child: content,
)
```

## Performance Otimizations

### Image Caching
```dart
// Cached network images com otimização
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: (width * 2).toInt(),
  memCacheHeight: (height * 2).toInt(),
  maxWidthDiskCache: (width * 2).toInt(),
  maxHeightDiskCache: (height * 2).toInt(),
  fadeInDuration: Duration(milliseconds: 300),
)
```

### Lazy Loading
```dart
// Lazy loading para listas longas
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return AnimeCard(items[index]);
  },
)
```

## Acessibilidade

### Semantics
```dart
// Labels semânticas para screen readers
Semantics(
  label: 'Anime: $title, Rating: $rating',
  button: true,
  child: card,
)
```

### Contrast
```dart
// Alto contraste para melhor legibilidade
Text(
  title,
  style: TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
)
```

## Boas Práticas

1. **Content-First Design**: O conteúdo é a estrela, UI deve ser invisível
2. **Minimal Navigation**: Menos cliques, mais conteúdo visível
3. **Smooth Animations**: Transições devem ser naturais e previsíveis
4. **Responsive First**: Design para mobile primeiro, escalando para telas maiores
5. **Performance First**: 60fps constant, lazy loading, caching inteligente

## Implementação no Projeto

### Arquivos Recomendados
- `lib/theme/netflix_theme.dart` - Tema e cores
- `lib/widgets/netflix_hero.dart` - Hero section
- `lib/widgets/netflix_carousel.dart` - Horizontal carousel
- `lib/widgets/netflix_card.dart` - Card com hover effects
- `lib/utils/netflix_animations.dart` - Animações reutilizáveis

### Exemplo de Uso
```dart
// No build method
NetflixTheme(
  child: Scaffold(
    backgroundColor: NetflixColors.background,
    body: CustomScrollView(
      slivers: [
        NetflixHero(...),
        NetflixCarousel(...),
        NetflixCarousel(...),
      ],
    ),
  ),
)
```

## Referências
- [Netflix Design System](https://www.netflixdesign.com/)
- [Flutter Adaptive & Responsive](https://docs.flutter.dev/ui/adaptive-responsive)
- [Material Design 3](https://m3.material.io/)

## Notas de Implementação
- Usar `LayoutBuilder` para layouts responsivos
- Implementar `FocusNode` para navegação TV
- Usar `AnimatedBuilder` para animações performáticas
- Considerar `Provider` ou `Riverpod` para state management
- Usar `cached_network_image` para imagens
- Implementar skeleton loading para melhor UX