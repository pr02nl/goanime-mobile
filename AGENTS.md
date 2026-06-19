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

## Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── anime.dart            # Main anime model
│   └── pauloflix_content.dart  # PauloFlix content model
├── screens/                  # UI screens
│   ├── home_screen.dart      # Main home screen
│   ├── video_player_screen.dart  # Modern video player with media_kit
│   ├── pauloflix_episode_list_screen.dart  # PauloFlix episodes
│   └── ...
├── widgets/                  # Reusable widgets
│   ├── anime_card.dart       # Anime card component
│   ├── anime_section.dart    # Section with carousel
│   ├── netflix_card.dart     # Netflix-style card
│   ├── netflix_carousel.dart # Netflix-style carousel
│   ├── pauloflix_badge.dart  # PauloFlix badge widget
│   ├── pauloflix_card.dart   # PauloFlix card widget
│   ├── pauloflix_section.dart  # PauloFlix section widget
│   └── ...
├── services/                 # API services
│   ├── pauloflix_service.dart  # PauloFlix de animes: scraping HTML do servidor
│   ├── pauloflix_database_service.dart  # SQLite animes PauloFlix
│   ├── pauloflix_movies_service.dart  # PauloFlix Movies: scraping + TMDB
│   ├── pauloflix_movies_database_service.dart  # SQLite filmes PauloFlix
│   ├── tmdb_service.dart  # Cliente TMDB API v3 com cache
│   └── api_key_settings_service.dart  # Persiste TMDB API key em SharedPreferences
├── theme/                    # App theming
│   ├── app_theme.dart        # Unified theme
│   ├── netflix_theme.dart    # Netflix-inspired theme
│   ├── tv_theme.dart         # TV-specific theme
│   └── app_colors.dart       # Color palette
├── helpers/                  # Database and utility helpers
│   └── database_helper.dart  # SQLite database helper
├── mixins/                   # Reusable mixins
│   └── video_player_aniskip_mixin.dart  # AniSkip integration mixin
├── providers/                # State management providers
│   ├── theme_provider.dart   # Theme state management
│   ├── pauloflix_provider.dart  # PauloFlix animes content state
│   └── pauloflix_movies_provider.dart  # PauloFlix filmes content state
├── l10n/                     # Localization files
│   └── app_localizations.dart # Internationalization support
├── google_video_proxy.dart   # Google Video proxy for streams
└── utils/                    # Utilities
    ├── responsive.dart       # Responsive helpers
    └── ...
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