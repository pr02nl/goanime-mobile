# Plano de Melhorias Tecnicas - GoAnime Mobile

## Sumario Executivo

Este documento detalha o plano de refatoracao completa do GoAnime Mobile, abordando problemas de arquitetura, gerenciamento de estado, vazamentos de memoria, seguranca, performance e testabilidade identificados na analise tecnica.

**Alinhado com as [recomendacoes oficiais do Flutter](https://docs.flutter.dev/app-architecture/guide) (2025).**

**Stack alvo:**

| Categoria | Tecnologia atual | Tecnologia alvo | Justificativa |
|---|---|---|---|
| Arquitetura | Mistura de camadas | **MVVM** (oficial Flutter) | Recomendado oficialmente, separacao clara de responsabilidades |
| State Management | Provider (ChangeNotifier) | **Riverpod 2.x** | Evolucao do Provider, mencionado como valido na docs oficial. Compile-safe, testavel |
| Dependency Injection | Manual (construtores) | **Provider** (oficial) | Segue case study oficial (Compass app). Uma unica biblioteca para tudo |
| Navigation | Navigator 1.0 (push/pop) | **go_router** | Recomendado oficialmente pelo time Flutter. Deep linking, type-safe |
| Data Models | Classes mutaveis | **freezed** + **json_serializable** | Imutabilidade, copyWith, equals, serialization automatica |
| Database | 4x SQLite separados (sqlite3) | **drift** (fork do sqflite com codegen) | Type-safe queries, migrations versionadas, single source of truth |
| HTTP | http package direto | **dio** + interceptors | Interceptors para logging, retry, rate limiting, error handling centralizado |
| Testing | Zero testes | **mocktail** + **flutter_test** | Mock sem codegen, compativel com Riverpod |

**Nota:** A documentacao oficial do Flutter usa ChangeNotifier + Provider no case study, mas menciona explicitamente que Riverpod, Bloc e Signals sao alternativas validas. Escolhemos Riverpod por ser a evolucao natural do Provider (mesmo autor) e oferecer melhor testabilidade.

---

## Fase 0: Fundacao (Semana 1)

### 0.1 Atualizacao de Dependencias

**Objetivo:** Atualizar `pubspec.yaml` com as novas dependencias, mantendo **Provider** (recomendado oficialmente) e adicionando ferramentas para MVVM.

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management (oficial Flutter - usado no case study Compass)
  provider: ^6.1.5

  # Navigation
  go_router: ^14.8.1

  # Data Models
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # Database
  drift: ^2.22.1

  # HTTP
  dio: ^5.7.0

  # Existing (manter)
  media_kit: ^1.2.6
  media_kit_video: ^2.0.1
  media_kit_libs_video: ^1.0.7
  html: ^0.15.6
  sqlite3: ^3.3.3
  path: ^1.9.1
  path_provider: ^2.1.5
  webview_flutter: ^4.13.1
  cached_network_image: ^3.4.1
  shared_preferences: ^2.5.5
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code Generation
  build_runner: ^2.4.14
  freezed: ^2.5.8
  json_serializable: ^6.9.4
  drift_dev: ^2.22.1

  # Testing
  mocktail: ^1.0.4

  # Linting
  flutter_lints: ^6.0.0
```

**Remover:**
- `riverpod`, `riverpod_annotation`, `riverpod_generator` (nao vamos usar - seguir padrao oficial)
- `bottom_navy_bar`, `animated_item` (se nao usados)
- `qr_flutter` (se nao usado)

**Mantido:**
- `provider: ^6.1.5` - recomendado oficialmente, usado no case study Compass

**Checklist:**
- [ ] Atualizar `pubspec.yaml` com dependencias acima
- [ ] Remover `riverpod` e pacotes relacionados
- [ ] Manter `provider` (padrao oficial)
- [ ] Rodar `flutter pub get`
- [ ] Rodar `flutter analyze` e corrigir breaking changes iniciais

---

### 0.2 Nova Estrutura de Diretorios

**Objetivo:** Organizar o codigo seguindo o [padrao oficial do Flutter](https://docs.flutter.dev/app-architecture/case-study#package-structure):
- `ui/` organizado por **feature** (cada feature tem view_models/ e widgets/)
- `data/` organizado por **tipo** (repositories, services, models)
- `domain/` para modelos de dominio compartilhados

```
lib/
├── main.dart
├── main_development.dart           # Entry point para dev
├── main_staging.dart               # Entry point para staging
├── main_production.dart            # Entry point para prod
├── app.dart                        # MaterialApp.router config
│
├── ui/                             # UI Layer - organizado por FEATURE
│   ├── core/                       # Shared UI components
│   │   ├── widgets/               # Widgets reutilizaveis (NetflixCard, etc)
│   │   ├── themes/                # Temas compartilhados
│   │   │   ├── app_theme.dart
│   │   │   ├── app_colors.dart
│   │   │   ├── netflix_theme.dart
│   │   │   └── tv_theme.dart
│   │   └── utils/                 # Utils de UI (responsive, tv_detector)
│   │
│   ├── home/                      # Feature: Home
│   │   ├── view_models/
│   │   │   └── home_viewmodel.dart
│   │   └── widgets/
│   │       ├── home_screen.dart
│   │       └── home_widgets.dart
│   │
│   ├── search/                    # Feature: Search
│   │   ├── view_models/
│   │   │   └── search_viewmodel.dart
│   │   └── widgets/
│   │       ├── search_screen.dart
│   │       └── search_widgets.dart
│   │
│   ├── player/                    # Feature: Video Player
│   │   ├── view_models/
│   │   │   └── video_player_viewmodel.dart
│   │   └── widgets/
│   │       ├── video_player_screen.dart
│   │       └── player_widgets.dart
│   │
│   ├── pauloflix/                 # Feature: PauloFlix Animes
│   │   ├── view_models/
│   │   │   └── pauloflix_viewmodel.dart
│   │   └── widgets/
│   │       ├── pauloflix_episode_list_screen.dart
│   │       └── pauloflix_widgets.dart
│   │
│   ├── pauloflix_movies/          # Feature: PauloFlix Movies
│   │   ├── view_models/
│   │   │   └── pauloflix_movies_viewmodel.dart
│   │   └── widgets/
│   │       ├── pauloflix_movies_home_screen.dart
│   │       └── pauloflix_movies_widgets.dart
│   │
│   ├── downloads/                 # Feature: Downloads
│   │   ├── view_models/
│   │   │   └── downloads_viewmodel.dart
│   │   └── widgets/
│   │       ├── downloads_screen.dart
│   │       └── download_widgets.dart
│   │
│   ├── watchlist/                 # Feature: Watchlist
│   │   ├── view_models/
│   │   │   └── watchlist_viewmodel.dart
│   │   └── widgets/
│   │       ├── watchlist_screen.dart
│   │       └── watchlist_widgets.dart
│   │
│   ├── settings/                  # Feature: Settings
│   │   ├── view_models/
│   │   │   └── settings_viewmodel.dart
│   │   └── widgets/
│   │       ├── settings_screen.dart
│   │       └── settings_widgets.dart
│   │
│   └── navigation/                # Feature: Main Navigation
│       └── main_navigation_screen.dart
│
├── data/                          # Data Layer - organizado por TIPO
│   ├── repositories/              # Repositories (implementacoes)
│   │   ├── home_repository_impl.dart
│   │   ├── search_repository_impl.dart
│   │   ├── pauloflix_repository_impl.dart
│   │   ├── pauloflix_movies_repository_impl.dart
│   │   ├── watchlist_repository_impl.dart
│   │   └── downloads_repository_impl.dart
│   │
│   ├── services/                  # Services (API clients, DB, etc)
│   │   ├── anime_service.dart
│   │   ├── jikan_service.dart
│   │   ├── anilist_service.dart
│   │   ├── aniskip_service.dart
│   │   ├── tmdb_service.dart
│   │   ├── pauloflix_service.dart
│   │   ├── pauloflix_movies_service.dart
│   │   ├── watchlist_service.dart
│   │   ├── download_service.dart
│   │   ├── locale_service.dart
│   │   ├── search_history_service.dart
│   │   ├── episode_thumbnail_service.dart
│   │   ├── api_key_settings_service.dart
│   │   └── tv_api_key_server.dart
│   │
│   ├── datasources/               # Data sources (remote/local)
│   │   ├── remote/
│   │   │   ├── jikan_remote_datasource.dart
│   │   │   ├── anilist_remote_datasource.dart
│   │   │   └── tmdb_remote_datasource.dart
│   │   └── local/
│   │       ├── home_local_datasource.dart
│   │       └── pauloflix_local_datasource.dart
│   │
│   └── models/                    # API Models (DTOs)
│       ├── jikan_models.dart
│       ├── anilist_models.dart
│       ├── tmdb_models.dart
│       ├── aniskip_models.dart
│       └── api_responses.dart
│
├── domain/                        # Domain Layer
│   ├── models/                    # Domain models (entidades de negocio)
│   │   ├── anime.dart
│   │   ├── episode.dart
│   │   ├── video.dart
│   │   ├── pauloflix_content.dart
│   │   ├── pauloflix_movie.dart
│   │   └── watchlist_anime.dart
│   │
│   └── repositories/              # Repository interfaces (contratos)
│       ├── home_repository.dart
│       ├── search_repository.dart
│       ├── pauloflix_repository.dart
│       ├── pauloflix_movies_repository.dart
│       ├── watchlist_repository.dart
│       └── downloads_repository.dart
│
├── core/                          # Cross-cutting concerns
│   ├── database/
│   │   ├── app_database.dart      # drift database unico
│   │   └── tables/                # Definicoes de tabelas drift
│   │       ├── anime_table.dart
│   │       ├── watchlist_table.dart
│   │       ├── downloads_table.dart
│   │       └── pauloflix_table.dart
│   ├── network/
│   │   ├── dio_client.dart        # Dio instance com interceptors
│   │   ├── rate_limit_interceptor.dart
│   │   ├── retry_interceptor.dart
│   │   └── logging_interceptor.dart
│   ├── errors/
│   │   ├── failures.dart          # Failure base classes
│   │   └── exceptions.dart        # Exception types
│   ├── logger/
│   │   └── app_logger.dart        # Logger centralizado
│   └── constants/
│       ├── api_constants.dart
│       └── app_constants.dart
│
├── routing/                       # go_router config
│   └── app_router.dart
│
├── l10n/                          # Internacionalizacao
│   └── app_localizations.dart
│
└── google_video_proxy.dart        # Proxy para Google Video streams
```

**Diferencas do plano original:**
- ✅ Segue padrao oficial: `ui/` (por feature) + `data/` (por tipo) + `domain/`
- ✅ ViewModels ficam em `ui/<feature>/view_models/` (nao em `presentation/`)
- ✅ Repositories e Services ficam em `data/` (nao dentro de cada feature)
- ✅ Domain models ficam em `domain/models/` (entidades de negocio)
- ✅ API models (DTOs) ficam em `data/models/` (serializacao)

**Checklist:**
- [ ] Criar estrutura de diretorios
- [ ] Mover arquivos existentes para novas pastas
- [ ] Atualizar todos os imports
- [ ] Garantir que `flutter analyze` passe sem erros

---

### 0.3 Dependency Injection com Provider

**Objetivo:** Usar **apenas Provider** para toda a DI, seguindo o case study Compass.

**Arquivo:** `lib/app.dart`

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services (singleton)
        Provider<JikanService>(create: (_) => JikanService()),
        Provider<AniListService>(create: (_) => AniListService()),
        Provider<AniSkipService>(create: (_) => AniSkipService()),
        Provider<TmdbService>(create: (_) => TmdbService()),
        Provider<AnimeService>(create: (_) => AnimeService()),
        
        // Database
        Provider<AppDatabase>(create: (_) => AppDatabase()),
        
        // Repositories
        Provider<HomeRepository>(create: (ctx) => HomeRepositoryImpl(
          jikanService: ctx.read<JikanService>(),
          database: ctx.read<AppDatabase>(),
        )),
        Provider<SearchRepository>(create: (ctx) => SearchRepositoryImpl(
          jikanService: ctx.read<JikanService>(),
          aniListService: ctx.read<AniListService>(),
        )),
        Provider<WatchlistRepository>(create: (ctx) => WatchlistRepositoryImpl(
          database: ctx.read<AppDatabase>(),
        )),
        
        // ViewModels
        ChangeNotifierProvider(create: (ctx) => HomeViewModel(
          repository: ctx.read<HomeRepository>(),
        )),
        ChangeNotifierProvider(create: (ctx) => SearchViewModel(
          repository: ctx.read<SearchRepository>(),
        )),
        ChangeNotifierProvider(create: (ctx) => WatchlistViewModel(
          repository: ctx.read<WatchlistRepository>(),
        )),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        // ...
      ),
    );
  }
}
```

**Vantagens de usar apenas Provider:**
- ✅ Uma unica biblioteca de DI (menos dependencias)
- ✅ Segue exatamente o case study Compass
- ✅ Services singleton no topo da widget tree
- ✅ ViewModels acessam dependencies via `ctx.read<T>()`
- ✅ Mais simples de entender e manter

**Checklist:**
- [ ] Remover `get_it` do `pubspec.yaml`
- [ ] Remover `service_locator.dart`
- [ ] Registrar todos os services com `Provider`
- [ ] Registrar todos os repositories com `Provider`
- [ ] Registrar todos os ViewModels com `ChangeNotifierProvider`
- [ ] Usar `ctx.read<T>()` para acessar dependencies
- [ ] Testar que tudo funciona sem get_it

---

## Fase 1: Core Infrastructure (Semana 2)

### 1.1 Dio HTTP Client com Interceptors

**Objetivo:** Centralizar configuracao HTTP com rate limiting, retry e logging.

**Arquivo:** `lib/core/network/dio_client.dart`

```dart
class DioClient {
  static Dio create() {
    final dio = Dio(BaseOptions(
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.addAll([
      LoggingInterceptor(),
      RateLimitInterceptor(minInterval: Duration(milliseconds: 400)),
      RetryInterceptor(maxRetries: 3),
    ]);

    return dio;
  }
}
```

**Arquivo:** `lib/core/network/rate_limit_interceptor.dart`

```dart
class RateLimitInterceptor extends Interceptor {
  final Duration minInterval;
  DateTime? _lastRequest;

  RateLimitInterceptor({this.minInterval = Duration(milliseconds: 400)});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_lastRequest != null) {
      final elapsed = DateTime.now().difference(_lastRequest!);
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
    }
    _lastRequest = DateTime.now();
    handler.next(options);
  }
}
```

**Arquivo:** `lib/core/network/retry_interceptor.dart`

```dart
class RetryInterceptor extends Interceptor {
  final int maxRetries;

  RetryInterceptor({this.maxRetries = 3});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 429) {
      final retryAfter = err.response?.headers.value('retry-after');
      final waitSeconds = retryAfter != null ? int.tryParse(retryAfter) ?? 2 : 2;
      await Future.delayed(Duration(seconds: waitSeconds));
      // Retry logic
    }
    handler.next(err);
  }
}
```

**Resolve:**
- Rate limiting duplicado em `JikanService`, `TmdbService`
- Retry logico espalhado
- Logging inconsistente

**Checklist:**
- [ ] Criar `DioClient`
- [ ] Criar `RateLimitInterceptor`
- [ ] Criar `RetryInterceptor`
- [ ] Criar `LoggingInterceptor`
- [ ] Registrar no `service_locator.dart`

---

### 1.2 Database Unificado com drift

**Objetivo:** Substituir 4 bancos SQLite separados por 1 banco drift com migrations versionadas.

**Arquivo:** `lib/core/database/app_database.dart`

```dart
import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Animes,
    WatchlistItems,
    Downloads,
    PauloFlixContent,
    PauloFlixMovies,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Migration v1 -> v2
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode=WAL');
      await customStatement('PRAGMA foreign_keys=ON');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'goanime.db'));
    return NativeDatabase.createInBackground(file);
  });
}
```

**Tabelas:**

```dart
// lib/core/database/tables/watchlist_table.dart
class WatchlistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get animeId => text().unique()();
  TextColumn get title => text()();
  TextColumn get coverImage => text()();
  TextColumn get myAnimeListUrl => text()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

// lib/core/database/tables/downloads_table.dart
class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get downloadId => text().unique()();
  TextColumn get animeId => text()();
  TextColumn get animeName => text()();
  TextColumn get episodeNumber => text()();
  TextColumn get episodeTitle => text()();
  TextColumn get videoUrl => text()();
  TextColumn get thumbnailUrl => text()();
  IntColumn get quality => intEnum<DownloadQuality>()();
  IntColumn get status => intEnum<DownloadStatus>()();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  TextColumn get filePath => text().nullable()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

// lib/core/database/tables/pauloflix_table.dart
class PauloFlixContent extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get folderName => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get serverUrl => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get bannerUrl => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get score => real().nullable()();
  TextColumn get genres => text().nullable()(); // JSON array
  TextColumn get status => text().nullable()();
  IntColumn get episodeCount => integer().nullable()();
  IntColumn get malId => integer().nullable()();
  IntColumn get anilistId => integer().nullable()();
  DateTimeColumn get lastSynced => dateTime()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
}
```

**Resolve:**
- 4 bancos SQLite separados
- Sem migrations
- Queries nao type-safe
- `DatabaseHelper._initCompleter` bug (nao reseta em erro)

**Checklist:**
- [ ] Criar `AppDatabase` com drift
- [ ] Definir todas as tabelas
- [ ] Implementar migracao de dados dos bancos antigos
- [ ] Rodar `dart run build_runner build`
- [ ] Testar queries type-safe
- [ ] Testar migration de dados existentes

---

### 1.3 Error Handling Centralizado

**Objetivo:** Criar hierarchy de erros padronizada.

**Arquivo:** `lib/core/errors/failures.dart`

```dart
abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexao com a internet']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erro ao acessar cache local']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso nao encontrado']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Autenticacao invalida']);
}

class RateLimitFailure extends Failure {
  final Duration? retryAfter;
  const RateLimitFailure({this.retryAfter, super.message = 'Rate limit atingido'});
}
```

**Arquivo:** `lib/core/errors/exceptions.dart`

```dart
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException(this.message, {this.statusCode});
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache error']);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Network error']);
}
```

**Checklist:**
- [ ] Criar `failures.dart`
- [ ] Criar `exceptions.dart`
- [ ] Substituir `throw Exception(...)` nos services

---

### 1.4 Logger Centralizado

**Objetivo:** Substituir `debugPrint` por logger estruturado.

**Arquivo:** `lib/core/logger/app_logger.dart`

```dart
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  final String _tag;
  const AppLogger(this._tag);

  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  void _log(LogLevel level, String message, Object? error, StackTrace? stackTrace) {
    if (kReleaseMode && level == LogLevel.debug) return;
    final prefix = '[${level.name.toUpperCase()}] [$_tag]';
    debugPrint('$prefix $message');
    if (error != null) debugPrint('$prefix Error: $error');
    if (stackTrace != null) debugPrint('$prefix Stack: $stackTrace');
  }
}
```

**Checklist:**
- [ ] Criar `AppLogger`
- [ ] Substituir `debugPrint` nos services e screens
- [ ] Adicionar tags por feature

---

## Fase 2: Models com freezed (Semana 2-3)

### 2.1 Migrar Models para freezed

**Objetivo:** Garantir imutabilidade, `copyWith`, `==`, `hashCode` e serialization automatica.

**Arquivo:** `lib/models/anime.dart` (antes)

```dart
class Anime {
  final String name;
  final String url;
  final AnimeSource source;
  final String? fallbackImageUrl;
  MediaDetails? aniListData;        // MUTAVEL - problema
  bool isLoadingAniList = false;    // MUTAVEL - problema
  // ...
}
```

**Arquivo:** `lib/models/anime.dart` (depois)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'anime.freezed.dart';
part 'anime.g.dart';

enum AnimeSource { animeFire, pauloFlix }

@freezed
class Anime with _$Anime {
  const factory Anime({
    required String name,
    required String url,
    @Default(AnimeSource.animeFire) AnimeSource source,
    String? fallbackImageUrl,
    MediaDetails? aniListData,
    @Default(false) bool isLoadingAniList,
  }) = _Anime;

  factory Anime.fromJson(Map<String, dynamic> json) => _$AnimeFromJson(json);

  // Getters computados
  String get imageUrl => aniListData?.coverImage.best ?? fallbackImageUrl ?? '';
  String get bannerUrl => aniListData?.bannerImage ?? '';
  String get description => aniListData?.description ?? '';
  int? get malId => aniListData?.idMal;
  int? get anilistId => aniListData?.id;
  List<String> get genres => aniListData?.genres ?? [];
  String? get status => aniListData?.status;
  int? get episodeCount => aniListData?.episodes;
  double? get averageScore => aniListData?.averageScore;
  String get sourceName => switch (source) {
    AnimeSource.animeFire => 'AnimeFire',
    AnimeSource.pauloFlix => 'PauloFlix',
  };
}
```

**Models a migrar:**
- `Anime` (anime.dart)
- `Episode` (episode.dart)
- `Video` / `VideoStreamResult` (video.dart)
- `PauloFlixContent` (pauloflix_content.dart)
- `PauloFlixMovie` (pauloflix_movie.dart)
- `WatchlistAnime` (watchlist_anime.dart)
- `JikanAnime` / `JikanResponse` (jikan_models.dart)
- `AniList models` (anilist_models.dart)
- `TmdbMovie` / `TmdbSearchResponse` (tmdb_models.dart)
- `SkipTimes` / `Skip` (aniskip_models.dart)
- `DownloadItem` (dentro de download_service.dart -> models/download_item.dart)

**Resolve:**
- Campos mutaveis em `Anime` (`isLoadingAniList`, `aniListData`) causam race conditions
- `DownloadItem` com campos mutaveis (`status`, `progress`, `bytesDownloaded`)
- Sem `==` ou `hashCode` em models - dificil comparar em testes
- `copyWith` manual em `DownloadItem`

**Checklist:**
- [ ] Migrar todos os models para `@freezed`
- [ ] Remover campos mutaveis
- [ ] Adicionar `@JsonEnum` para enums
- [ ] Rodar `dart run build_runner build`
- [ ] Atualizar todos os usos de `.copyWith()`
- [ ] Verificar `flutter analyze`

---

## Fase 3: Navigation com go_router (Semana 3)

### 3.1 Configurar go_router

**Objetivo:** Substituir Navigator 1.0 por go_router com rotas type-safe.

**Arquivo:** `lib/router/app_router.dart`

```dart
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/player/presentation/video_player_screen.dart';
import '../features/pauloflix/presentation/pauloflix_episode_list_screen.dart';
import '../features/watchlist/presentation/watchlist_screen.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/navigation/main_navigation_screen.dart';
import '../models/episode.dart';
import '../models/anime.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainNavigationScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/watchlist',
            name: 'watchlist',
            builder: (context, state) => const WatchlistScreen(),
          ),
          GoRoute(
            path: '/downloads',
            name: 'downloads',
            builder: (context, state) => const DownloadsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        builder: (context, state) {
          final extra = state.extra as PlayerRouteExtra;
          return VideoPlayerScreen(
            episode: extra.episode,
            animeTitle: extra.animeTitle,
            anime: extra.anime,
            isMovie: extra.isMovie,
            episodeList: extra.episodeList,
            episodeIndex: extra.episodeIndex,
          );
        },
      ),
      GoRoute(
        path: '/pauloflix/:folderName',
        name: 'pauloflix_episodes',
        builder: (context, state) {
          final content = state.extra as PauloFlixContent;
          return PauloFlixEpisodeListScreen(content: content);
        },
      ),
    ],
  );
});

