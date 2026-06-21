# PauloFlix - Agent Context

## Project Overview
Flutter-based mobile anime streaming app for iOS and Android devices with Android TV support.

## Tech Stack
- **Framework**: Flutter 3.9.2+
- **Language**: Dart
- **Video Player**: media_kit (high-performance native Flutter player)
- **State Management**: Provider
- **Navigation**: MaterialApp with Navigator 1.0 (push/pop)
- **APIs**: Jikan API (MyAnimeList), AniList GraphQL, TMDB v3

## Project Structure (Arquitetura em Camadas)
```
lib/
├── main.dart                          # Entry point
├── app.dart                           # MaterialApp setup, providers, theme
│
├── core/                              # Infraestrutura compartilhada
│   ├── constants/
│   │   ├── api_constants.dart         # Base URLs, endpoints
│   │   └── app_constants.dart         # Chaves de SharedPreferences, limites
│   ├── database/                          # ⚠️ Em refatoração — ver docs/DATABASE_REFACTORING.md
│   │   ├── app_database.dart          # Drift database definition (FANTASMA — ver plano)
│   │   ├── app_database.g.dart        # Drift codegen (gerado, não exercitado)
│   │   ├── database_helper.dart       # Helper SQLite legado (zumbi write-only — remover)
│   │   └── tables/
│   │       ├── downloads_table.dart   # Schema downloads
│   │       ├── pauloflix_table.dart   # Schema PauloFlix animes
│   │       └── watchlist_table.dart   # Schema watchlist
│   ├── errors/
│   │   ├── exceptions.dart            # Exceções sealed (TmdbException, etc.)
│   │   └── failures.dart              # Failures unificados
│   ├── logger/
│   │   └── app_logger.dart            # Logger estruturado
│   └── network/
│       ├── dio_client.dart            # Dio com interceptors
│       ├── logging_interceptor.dart    # Logging HTTP
│       ├── rate_limit_interceptor.dart # Rate limiting
│       └── retry_interceptor.dart     # Retry com backoff
│
├── domain/                            # Regras de negócio (interfaces + modelos internos)
│   ├── models/
│   │   ├── anime.dart                 # Anime unificado (Jikan + AniList)
│   │   ├── episode.dart               # Episódio
│   │   ├── pauloflix_content.dart     # Conteúdo PauloFlix (animes)
│   │   ├── pauloflix_models.dart      # Modelos PauloFlix internos
│   │   ├── pauloflix_movie.dart       # Filme ou coleção
│   │   ├── pauloflix_movie_item.dart  # Filme individual (dentro de coleção)
│   │   ├── video.dart                 # Dados de vídeo
│   │   └── watchlist_anime.dart       # Item da watchlist
│   └── repositories/
│       ├── home_repository.dart       # Interface (abstract)
│       └── search_repository.dart     # Interface (abstract)
│
├── data/                              # Implementações de dados
│   ├── models/                        # Modelos de API externos
│   │   ├── anilist_models.dart        # MediaDetails, MediaTitle, CoverImage
│   │   ├── aniskip_models.dart        # SkipTimes, Skip
│   │   ├── jikan_models.dart          # JikanAnime, JikanGenre, JikanResponse
│   │   └── tmdb_models.dart           # TmdbMovie, TmdbGenre
│   ├── repositories/
│   │   ├── home_repository_impl.dart  # Implementação concreta
│   │   └── search_repository_impl.dart
│   └── services/
│       ├── anime_service.dart         # AnimeFire/scraping + extração de vídeo
│       ├── anilist_service.dart       # AniList GraphQL
│       ├── aniskip_service.dart       # AniSkip skip times
│       ├── api_key_settings_service.dart  # TMDB API key (SharedPreferences)
│       ├── download_service.dart      # Downloads offline
│       ├── episode_thumbnail_service.dart # Thumbnails de episódios
│       ├── google_video_proxy.dart    # Proxy HTTP para Google Video
│       ├── jikan_service.dart         # Jikan API (cache 30min)
│       ├── pauloflix_database_service.dart  # SQLite PauloFlix animes
│       ├── pauloflix_movies_database_service.dart  # SQLite PauloFlix filmes
│       ├── pauloflix_movies_service.dart   # PauloFlix Movies: scraping + TMDB
│       ├── pauloflix_service.dart     # PauloFlix animes: scraping HTML
│       ├── search_history_service.dart # Histórico de busca (SharedPreferences)
│       ├── tmdb_service.dart          # TMDB API v3 (cache + throttle)
│       ├── tv_api_key_server.dart     # Servidor HTTP para setup de API key via QR
│       ├── watchlist_notifier.dart    # ChangeNotifier da watchlist
│       └── watchlist_service.dart     # Watchlist (SQLite)
│
├── routing/                           # Navegação
│   ├── app_router.dart                # go_router config
│   └── route_data.dart                # Typed routes
│
├── l10n/
│   └── app_localizations.dart         # PT-BR / EN-US
│
└── ui/                                # Interface do usuário
    ├── core/
    │   ├── themes/
    │   │   ├── app_colors.dart        # Paleta de cores
    │   │   ├── app_theme.dart         # Tema unificado
    │   │   ├── netflix_theme.dart     # Tema Netflix
    │   │   └── tv_theme.dart          # Tema TV
    │   ├── utils/
    │   │   ├── episode_utils.dart     # Extração de número de episódio
    │   │   ├── performance_config.dart # Durações de animação
    │   │   ├── responsive.dart        # Breakpoints Mobile/Tablet/TV
    │   │   ├── text_utils.dart        # Utilitários de texto
    │   │   └── tv_detector.dart       # Detecção de Android TV
    │   ├── view_models/
    │   │   └── locale_viewmodel.dart  # Estado do idioma
    │   └── widgets/                   # Widgets reutilizáveis
    │       ├── anime_card.dart
    │       ├── anime_result_card.dart
    │       ├── content_type_selector.dart  # Pill Animes|Filmes
    │       ├── focusable_widget.dart  # Focus + D-pad
    │       ├── genre_glyph_icon.dart  # Ícones de gênero
    │       ├── logo_widget.dart
    │       ├── netflix_card.dart      # Card estilo Netflix
    │       ├── netflix_carousel.dart  # Carousel horizontal
    │       ├── pauloflix_badge.dart   # Badge azul PauloFlix
    │       ├── pauloflix_movies_badge.dart # Badge vermelho cinema
    │       ├── pauloflix_movies_section.dart # Seção filmes
    │       ├── pauloflix_section.dart # Seção animes PauloFlix
    │       ├── responsive_anime_card.dart
    │       ├── shimmer_loading.dart   # Skeleton loading
    │       ├── skip_button.dart       # Botão AniSkip
    │       ├── tv_grid_view.dart      # Grid otimizado TV
    │       ├── tv_safe_text_field.dart # TextField seguro para TV
    │       └── watchlist_button.dart
    │
    ├── downloads/widgets/
    │   ├── download_button.dart
    │   └── downloads_screen.dart
    │
    ├── home/
    │   ├── view_models/home_viewmodel.dart
    │   └── widgets/
    │       ├── anime_detail_screen.dart
    │       ├── genre_animes_screen.dart
    │       └── home_screen.dart
    │
    ├── navigation/main_navigation_screen.dart  # Shell + toggle Animes|Filmes
    │
    ├── pauloflix/
    │   ├── view_models/pauloflix_provider.dart
    │   └── widgets/
    │       ├── pauloflix_episode_list_screen.dart
    │       └── pauloflix_see_all_screen.dart
    │
    ├── pauloflix_movies/
    │   ├── view_models/pauloflix_movies_provider.dart
    │   └── widgets/
    │       ├── pauloflix_movie_detail_screen.dart
    │       ├── pauloflix_movies_home_screen.dart
    │       └── pauloflix_movies_search_screen.dart
    │
    ├── player/
    │   ├── video_player_aniskip_mixin.dart  # Mixin AniSkip
    │   └── widgets/
    │       ├── blogger_webview_screen.dart
    │       ├── episode_grid_card.dart      # Card de episódio em modo grid
    │       ├── episode_list_card.dart      # Card de episódio em modo lista
    │       ├── episode_list_screen.dart
    │       ├── modern_episode_list_screen.dart
    │       ├── video_player_info_panel.dart      # Painel de info abaixo do player
    │       ├── video_player_overlay_controls.dart # Controles de overlay fullscreen
    │       ├── video_player_screen.dart
    │       └── video_player_subtitle_sheet.dart   # Seletor de legendas
    │
    ├── search/widgets/
    │   ├── anime_search_screen.dart
    │   ├── search_screen.dart
    │   └── source_selection_screen.dart
    │
    ├── settings/
    │   ├── view_models/theme_viewmodel.dart
    │   └── widgets/
    │       ├── settings_screen.dart
    │       └── tv_qr_setup_dialog.dart
    │
    └── watchlist/
        ├── view_models/watchlist_viewmodel.dart
        └── widgets/watchlist_screen.dart
```

