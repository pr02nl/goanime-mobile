# Netflix UI/UX Integration Example

## Como usar esta skill no projeto PauloFlix

### 1. Copiar arquivos para o projeto

Copie os arquivos da skill para o projeto:

```bash
# Copiar tema
cp .devin/skills/netflix_ui_ux/netflix_theme.dart lib/theme/

# Copiar componentes
cp .devin/skills/netflix_ui_ux/netflix_card.dart lib/widgets/
cp .devin/skills/netflix_ui_ux/netflix_carousel.dart lib/widgets/
```

### 2. Atualizar o main.dart com o tema Netflix

```dart
import 'package:flutter/material.dart';
import 'theme/netflix_theme.dart';

void main() {
  runApp(const PauloFlixApp());
}

class PauloFlixApp extends StatelessWidget {
  const PauloFlixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PauloFlix',
      debugShowCheckedModeBanner: false,
      theme: NetflixTheme.lightTheme,
      darkTheme: NetflixTheme.darkTheme,
      themeMode: ThemeMode.dark, // Usar tema escuro por padrão
      home: const MainNavigationScreen(),
    );
  }
}
```

### 3. Exemplo de uso no Home Screen

```dart
import 'package:flutter/material.dart';
import '../widgets/netflix_carousel.dart';
import '../widgets/netflix_card.dart';
import '../models/jikan_models.dart';
import '../theme/netflix_theme.dart';
import '../utils/responsive.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NetflixTheme.background,
      body: CustomScrollView(
        slivers: [
          // Hero Section
          SliverToBoxAdapter(
            child: NetflixHeroCard(
              imageUrl: 'https://example.com/hero-image.jpg',
              title: 'Featured Anime',
              description: 'An amazing anime series you should watch',
              onPlay: () {
                // Navegar para player
              },
              onMyList: () {
                // Adicionar à lista
              },
              height: Responsive.getBannerHeight(context),
              isTV: await Responsive.isTV(context),
            ),
          ),
          
          // Trending Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: NetflixTheme.lg),
              child: NetflixCarousel(
                title: 'Trending Now',
                items: trendingAnimes.map((anime) {
                  return NetflixCard(
                    imageUrl: anime.imageUrl,
                    title: anime.title,
                    rating: anime.score,
                    width: Responsive.getHorizontalListItemWidth(context),
                    height: Responsive.getCardHeight(context),
                    onTap: () {
                      // Navegar para detalhes
                    },
                    isTV: await Responsive.isTV(context),
                  );
                }).toList(),
                height: Responsive.getSectionHeight(context),
                isTV: await Responsive.isTV(context),
              ),
            ),
          ),
          
          // Popular Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: NetflixTheme.xl),
              child: NetflixCarousel(
                title: 'Popular This Week',
                items: popularAnimes.map((anime) {
                  return NetflixCard(
                    imageUrl: anime.imageUrl,
                    title: anime.title,
                    rating: anime.score,
                    width: Responsive.getHorizontalListItemWidth(context),
                    height: Responsive.getCardHeight(context),
                    onTap: () {
                      // Navegar para detalhes
                    },
                    isTV: await Responsive.isTV(context),
                  );
                }).toList(),
                height: Responsive.getSectionHeight(context),
                isTV: await Responsive.isTV(context),
              ),
            ),
          ),
          
          // More sections...
        ],
      ),
    );
  }
}
```

### 4. Exemplo de uso no Anime Detail Screen

```dart
import 'package:flutter/material.dart';
import '../widgets/netflix_card.dart';
import '../theme/netflix_theme.dart';

class AnimeDetailScreen extends StatelessWidget {
  final JikanAnime anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NetflixTheme.background,
      body: CustomScrollView(
        slivers: [
          // Hero section with anime info
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Background image
                CachedNetworkImage(
                  imageUrl: anime.largImageUrl ?? anime.imageUrl,
                  height: 400,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                // Gradient overlay
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        NetflixTheme.background,
                      ],
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  top: 40,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: NetflixTheme.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Anime info
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title,
                        style: const TextStyle(
                          color: NetflixTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (anime.score != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: NetflixTheme.netflixRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    anime.score!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 12),
                          Text(
                            anime.type ?? 'TV',
                            style: const TextStyle(
                              color: NetflixTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            anime.episodes ?? '?',
                            style: const TextStyle(
                              color: NetflixTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Synopsis
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(NetflixTheme.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      color: NetflixTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: NetflixTheme.md),
                  Text(
                    anime.synopsis ?? 'No synopsis available.',
                    style: const TextStyle(
                      color: NetflixTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Episodes list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NetflixTheme.lg,
              ),
              child: const Text(
                'Episodes',
                style: TextStyle(
                  color: NetflixTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Episodes carousel
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: NetflixTheme.md),
              child: NetflixCarousel(
                title: '',
                items: episodes.map((episode) {
                  return NetflixCard(
                    imageUrl: episode.thumbnail,
                    title: 'Episode ${episode.number}',
                    width: 200,
                    height: 120,
                    showTitle: true,
                    showRating: false,
                    onTap: () {
                      // Play episode
                    },
                  );
                }).toList(),
                height: 140,
                showTitle: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 5. Exemplo de loading state com Shimmer

```dart
// Antes de carregar os dados
if (isLoading) {
  return NetflixCarouselShimmer(
    title: 'Trending Now',
    itemCount: 6,
    height: Responsive.getSectionHeight(context),
  );
}

// Depois de carregar
return NetflixCarousel(
  title: 'Trending Now',
  items: animeList,
  height: Responsive.getSectionHeight(context),
);
```

### 6. Customização do tema

Você pode customizar as cores do tema Netflix para combinar com a identidade visual do PauloFlix:

```dart
// Em netflix_theme.dart
class PauloFlixTheme extends NetflixTheme {
  // Override cores principais
  static const Color pauloFlixPrimary = Color(0xFF00BCD4); // Cyan
  static const Color pauloFlixSecondary = Color(0xFF7C4DFF); // Purple
  
  static ThemeData get pauloFlixDarkTheme {
    return ThemeData(
      // ... outras configurações
      primaryColor: goAnimePrimary,
      colorScheme: const ColorScheme.dark(
        primary: goAnimePrimary,
        secondary: goAnimeSecondary,
        surface: surface,
        error: netflixRed,
      ),
    );
  }
}
```

### 7. Animações customizadas

```dart
// Adicionar animações personalizadas
class CustomAnimations {
  static Widget fadeInTransition(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: NetflixTheme.mediumDuration,
      curve: NetflixTheme.defaultCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
```

## Dicas de Implementação

1. **Performance**: Use `const` widgets onde possível para evitar rebuilds desnecessários
2. **Imagens**: Sempre use `CachedNetworkImage` com parâmetros de cache otimizados
3. **TV**: Teste a navegação por D-pad em dispositivos Android TV
4. **Responsividade**: Use os helpers de `Responsive` para layouts adaptativos
5. **Animações**: Mantenha animações suaves e curtas (150-300ms)
6. **Acessibilidade**: Adicione labels semânticos para screen readers

## Próximos Passos

- Implementar navegação por gestos no mobile
- Adicionar animações de transição entre telas
- Criar componentes de loading mais elaborados
- Implementar skeleton screens para listas longas
- Adicionar suporte a Picture-in-Picture para vídeo
- Criar componentes de busca estilo Netflix