class PlayerRouteExtra {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;
  final bool isMovie;
  final List<Episode>? episodeList;
  final int? episodeIndex;

  const PlayerRouteExtra({
    required this.episode,
    required this.animeTitle,
    this.anime,
    this.isMovie = false,
    this.episodeList,
    this.episodeIndex,
  });
}
```

**Arquivo:** `lib/main.dart` (depois)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initServiceLocator();
  await MediaKit.ensureInitialized();
  await PerformanceConfig.init();
  await DatabaseHelper.initializeAll();

  runApp(const MyApp());
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeServiceProvider);

    return MaterialApp.router(
      title: 'GoAnime',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: locale,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
```

**Resolve:**
- Navegacao inconsistente (push/pop manual)
- Sem deep linking
- Sem type-safe routes
- `MainNavigationScreen` com logica complexa de trocar root

**Checklist:**
- [ ] Criar `app_router.dart`
- [ ] Definir todas as rotas
- [ ] Migrar `Navigator.push` para `context.go()` / `context.push()`
- [ ] Simplificar `MainNavigationScreen`
- [ ] Testar deep linking

---

## Fase 4: State Management com MVVM (Semana 3-4)

### 4.1 Migrar para MVVM com ChangeNotifier + Provider

**Objetivo:** Implementar o padrao MVVM recomendado oficialmente pelo Flutter, usando **ChangeNotifier + Provider** (como no case study Compass).

