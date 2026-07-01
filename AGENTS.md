# PauloFlix - Agent Context

## Project Overview
Flutter-based mobile anime streaming app for iOS and Android devices with Android TV support.

## Tech Stack
- **Framework**: Flutter 3.9.2+
- **Language**: Dart
- **Video Player**: media_kit (high-performance native Flutter player)
- **State Management**: Provider
- **Navigation**: go_router (type-safe deep linking)
- **Database**: Drift (7 tabelas, banco único `pauloflix.db`)
- **Sync**: JSON index (`tv_index.json` / `movie_index.json`) do servidor PauloFlix

## Project Structure (Arquitetura em Camadas)
```
lib/
├── main.dart                          # Entry point
├── app.dart                           # MaterialApp setup, providers, theme
│
├── core/                              # Infraestrutura compartilhada
│   ├── constants/
│   │   ├── api_constants.dart         # URLs do servidor PauloFlix + IntroDB
│   │   └── app_constants.dart         # Chaves de SharedPreferences, limites
│   ├── database/                      # Drift — fonte de verdade (7 tabelas)
│   │   ├── app_database.dart          # @DriftDatabase
│   │   ├── app_database.g.dart        # Drift codegen (gerado, ignorado)
│   │   ├── connection/
│   │   │   └── connection.dart        # LazyDatabase + path resolution
│   │   └── tables/                    # 7 tabelas Drift
│   │       ├── watchlist_items.dart
│   │       ├── downloads.dart
│   │       ├── pauloflix_content.dart
│   │       ├── pauloflix_movies.dart
│   │       ├── pauloflix_seasons.dart
│   │       ├── pauloflix_episodes.dart
│   │       └── episode_progress.dart
│   ├── errors/
│   ├── logger/
│   └── network/
│
├── domain/                            # Camada de domínio (pura)
│   ├── models/                        # Modelos de domínio
│   │   ├── anime.dart
│   │   ├── episode.dart
│   │   ├── pauloflix_content.dart
│   │   ├── pauloflix_movie.dart
│   │   ├── pauloflix_models.dart      # SeasonRecord, EpisodeRecord
│   │   └── ...
│   └── repositories/                  # Interfaces (5)
│
├── data/                              # Implementações de dados
│   ├── models/                        # Modelos de API externa
│   │   └── introdb_models.dart        # TheIntroDB API models
│   ├── repositories/                  # Implementações Drift (5 impls)
│   │   ├── home_repository_impl.dart
│   │   ├── watchlist_repository_impl.dart
│   │   ├── pauloflix_repository_impl.dart
│   │   ├── pauloflix_movies_repository_impl.dart
│   │   └── downloads_repository_impl.dart
│   └── services/                      # Services
│       ├── auth/
│       │   ├── authenticated_http_client.dart     # Injeta JWT
│       │   ├── authenticated_cache_manager.dart
│       │   └── jwt_token_manager.dart
│       ├── kodi/
│       │   ├── kodi_nfo_models.dart
│       │   ├── kodi_nfo_parser.dart
│       │   └── pauloflix_nfo_enricher.dart
│       ├── download_service.dart                  # Fila HTTP + persistência
│       ├── episode_progress_service.dart          # Progresso de episódios
│       ├── image_precache_service.dart            # Precache de imagens
│       ├── introdb_service.dart                   # TheIntroDB API
│       ├── movie_progress_service.dart            # Progresso de filmes
│       ├── pauloflix_movies_service.dart          # Sync JSON index (Movies)
│       ├── pauloflix_service.dart                 # Sync JSON index (TV)
│       ├── paulo_flix_episode_sync_service.dart   # Sync episodes on-demand
│       └── search_history_service.dart            # Histórico de busca
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
    │       ├── completed_badge.dart
    │       ├── content_type_selector.dart  # Pill Animes|Filmes
    │       ├── focusable_widget.dart  # Focus + D-pad
    │       ├── genre_glyph_icon.dart
    │       ├── letter_index.dart
    │       ├── logo_widget.dart
    │       ├── netflix_card.dart      # Card estilo Netflix
    │       ├── netflix_carousel.dart  # Carousel horizontal
    │       ├── netflix_hero_card.dart # Banner hero
    │       ├── paginated_alphabetical_carousel.dart
    │       ├── paginated_letter_grid.dart
    │       ├── pauloflix_badge.dart   # Badge azul PauloFlix
    │       ├── pauloflix_movies_badge.dart # Badge vermelho cinema
    │       ├── progress_overlay.dart
    │       ├── see_all_card.dart
    │       ├── shimmer_loading.dart   # Skeleton loading
    │       ├── skip_button.dart       # Botão TheIntroDB
    │       ├── tv_grid_view.dart      # Grid otimizado TV
    │       ├── tv_safe_text_field.dart # TextField seguro para TV
    │       └── watchlist_button.dart
    │
    ├── downloads/widgets/
    │   ├── download_button.dart
    │   └── downloads_screen.dart
    │
    ├── home/widgets/
    │   └── home_screen.dart
    │
    ├── navigation/main_navigation_screen.dart  # Shell + toggle Animes|Filmes
    │
    ├── pauloflix/
    │   ├── view_models/pauloflix_provider.dart
    │   └── widgets/
    │       ├── pauloflix_episode_list_screen.dart
    │       ├── pauloflix_search_screen.dart
    │       └── pauloflix_see_all_screen.dart
    │
    ├── pauloflix_movies/
    │   ├── view_models/pauloflix_movies_provider.dart
    │   └── widgets/
    │       ├── pauloflix_movie_detail_screen.dart
    │       ├── pauloflix_movies_home_screen.dart
    │       ├── pauloflix_movies_section.dart
    │       └── pauloflix_movies_search_screen.dart
    │
    ├── player/
    │   ├── video_player_introdb_mixin.dart  # Mixin TheIntroDB
    │   └── widgets/
    │       ├── blogger_webview_screen.dart
    │       ├── modern_video_player_controls.dart # Controles overlay
    │       ├── video_player_episode_buttons.dart
    │       ├── video_player_screen.dart
    │       └── video_player_subtitle_sheet.dart   # Seletor de legendas
    │
    ├── search/widgets/
    │   └── search_screen.dart
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
// Netflix components
NetflixCard(imageUrl: imageUrl, title: title, onTap: () {})
NetflixCarousel(title: title, height: height, items: items)
```

