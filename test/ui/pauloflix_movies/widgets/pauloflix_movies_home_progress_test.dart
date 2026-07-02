/// Teste de integração: `PauloFlixMoviesHomeScreen` atualiza os overlays
/// de progresso nos cards ao receber dados do stream reativo.
///
/// Cenários:
/// 1. Stream vazio → nenhum overlay de progresso visível
/// 2. Stream emite progresso parcial → barra de progresso aparece nos cards
/// 3. Stream emite progresso completo → badge verde aparece nos cards
/// 4. Stream emite atualização (remover progresso) → overlay some
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goanime/domain/models/paulo_flix_movie_progress_record.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';
import 'package:goanime/domain/repositories/paulo_flix_movie_progress_repository.dart';
import 'package:goanime/domain/repositories/pauloflix_movies_repository.dart';
import 'package:goanime/l10n/app_localizations.dart';
import 'package:goanime/ui/pauloflix_movies/view_models/pauloflix_movies_provider.dart';
import 'package:goanime/ui/pauloflix_movies/widgets/pauloflix_movies_home_screen.dart';
import 'package:goanime/ui/core/widgets/completed_badge.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// Mocks
// ═══════════════════════════════════════════════════════════════════════

/// Mock do `PauloFlixMoviesRepository` — retorna dados em memória.
class _FakeMoviesRepository implements PauloFlixMoviesRepository {
  final List<PauloFlixMovie> data;
  _FakeMoviesRepository(this.data);

  @override
  Future<List<PauloFlixMovie>> getAll() async => data;

  @override
  Future<List<PauloFlixMovie>> searchByName(String query) async => data;

  @override
  Future<PauloFlixMovie?> getByFolderName(String folderName) async =>
      data.where((m) => m.folderName == folderName).firstOrNull;

  @override
  Future<PauloFlixMovie?> getByTmdbId(int tmdbId) async => null;

  @override
  Future<void> saveContent(PauloFlixMovie content) async {}

  @override
  Future<void> saveBatch(List<PauloFlixMovie> movies) async {}

  @override
  Future<void> markAsUnavailable(String folderName) async {}

  @override
  Future<Map<String, int>> getStats() async => {
        'total': data.length,
        'available': data.length,
        'withMetadata': data.length,
        'collections': 0,
      };

  @override
  Stream<List<PauloFlixMovie>> watch() => const Stream.empty();
}

/// Mock do `PauloFlixMovieProgressRepository` com `StreamController`
/// para controle reativo dos dados de progresso.
class _MockProgressRepo implements PauloFlixMovieProgressRepository {
  final StreamController<List<PauloFlixMovieProgressRecord>> _controller;

  _MockProgressRepo()
      : _controller = StreamController<List<PauloFlixMovieProgressRecord>>.broadcast();

  void emit(List<PauloFlixMovieProgressRecord> records) {
    _controller.add(records);
  }

  void close() => _controller.close();

  @override
  Stream<List<PauloFlixMovieProgressRecord>> watchAllProgress() =>
      _controller.stream;

  @override
  Stream<List<PauloFlixMovieProgressRecord>> watchInProgressMovies({
    int limit = 12,
  }) =>
      _controller.stream;

  @override
  Future<PauloFlixMovieProgressRecord?> getProgress(String folderName) async =>
      null;

  @override
  Future<List<PauloFlixMovieProgressRecord>> getInProgressMovies({
    int limit = 12,
  }) async => [];

  @override
  Future<List<PauloFlixMovieProgressRecord>> getAllProgress() async => [];

  @override
  Future<void> updateProgress({
    required String folderName,
    required String serverUrl,
    required String displayName,
    String? imageUrl,
    String? videoUrl,
    required int positionSeconds,
    int? durationSeconds,
  }) async {}

  @override
  Future<void> resetProgress(String folderName) async {}
}

// ═══════════════════════════════════════════════════════════════════════
// Fixtures
// ═══════════════════════════════════════════════════════════════════════

PauloFlixMovie _movie({
  required String folderName,
  required String displayName,
}) {
  return PauloFlixMovie(
    folderName: folderName,
    displayName: displayName,
    serverUrl: 'https://server/$folderName/',
    videoUrl: 'https://server/$folderName/video.mp4',
    imageUrl: 'https://server/$folderName/poster.jpg',
    score: 8.0,
    genres: const ['Action'],
  );
}

/// Cria uma lista de filmes para popular a home.
List<PauloFlixMovie> _testMovies() => [
      _movie(folderName: 'filme-1', displayName: 'Filme Action 1'),
      _movie(folderName: 'filme-2', displayName: 'Filme Action 2'),
    ];