**ThemeProvider (depois):**
```dart
// lib/ui/settings/view_models/theme_viewmodel.dart
class ThemeViewModel extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }
}
```

**LocaleViewModel (depois):**
```dart
// lib/ui/settings/view_models/locale_viewmodel.dart
class LocaleViewModel extends ChangeNotifier {
  static const _localeKey = 'app_locale';
  Locale _locale = const Locale('pt', 'BR');

  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_localeKey);
    if (lang == 'en') {
      _locale = const Locale('en', 'US');
    } else {
      _locale = const Locale('pt', 'BR');
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}
```

**PauloFlixViewModel (depois):**
```dart
// lib/ui/pauloflix/view_models/pauloflix_viewmodel.dart
class PauloFlixViewModel extends ChangeNotifier {
  final PauloFlixRepository _repository;
  
  PauloFlixViewModel(this._repository);

  List<PauloFlixContent> _contents = [];
  List<PauloFlixContent> get contents => _contents;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _syncProgress = '';
  String get syncProgress => _syncProgress;

  Future<void> loadContents() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _contents = await _repository.getAllContent();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncContent() async {
    _isLoading = true;
    _syncProgress = 'Iniciando...';
    notifyListeners();

    try {
      final success = await _repository.syncContent(
        onProgress: (p) {
          _syncProgress = p;
          notifyListeners();
        },
      );
      if (success) {
        await loadContents();
      } else {
        _errorMessage = 'Falha na sincronizacao';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    // Implementar busca local com debounce
  }
}
```