## Build Commands

### Development
```bash
flutter pub get              # Install dependencies
flutter run                  # Run in debug mode
flutter run -d <device_id>   # Run on specific device
flutter devices              # List available devices
```

### Build for Production
```bash
# Android APK
flutter build apk --release
flutter build apk --release --target-platform android-arm64

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release
flutter build ipa --release
```

### Verification
```bash
flutter analyze              # Static analysis
flutter doctor               # Check Flutter installation
flutter test                 # Run tests
```

## Code Conventions

### File Naming
- Use snake_case for files: `anime_card.dart`, `home_screen.dart`
- Use PascalCase for classes: `AnimeCard`, `HomeScreen`
- Use camelCase for variables/functions: `animeList`, `buildCard()`

### Import Organization
```dart
// 1. Flutter/Dart imports
import 'package:flutter/material.dart';

// 2. Package imports
import 'package:provider/provider.dart';

// 3. Project imports (relative)
import '../models/anime.dart';
import '../widgets/anime_card.dart';
```

### Widget Structure
- Prefer const constructors where possible
- Use `const` for static widgets
- Separate build methods for complex widgets
- Use Responsive helpers for layout

## Netflix UI/UX Integration

The project includes a Netflix-inspired UI system with gradual migration support:

### Available Components
- **NetflixCard**: Card with hover effects and scale animation
- **NetflixCarousel**: Horizontal carousel with smooth scrolling
- **NetflixHeroCard**: Featured content hero section
- **NetflixTheme**: Complete Netflix-inspired theming system