PauloFlixMovieProgressRecord _progressRecord({
  required String folderName,
  required int positionSeconds,
  int durationSeconds = 6000,
  bool isCompleted = false,
}) {
  return PauloFlixMovieProgressRecord(
    folderName: folderName,
    serverUrl: 'https://server/$folderName/',
    displayName: 'Filme $folderName',
    positionSeconds: positionSeconds,
    durationSeconds: durationSeconds,
    isCompleted: isCompleted,
    lastSynced: DateTime.now(),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

/// Monta o widget tree completo: GoRouter + Providers + MoviesHomeScreen.
Widget _buildTestApp({
  required List<PauloFlixMovie> movies,
  required PauloFlixMovieProgressRepository progressRepo,
}) {
  final moviesRepo = _FakeMoviesRepository(movies);
  final provider = PauloFlixMoviesProvider.withServices(
    repository: moviesRepo,
  );

  final router = GoRouter(
    initialLocation: '/pauloflix-movies',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/pauloflix-movies',
            name: 'pauloflix-movies',
            builder: (context, state) => MultiProvider(
              providers: [
                ChangeNotifierProvider<PauloFlixMoviesProvider>.value(
                  value: provider,
                ),
                Provider<PauloFlixMovieProgressRepository>.value(
                  value: progressRepo,
                ),
              ],
              child: const PauloFlixMoviesHomeScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Player Screen'))),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

/// Helper: faz os pumps necessários para processar a carga inicial.
Future<void> pumpUntilReady(WidgetTester tester) async {
  // Pump 1: first build + initState
  await tester.pump();
  // Pump 2: postFrameCallback → provider.loadContents()
  await tester.pump();
  // Pump 3: loadContents completa → notifyListeners → rebuild
  await tester.pump();
  // Pump 4: rebuild → _ensureSnapshotBuilt
  await tester.pump();
  // Pump 5: nested postFrameCallback → _subscribeToProgressStream + TV detect
  await tester.pump();
  // Pump 6: estabiliza
  await tester.pump();
}

// ═══════════════════════════════════════════════════════════════════════
// Testes
// ═══════════════════════════════════════════════════════════════════════

void main() {
  group('PauloFlixMoviesHomeScreen — overlays de progresso reativos', () {
    final testMovies = _testMovies();

    testWidgets('stream vazio: nenhum overlay de progresso visível', (
      tester,
    ) async {
      final progressRepo = _MockProgressRepo();

      await tester.pumpWidget(
        _buildTestApp(movies: testMovies, progressRepo: progressRepo),
      );
      await pumpUntilReady(tester);

      // Nenhum overlay de progresso (barra ou badge) deve aparecer
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      // Os títulos dos filmes devem estar visíveis (podem aparecer
      // em múltiplas seções: carrosséis + grid "Todos os Filmes")
      expect(find.text('Filme Action 1'), findsWidgets);
      expect(find.text('Filme Action 2'), findsWidgets);

      progressRepo.close();
    });

    testWidgets(
        'stream emite progresso parcial: barra de progresso '
        'aparece nos cards', (tester) async {
      final progressRepo = _MockProgressRepo();

      await tester.pumpWidget(
        _buildTestApp(movies: testMovies, progressRepo: progressRepo),
      );
      await pumpUntilReady(tester);

      // Inicialmente sem overlay
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Emite progresso parcial para filme-1
      progressRepo.emit([
        _progressRecord(
          folderName: 'filme-1',
          positionSeconds: 300,
          durationSeconds: 6000,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Barra de progresso deve aparecer (pode estar tanto no card
      // do carrossel quanto na seção "Continue assistindo")
      expect(find.byType(LinearProgressIndicator), findsAtLeastNWidgets(1));
      // NÃO deve ter badge de completo
      expect(find.byIcon(Icons.check_circle), findsNothing);

      progressRepo.close();
    });

    testWidgets(
        'stream emite progresso completo: badge verde aparece '
        'nos cards', (tester) async {
      final progressRepo = _MockProgressRepo();

      await tester.pumpWidget(
        _buildTestApp(movies: testMovies, progressRepo: progressRepo),
      );
      await pumpUntilReady(tester);

      // Emite progresso completo para filme-1
      progressRepo.emit([
        _progressRecord(
          folderName: 'filme-1',
          positionSeconds: 6000,
          durationSeconds: 6000,
          isCompleted: true,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Deve ter badge de completo (pode aparecer em múltiplas
      // seções: card do carrossel + "Continue assistindo")
      expect(find.byIcon(Icons.check_circle), findsAtLeastNWidgets(1));

      progressRepo.close();
    });

    testWidgets(
        'stream emite atualização e depois remove: overlay '
        'some quando progresso é zerado', (tester) async {
      final progressRepo = _MockProgressRepo();

      await tester.pumpWidget(
        _buildTestApp(movies: testMovies, progressRepo: progressRepo),
      );
      await pumpUntilReady(tester);

      // 1. Emite progresso parcial
      progressRepo.emit([
        _progressRecord(
          folderName: 'filme-1',
          positionSeconds: 300,
          durationSeconds: 6000,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsAtLeastNWidgets(1));

      // 2. Emite lista vazia (reset/remove progresso)
      progressRepo.emit([]);
      await tester.pump();
      await tester.pump();

      // Overlay deve ter sumido
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);

      progressRepo.close();
    });

    testWidgets(
        'stream com múltiplos filmes: cada card tem seu overlay '
        'correto', (tester) async {
      final progressRepo = _MockProgressRepo();

      await tester.pumpWidget(
        _buildTestApp(movies: testMovies, progressRepo: progressRepo),
      );
      await pumpUntilReady(tester);

      // Emite progresso para ambos os filmes: filme-1 parcial, filme-2 completo
      progressRepo.emit([
        _progressRecord(
          folderName: 'filme-1',
          positionSeconds: 300,
          durationSeconds: 6000,
          isCompleted: false,
        ),
        _progressRecord(
          folderName: 'filme-2',
          positionSeconds: 6000,
          durationSeconds: 6000,
          isCompleted: true,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Scroll para baixo para revelar os cards no grid "Todos os Filmes"
      await tester.dragUntilVisible(
        find.byType(CompletedBadge),
        find.byType(PauloFlixMoviesHomeScreen),
        const Offset(0, -300),
      );

      // Deve ter barra de progresso (filme-1) — pode aparecer em
      // múltiplas seções da home
      expect(find.byType(LinearProgressIndicator), findsAtLeastNWidgets(1));
      // Deve ter o badge CompletedBadge (filme-2)
      expect(find.byType(CompletedBadge), findsAtLeastNWidgets(1));

      progressRepo.close();
    });
  });
}