**Registro no app.dart:**
```dart
// lib/app.dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ViewModels
        ChangeNotifierProvider(create: (_) => ThemeViewModel()..load()),
        ChangeNotifierProvider(create: (_) => LocaleViewModel()..load()),
        ChangeNotifierProvider(create: (_) => PauloFlixViewModel(sl<PauloFlixRepository>())),
        ChangeNotifierProvider(create: (_) => PauloFlixMoviesViewModel(sl<PauloFlixMoviesRepository>())),
        ChangeNotifierProvider(create: (_) => WatchlistViewModel(sl<WatchlistRepository>())),
        ChangeNotifierProvider(create: (_) => DownloadsViewModel(sl<DownloadsRepository>())),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        // ...
      ),
    );
  }
}
```

**Resolve:**
- `ThemeProvider` nao persiste preferencia
- `LocaleService.init()` nunca chamado
- `WatchlistNotifier` nunca registrado
- `DownloadService` singleton com ChangeNotifier vazado
- `HomeScreen` guarda 6 listas em state local

**Vantagens do padrao oficial (ChangeNotifier + Provider):**
- ✅ Simples e direto, sem code generation
- ✅ Facil de testar (ViewModels sao classes Dart puras)
- ✅ Recomendado oficialmente pelo Flutter
- ✅ Usado no case study Compass
- ✅ ViewModels podem ser mockados facilmente em testes