### Theme Integration
- Colors: Netflix red (#E50914), black (#000000)
- Animation curves: easeInOutCubic
- Animation durations: 150ms (fast), 300ms (medium), 500ms (slow)
- Responsive breakpoints: Mobile (<600px), Tablet (600-1200px), TV/Desktop (>1200px)

## Video Player Implementation

The project uses **media_kit** for video playback:

### Key Components
- **media_kit**: Core video player library
- **media_kit_video**: Flutter widget for video rendering
- **media_kit_libs_video**: Native video libraries for each platform
- **TheIntroDB**: Skip intro/outro via api.theintrodb.org

### Video Player Features
- Modern video player with media_kit backend
- Fullscreen support with immersive mode
- TV-optimized playback with D-pad controls
- TheIntroDB integration for skipping intro/outro segments
- HTTP headers (User-Agent, Referer, JWT) injetados diretamente no `Media.open()`
- Hardware acceleration enabled safely on TV
- WebView fallback for iOS when needed
- Adaptive video controls for different platforms

### Video Player Architecture
```dart
// Main video player screen
VideoPlayerScreen
├── Player (media_kit core)
├── VideoController (media_kit_video)
├── IntroDbService (skip intro/outro)
└── TV-specific optimizations
```

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
Located at: `docs/archive/devin-skills/`

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
- `PAULOFLIX_MOVIES.md` - PauloFlix Movies documentation
- `archive/DATABASE_REFACTORING.md` - Historical DB refactoring plan

## Common Patterns

### API Calls
```dart
// Use services for API calls
final pauloflixService = PauloFlixService();
final contents = await pauloflixService.syncContent(...);
```

### Navigation
```dart
context.pushNamed('player', extra: PlayerRouteData(...));
```

### State Management
```dart
// Using Provider
class PauloFlixProvider extends ChangeNotifier {
  List<PauloFlixContent> _contents = [];
  List<PauloFlixContent> get contents => _contents;

  Future<void> loadContents() async {
    _contents = await repository.getAll();
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