### Migration Pattern
```dart
// Old way (still supported)
AnimeCard(anime: anime, onTap: () {})

// Netflix style (gradual migration)
AnimeCard(anime: anime, useNetflixStyle: true, onTap: () {})

// New Netflix components
NetflixCard(imageUrl: anime.imageUrl, title: anime.title, onTap: () {})
```

### Theme Integration
- Colors: Netflix red (#E50914), black (#000000)
- Animation curves: easeInOutCubic
- Animation durations: 150ms (fast), 300ms (medium), 500ms (slow)
- Responsive breakpoints: Mobile (<600px), Tablet (600-1200px), TV/Desktop (>1200px)

## Video Player Implementation

The project uses **media_kit** for video playback, replacing the previous Chewie implementation:

### Key Components
- **media_kit**: Core video player library
- **media_kit_video**: Flutter widget for video rendering
- **media_kit_libs_video**: Native video libraries for each platform
- **GoogleVideoProxy**: Custom proxy for Google Video streams with referrer handling

### Video Player Features
- Modern video player with media_kit backend
- Fullscreen support with immersive mode
- TV-optimized playback with D-pad controls
- AniSkip integration for skipping intro/outro segments
- Google Video proxy for handling restricted streams
- Hardware acceleration enabled safely on TV (using androidAttachSurfaceAfterVideoParameters to prevent black screen)
- WebView fallback for iOS when needed
- Adaptive video controls for different platforms

### Video Player Architecture
```dart
// Main video player screen
ModernVideoPlayerScreen
├── Player (media_kit core)
├── VideoController (media_kit_video)
├── GoogleVideoProxy (for Google Video streams)
├── AniSkip integration (skip intro/outro)
└── TV-specific optimizations
```

### Google Video Proxy
Custom HTTP proxy server that:
- Handles Google Video streams with proper referrer headers
- Runs locally on loopback interface
- Forwards relevant headers (Range, Accept, etc.)
- Bypasses CORS restrictions for embedded video players

### TV Video Player Specifics
- Hardware acceleration enabled safely with androidAttachSurfaceAfterVideoParameters: true
- MaterialDesktopVideoControls with Focus wrapper
- Auto-fullscreen on TV devices
- Landscape-only orientation on TV
- Closes player when exiting fullscreen on TV

## TV Navigation Support

Android TV support with D-pad navigation:
- **Focus Management**: Automatic FocusNode handling
- **Visual Indicators**: Clear focus states for TV
- **Layout Optimization**: 6-column grid for TV screens
- **Large Text**: 30-40% larger fonts for TV
- **TV Theme**: Enhanced contrast and spacing

### TV Detection
```dart
bool isTV = await Responsive.isTV(context);
```

## Responsive Design

Use Responsive utilities for adaptive layouts:
```dart
Responsive.getHorizontalListItemWidth(context)  // Card width
Responsive.getCardHeightSync(context)           // Card height
Responsive.getSectionHeight(context)            // Section height
Responsive.getBannerHeight(context)             // Banner height
```

## Skills Available

### Netflix UI/UX Skill
Located at: `.devin/skills/netflix_ui_ux/`

Creates Netflix-inspired responsive Flutter UI/UX with:
- Premium design patterns
- Smooth animations
- Multi-platform support (mobile, tablet, TV, desktop)
- TV navigation support
- Hover effects and transitions

Trigger this skill when:
- User asks for Netflix-style UI
- Need carousel components
- Implementing hover effects
- Working on TV layouts
- Need responsive card components

## Documentation Structure

All project documentation is in the `docs/` folder:
- `README.md` - Project overview
- `APIs.md` - API documentation
- `Models.md` - Data models documentation
- `Services.md` - Service layer documentation
- `TV_SUPPORT.md` - TV support guide
- `UI.md` - UI components documentation
- `NETFLIX_REFACTORING.md` - Netflix UI/UX refactoring documentation

## Common Patterns

### API Calls
```dart
// Use services for API calls
final animeService = AnimeService();
final animes = await animeService.getTopAnime();
```

### Navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => DetailScreen(anime: anime)),
);
```

### State Management
```dart
// Using Provider
class AnimeProvider extends ChangeNotifier {
  List<Anime> _animes = [];
  List<Anime> get animes => _animes;
  
  Future<void> loadAnimes() async {
    _animes = await animeService.getTopAnime();
    notifyListeners();
  }
}
```

## Testing Strategy

Before completing tasks:
1. Run `flutter analyze` to check for errors
2. Test on multiple screen sizes if UI changes
3. Test TV navigation if TV-related changes
4. Verify animations are smooth (60fps)
5. Check responsive behavior

## Important Notes

- Always use existing libraries before adding new dependencies
- Follow existing code patterns and conventions
- Maintain backward compatibility when possible
- Use the Netflix UI/UX skill for Netflix-style components
- Keep documentation in `docs/` folder
- Test on real devices when possible
- TV support requires special attention to focus management