**Checklist:**
- [ ] Criar ViewModels em `ui/<feature>/view_models/`
- [ ] Migrar `ThemeProvider` para `ThemeViewModel`
- [ ] Migrar `LocaleService` para `LocaleViewModel`
- [ ] Migrar `PauloFlixProvider` para `PauloFlixViewModel`
- [ ] Migrar `PauloFlixMoviesProvider` para `PauloFlixMoviesViewModel`
- [ ] Migrar `DownloadService` para `DownloadsViewModel`
- [ ] Registrar todos com `ChangeNotifierProvider` no `app.dart`
- [ ] Atualizar todos os `Provider.of<T>()` para `context.watch<T>()`
- [ ] Remover `riverpod` do `pubspec.yaml` (se adicionado)

---

### 4.2 Criar ViewModels para Screens

**Objetivo:** Separar logica de negocio das screens seguindo o padrao MVVM oficial.

**Arquivo:** `lib/ui/home/view_models/home_viewmodel.dart`

```dart
class HomeViewModel extends ChangeNotifier {
  final HomeRepository _repository;
  
  HomeViewModel(this._repository);

  HomeData? _homeData;
  HomeData? get homeData => _homeData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadHomeData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _homeData = await _repository.loadHomeData();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      _homeData = await _repository.loadHomeData(forceRefresh: true);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
```

**Arquivo:** `lib/ui/home/widgets/home_screen.dart` (depois)

```dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    if (viewModel.isLoading && viewModel.homeData == null) {
      return const HomeShimmer();
    }

    if (viewModel.errorMessage != null && viewModel.homeData == null) {
      return Center(child: Text('Erro: ${viewModel.errorMessage}'));
    }

    return _buildContent(context, viewModel);
  }
}
```

**ViewModels a criar (um por feature):**
- `HomeViewModel` - carrega dados da home
- `SearchViewModel` - busca de animes
- `VideoPlayerViewModel` - gerenciamento do player
- `PauloFlixViewModel` - lista e sync de conteudo
- `PauloFlixMoviesViewModel` - filmes
- `WatchlistViewModel` - CRUD watchlist
- `DownloadsViewModel` - gerenciamento de downloads
- `SettingsViewModel` - configuracoes

**Padrao MVVM oficial:**
- **View** (`home_screen.dart`): Apenas renderiza UI baseado no estado do ViewModel
- **ViewModel** (`home_viewmodel.dart`): Gerencia estado, chama repositories, expoe dados para a View
- **Commands**: Metodos do ViewModel que a View chama (ex: `loadHomeData()`, `refresh()`)

**Resolve:**
- Screens com logica de negocio, chamadas HTTP, parsing
- Estado local excessivo em `HomeScreen` (6 listas)
- Dificil testar screens

**Checklist:**
- [ ] Criar ViewModels para cada feature em `ui/<feature>/view_models/`
- [ ] Mover logica de negocio das screens para ViewModels
- [ ] Views ficam em `ui/<feature>/widgets/`
- [ ] Views usam `context.watch<ViewModel>()` para observar mudancas
- [ ] Views chamam metodos do ViewModel via commands
- [ ] Registrar ViewModels com `ChangeNotifierProvider` no `app.dart`
- [ ] Testar ViewModels isoladamente com mocks

---

## Fase 5: Repository Pattern (Semana 4)

### 5.1 Interfaces de Repository

**Objetivo:** Abstrair fontes de dados para facilitar testes e troca de implementacao.

**Arquivo:** `lib/features/home/domain/repositories/home_repository.dart`

```dart
abstract class HomeRepository {
  Future<HomeData> loadHomeData({bool forceRefresh = false});
  Future<List<JikanAnime>> getAnimesByGenre(int genreId, {int page = 1});
  Future<List<JikanAnime>> searchAnimes(String query, {int page = 1});
}
```

**Arquivo:** `lib/features/home/data/repositories/home_repository_impl.dart`

```dart
class HomeRepositoryImpl implements HomeRepository {
  final JikanRemoteDatasource _remote;
  final HomeLocalDatasource _local;

  HomeRepositoryImpl({
    required JikanRemoteDatasource remote,
    required HomeLocalDatasource local,
  })  : _remote = remote,
        _local = local;

  @override
  Future<HomeData> loadHomeData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      try {
        final cached = await _local.getCachedHomeData();
        if (cached != null && !cached.isExpired) return cached;
      } on CacheException {
        // Fallback para remote
      }
    }

    final data = await _remote.fetchHomeData();
    await _local.cacheHomeData(data);
    return data;
  }
}
```

**Repositories a criar:**
- `HomeRepository` + `HomeRepositoryImpl`
- `SearchRepository` + `SearchRepositoryImpl`
- `PauloFlixRepository` + `PauloFlixRepositoryImpl`
- `PauloFlixMoviesRepository` + `PauloFlixMoviesRepositoryImpl`
- `WatchlistRepository` + `WatchlistRepositoryImpl`
- `DownloadRepository` + `DownloadRepositoryImpl`
- `PlayerRepository` + `PlayerRepositoryImpl`

**Resolve:**
- Servicos usados como "god objects"
- Logica de cache misturada com logica de negocio
- Impossivel testar sem mock HTTP

**Checklist:**
- [ ] Definir interfaces de Repository (domain layer)
- [ ] Implementar repositories (data layer)
- [ ] Criar datasources (remote + local)
- [ ] Registrar no `service_locator.dart`
- [ ] Substituir chamadas diretas a services nos ViewModels

---

## Fase 6: Bug Fixes Criticos (Semana 4-5)

### 6.1 LocaleService.init() nunca chamado

**Problema:** `main.dart:61` cria `LocaleService` via `ChangeNotifierProvider(create:)` mas `init()` nunca e chamado. O app sempre inicia em `en-US`.

**Solucao:** Com Riverpod, o `build()` do provider ja carrega o valor correto do SharedPreferences. Ver Fase 4.1.

**Checklist:**
- [ ] Verificar se locale e carregado corretamente
- [ ] Testar troca de idioma

---

### 6.2 JikanService._isLoadingHome loop infinito

**Problema:** `jikan_service.dart:156-158` - se excecao ocorre durante loading, flag `_isLoadingHome` pode ficar presa em `true`, causando loop infinito no `while`.

**Solucao:**
```dart
// Antes (problema):
if (_isLoadingHome) {
  while (_isLoadingHome) {
    await Future.delayed(Duration(milliseconds: 100));
  }
}

// Depois (Corrigido):
if (_isLoadingHome) {
  final stopwatch = Stopwatch()..start();
  while (_isLoadingHome && stopwatch.elapsedMilliseconds < 30000) {
    await Future.delayed(Duration(milliseconds: 100));
  }
  if (_isLoadingHome) {
    throw Exception('Timeout: another load is in progress');
  }
}
```

**Completamente resolvido com Riverpod:** o proprio Riverpod gerencia loading state e evita duplicacao.

**Checklist:**
- [ ] Adicionar timeout no while
- [ ] Ou migrar para Riverpod (resolucao completa)

---

### 6.3 Video Player dispose async

**Problema:** `video_player_screen.dart:866` - `_cleanupControllers()` e async mas chamado de `dispose()` que nao pode await.

**Solucao:**
```dart
@override
void dispose() {
  _overlayControlsTimer?.cancel();
  _uninstallHardwareKeyboardHandler();
  SystemChrome.setSystemUIChangeCallback(null);

  // Cleanup sincrono + agendar async
  _player?.stop();
  _errorSub?.cancel();
  _playingSub?.cancel();
  _completedSub?.cancel();
  _tracksSub?.cancel();

  // Async cleanup em background
  _deferredCleanup();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([]);
  super.dispose();
}

Future<void> _deferredCleanup() async {
  await _player?.dispose();
  await _googleVideoProxy?.stop();
}
```

**Checklist:**
- [ ] Separar cleanup sincrono do async
- [ ] Garantir que player.stop() e chamado antes do dispose
- [ ] Testar troca rapida de episodios

---

### 6.4 DatabaseHelper._initCompleter nao reseta em erro

**Problema:** `database_helper.dart:23-25` - se `_initDatabase()` falha, `_initCompleter` fica com erro e chamadas futuras ficam presas.

**Solucao:**
```dart
static Future<Database> get database async {
  if (_database != null) return _database!;
  if (_initCompleter != null) return _initCompleter!.future;

  _initCompleter = Completer<Database>();
  try {
    _database = await _initDatabase();
    _initCompleter!.complete(_database!);
  } catch (e) {
    _initCompleter!.completeError(e);
    _initCompleter = null;  // Reset para permitir retry
    _database = null;
    rethrow;
  }
  return _database!;
}
```

**Completamente resolvido com drift:** o drift gerencia conexao e retry internamente.

**Checklist:**
- [ ] Adicionar reset do `_initCompleter` em caso de erro
- [ ] Ou migrar para drift (resolucao completa)

---

### 6.5 DownloadService singleton nunca disposed

**Problema:** `download_service.dart` e singleton com `ChangeNotifier`. Os `http.Client` em `_downloadClients` podem vazar.

**Solucao com Riverpod:**
```dart
@riverpod
class DownloadManager extends _$DownloadManager {
  @override
  List<DownloadItem> build() {
    // Riverpod gerencia lifecycle automaticamente
    ref.onDispose(() {
      _cancelAll();
      _closeDatabase();
    });
    _loadDownloads();
    return [];
  }

  void _cancelAll() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
  }
}
```

**Checklist:**
- [ ] Migrar para Riverpod com `ref.onDispose()`
- [ ] Garantir que todos os `http.Client` sao fechados
- [ ] Fechar database no dispose

---

## Fase 7: Performance (Semana 5)

### 7.1 Debounce na Busca

**Problema:** `PauloFlixProvider.search()` faz filter O(n) em memoria a cada tecla.

**Solucao:**
```dart
@riverpod
class PauloFlixSearch extends _$PauloFlixSearch {
  @override
  List<PauloFlixContent> build(String query) {
    if (query.isEmpty) return ref.watch(pauloflixNotifierProvider).contents;

    // Debounce automatico com Riverpod
    return ref
        .watch(pauloflixNotifierProvider)
        .contents
        .where((c) =>
          c.displayName.toLowerCase().contains(query.toLowerCase()) ||
          c.genres.any((g) => g.toLowerCase().contains(query.toLowerCase()))
        )
        .toList();
  }
}

// Na screen:
final query = useState('');
// ...
TextField(
  onChanged: (v) => query.value = v,
)
// Riverpod faz debounce automaticamente com .debounce()
```

**Checklist:**
- [ ] Adicionar debounce na busca PauloFlix
- [ ] Adicionar debounce na busca de animes
- [ ] Adicionar debounce na busca de filmes

---

### 7.2 Parsing HTML em Isolate

**Problema:** `AnimeService` faz parsing HTML pesado na main isolate, travando a UI.

**Solucao:**
```dart
static Future<List<Anime>> searchAnime(String animeName) async {
  final htmlContent = await _fetchSearchPage(animeName);
  // Parsing pesado em isolate separado
  return compute(_parseSearchResults, htmlContent);
}

static List<Anime> _parseSearchResults(String html) {
  final document = html_parser.parse(html);
  // ... parsing logico
  return animes;
}
```

**Checklist:**
- [ ] Mover parsing HTML para `compute()`
- [ ] Mover parsing de episodios para `compute()`
- [ ] Mover parsing de Blogger para `compute()`

---

### 7.3 Otimizar PauloFlix Sync

**Problema:** `PauloFlixService.syncContent()` faz search individual no Jikan para cada show - O(N) requests.

**Solucao:**
```dart
static Future<List<PauloFlixContent>> _enrichShowsWithJikan(
  List<PauloFlixShow> shows,
  void Function(String)? onProgress,
) async {
  // Batch de 5 em 5 com Future.wait
  final batches = shows.slices(size: 5);
  final allContents = <PauloFlixContent>[];

  for (final batch in batches) {
    final results = await Future.wait(
      batch.map((show) => _enrichSingleShow(show)),
    );
    allContents.addAll(results);
    onProgress?.call('Processados ${allContents.length}/${shows.length}');
    await Future.delayed(Duration(seconds: 1)); // Rate limit
  }

  return allContents;
}
```

**Checklist:**
- [ ] Implementar batch processing
- [ ] Adicionar parallelismo controlado (5 simultaneos)
- [ ] Manter rate limit entre batches

---

### 7.4 Remover AutomaticKeepAliveClientMixin desnecessario

**Problema:** `HomeScreen` usa `AutomaticKeepAliveClientMixin` mantendo estado vivo mesmo fora da tela.

**Solucao:** Com go_router + `ShellRoute`, o estado e preservado automaticamente quando necessario. Remover o mixin.

**Checklist:**
- [ ] Avaliar se o mixin e realmente necessario
- [ ] Se nao, remover e testar comportamento
- [ ] Se sim, documentar o motivo

---

## Fase 8: Seguranca (Semana 5-6)

### 8.1 URL do Servidor PauloFlix

**Problema:** `pauloflix_service.dart:12` - URL hardcoded em plaintext com HTTP.

**Solucao:**
```dart
// lib/core/constants/api_constants.dart
class ApiConstants {
  static const String pauloFlixBaseUrl = String.fromEnvironment(
    'PAULOFLIX_URL',
    defaultValue: 'https://pauloflix.example.com/tvshows/',
  );

  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';
  static const String anilistBaseUrl = 'https://graphql.anilist.co';
  static const String aniskipBaseUrl = 'https://api.aniskip.com/v2';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
}
```

**Checklist:**
- [ ] Mover URLs para `ApiConstants`
- [ ] Usar `String.fromEnvironment` para configuracao em build time
- [ ] Migrar HTTP para HTTPS

---

### 8.2 GoogleVideoProxy Seguranca

**Problema:** `google_video_proxy.dart` abre porta no loopback sem autenticacao.

**Solucao:**
```dart
Future<void> _handleRequest(HttpRequest request) async {
  // Validar que o request vem do proprio dispositivo
  final remoteAddress = request.connectionInfo?.remoteAddress;
  if (remoteAddress != null &&
      !remoteAddress.isLoopback &&
      remoteAddress.address != '127.0.0.1') {
    request.response.statusCode = HttpStatus.forbidden;
    await request.response.close();
    return;
  }
  // ... resto do handler
}
```

**Checklist:**
- [ ] Adicionar validacao de loopback
- [ ] Limitar tamanho do request
- [ ] Adicionar timeout por conexao

---

## Fase 9: Testing (Semana 6-8)

### 9.1 Testes Unitarios de Models

```dart
// test/models/anime_test.dart
void main() {
  group('Anime', () {
    test('imageUrl returns aniList cover when available', () {
      final anime = Anime(
        name: 'Naruto',
        url: 'https://example.com',
        aniListData: MediaDetails(
          coverImage: CoverImage(large: 'https://cover.jpg', best: 'https://cover.jpg'),
        ),
      );
      expect(anime.imageUrl, 'https://cover.jpg');
    });

    test('imageUrl returns fallback when no aniList data', () {
      final anime = Anime(
        name: 'Naruto',
        url: 'https://example.com',
        fallbackImageUrl: 'https://fallback.jpg',
      );
      expect(anime.imageUrl, 'https://fallback.jpg');
    });

    test('copyWith creates new instance with updated fields', () {
      final anime = Anime(name: 'Naruto', url: 'https://example.com');
      final updated = anime.copyWith(name: 'Boruto');
      expect(updated.name, 'Boruto');
      expect(updated.url, 'https://example.com');
    });
  });
}
```

### 9.2 Testes de ViewModels com mocktail

```dart
// test/features/home/home_viewmodel_test.dart
void main() {
  late HomeViewModel viewModel;
  late MockHomeRepository mockRepository;

  setUp(() {
    mockRepository = MockHomeRepository();
    viewModel = HomeViewModel(repository: mockRepository);
  });

  test('loadHomeData returns data on success', () async {
    final expectedData = HomeData(
      seasonAnimes: [/* ... */],
      // ...
    );
    when(() => mockRepository.loadHomeData())
        .thenAnswer((_) async => expectedData);

    await viewModel.loadHomeData();

    expect(viewModel.state.status, Status.success);
    expect(viewModel.state.data, expectedData);
  });

  test('loadHomeData returns error on failure', () async {
    when(() => mockRepository.loadHomeData())
        .thenThrow(ServerException('API error'));

    await viewModel.loadHomeData();

    expect(viewModel.state.status, Status.error);
    expect(viewModel.state.errorMessage, isNotEmpty);
  });
}

class MockHomeRepository extends Mock implements HomeRepository {}
```

### 9.3 Testes de Repositories

```dart
// test/features/home/data/home_repository_impl_test.dart
void main() {
  late HomeRepositoryImpl repository;
  late MockJikanRemoteDatasource mockRemote;
  late MockHomeLocalDatasource mockLocal;

  setUp(() {
    mockRemote = MockJikanRemoteDatasource();
    mockLocal = MockHomeLocalDatasource();
    repository = HomeRepositoryImpl(remote: mockRemote, local: mockLocal);
  });

  test('loadHomeData returns cached data when available and not expired', () async {
    final cachedData = HomeData(/* ... */);
    when(() => mockLocal.getCachedHomeData())
        .thenAnswer((_) async => cachedData);

    final result = await repository.loadHomeData();

    expect(result, cachedData);
    verifyNever(() => mockRemote.fetchHomeData());
  });

  test('loadHomeData fetches remote when cache is expired', () async {
    final expiredData = HomeData(/* ... */);
    final freshData = HomeData(/* ... */);
    when(() => mockLocal.getCachedHomeData())
        .thenAnswer((_) async => expiredData);
    when(() => mockRemote.fetchHomeData())
        .thenAnswer((_) async => freshData);

    final result = await repository.loadHomeData(forceRefresh: true);

    expect(result, freshData);
  });
}
```

**Checklist:**
- [ ] Configurar `flutter_test` + `mocktail`
- [ ] Testes unitarios para todos os models
- [ ] Testes unitarios para todos os ViewModels
- [ ] Testes unitarios para todos os Repositories
- [ ] Testes de integracao para fluxos criticos (player, download)
- [ ] Widget tests para componentes reutilizaveis
- [ ] Meta: 70%+ de cobertura

---

## Fase 10: Code Quality (Semana 7-8)

### 10.1 analysis_options.yaml Reforcado

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint
  errors:
    missing_return: error
    dead_code: warning
    unused_import: warning
    unused_local_variable: warning

linter:
  rules:
    - always_declare_return_types
    - annotate_overrides
    - avoid_empty_else
    - avoid_print
    - avoid_relative_lib_imports
    - avoid_returning_null_for_future
    - avoid_slow_async_io
    - avoid_types_as_parameter_names
    - avoid_unnecessary_containers
    - avoid_web_libraries_in_flutter
    - cancel_subscriptions
    - close_sinks
    - no_duplicate_case_values
    - no_logic_in_create_state
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_in_for_each
    - prefer_final_locals
    - prefer_single_quotes
    - require_trailing_commas
    - sort_child_widgets_last
    - test_types_in_equals
    - throw_in_finally
    - unnecessary_statements
    - use_build_context_synchronously
    - use_key_in_widget_constructors
```

### 10.2 Remover Campos Mutaveis

Todos os models migrados para `@freezed` sao imutaveis. Os servicos que modificam estado agora usam `copyWith`.

### 10.3 Const Constructors

Adicionar `const` em todos os widgets e classes onde possivel.

**Checklist:**
- [ ] Atualizar `analysis_options.yaml`
- [ ] Rodar `flutter analyze` e corrigir todos os warnings
- [ ] Adicionar `const` onde possivel
- [ ] Remover imports nao utilizados
- [ ] Adicionar trailing commas

---

## Cronograma Resumo

| Fase | Semanas | Entregaveis | Prioridade |
|---|---|---|---|
| 0 - Fundacao | 1 | pubspec, estrutura MVVM oficial, Provider DI | Alta |
| 1 - Core Infra | 2 | Dio, drift, errors, logger | Alta |
| 2 - Models freezed | 2-3 | Todos os models imutaveis | Alta |
| 3 - go_router | 3 | Navegacao type-safe | Alta |
| 4 - MVVM + Provider | 3-4 | ViewModels + ChangeNotifier (padrao oficial) | Alta |
| 5 - Repository | 4 | Interfaces + impls | Alta |
| 6 - Bug Fixes | 4-5 | Locale, dispose, DB, loading | Critica |
| 7 - Performance | 5 | Debounce, isolates, batch | Media |
| 8 - Seguranca | 5-6 | URLs, proxy, headers | Media |
| 9 - Testing | 6-8 | Unit, integration, widget | Media |
| 10 - Code Quality | 7-8 | Lint, const, cleanup | Baixa |

**Total estimado:** 8 semanas (2 meses)

---

## Ordem de Execucao Recomendada

```
Fase 6 (Bug Fixes Criticos)  <-- fazer PRIMEIRO, independente da migracao
    |
Fase 0 (Fundacao)
    |
Fase 1 (Core Infra) ---------> Dio + drift + errors
    |
Fase 2 (Models freezed) -----> imutabilidade
    |
Fase 3 (go_router) ----------> navegacao
    |
Fase 4 (MVVM + Provider) ----> ViewModels + ChangeNotifier (padrao oficial)
    |
Fase 5 (Repository) ---------> clean architecture
    |
Fase 7 (Performance) --------> otimizacao
    |
Fase 8 (Seguranca) ----------> hardening
    |
Fase 9 (Testing) ------------> cobertura
    |
Fase 10 (Code Quality) ------> polish
```

---

## Alinhamento com Documentacao Oficial Flutter

Este plano foi atualizado para seguir as [recomendacoes oficiais do Flutter](https://docs.flutter.dev/app-architecture/guide):

### ✅ O que seguimos da docs oficial:

1. **Arquitetura MVVM** (UI Layer + Data Layer + Domain Layer opcional)
2. **Estrutura de pastas**: `ui/` (por feature) + `data/` (por tipo) + `domain/`
3. **State Management**: ChangeNotifier + Provider (como no case study Compass)
4. **ViewModels**: Classes Dart puras que gerenciam estado da UI
5. **Views**: Widgets que apenas renderizam baseado no estado do ViewModel
6. **Repositories**: Fonte de verdade dos dados (cache + remote)
7. **Services**: Interagem com APIs externas, DB, plugins
8. **Dependency Injection**: Provider para tudo (services, repositories, ViewModels)

### 📚 Referencias oficiais utilizadas:

- [Guide to app architecture](https://docs.flutter.dev/app-architecture/guide)
- [Architecture case study (Compass app)](https://docs.flutter.dev/app-architecture/case-study)
- [UI layer](https://docs.flutter.dev/app-architecture/case-study/ui-layer)
- [Data layer](https://docs.flutter.dev/app-architecture/case-study/data-layer)
- [Dependency injection](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
- [Testing each layer](https://docs.flutter.dev/app-architecture/case-study/testing)

### 🎯 Mudancas em relacao ao plano original:

| Aspecto | Plano Original | Plano Atualizado | Motivo |
|---|---|---|---|
| **State Management** | Riverpod 2.x | **Provider + ChangeNotifier** | Seguir case study oficial (Compass) |
| **ViewModels** | Riverpod com codegen | **ChangeNotifier puro** | Simples, testavel, oficial |
| **Estrutura** | `features/` com data/domain/presentation | **`ui/` + `data/` + `domain/`** | Padrao oficial |
| **DI** | get_it + Riverpod | **Provider** (tudo) | Uma unica biblioteca, segue Compass |

### 💡 Por que Provider em vez de Riverpod?

A documentacao oficial do Flutter usa **ChangeNotifier + Provider** no case study Compass e menciona explicitamente que Riverpod, Bloc e Signals sao alternativas validas. Escolhemos **Provider** porque:

1. ✅ **Oficial**: Usado no case study oficial do Flutter
2. ✅ **Simples**: Sem code generation, mais direto
3. ✅ **Testavel**: ViewModels sao classes Dart puras, faceis de mockar
4. ✅ **Familiar**: Ja estamos usando Provider no projeto
5. ✅ **Documentado**: Mais exemplos e tutoriais oficiais

Riverpod seria uma escolha valida tambem, mas Provider e mais alinhado com as recomendacoes oficiais atuais.

---

## Riscos e Mitigacoes

| Risco | Probabilidade | Impacto | Mitigacao |
|---|---|---|---|
| Breaking changes na migracao Provider -> Riverpod | Alta | Alto | Migrar feature por feature, manter Provider como fallback |
| drift migration perde dados existentes | Media | Alto | Testar migration em staging, backup automatico |
| go_router muda comportamento de back stack | Media | Medio | Testar todos os fluxos de navegacao |
| Code generation lento em CI | Media | Baixo | Cache de build, otimizar build.yaml |
| freezed gera muito boilerplate | Baixa | Baixa | Normal, o codegen cuida disso |

---

## Comandos de Verificacao

```bash
# Apos cada fase:
flutter analyze
flutter test
flutter build apk --release

# Code generation:
dart run build_runner build --delete-conflicting-outputs

# Verificar cobertura de testes:
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## Notas Finais

- Cada fase deve ser um **PR separado** para facilitar review
- **Nao quebrar funcionalidade existente** - cada fase deve manter o app funcional
- **Testes devem ser escritos ANTES da refatoracao** quando possivel (TDD)
- Usar **feature flags** para migrar gradualmente (ex: `useRiverpod: true/false`)
- Documentar decisoes de arquitetura em ADRs (Architecture Decision Records)
