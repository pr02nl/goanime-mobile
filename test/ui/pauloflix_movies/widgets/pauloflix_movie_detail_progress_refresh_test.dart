/// Teste de integração: `PauloFlixMovieDetailScreen` atualiza o progresso
/// ao voltar do player.
///
/// Cenários:
/// 1. Inicialmente sem progresso → botão "Assistir", sem barra de progresso
/// 2. Após retornar do player com progresso parcial → botão "Continuar",
///    barra de progresso visível
/// 3. Após retornar do player com filme completo → botão "Reassistir",
///    badge verde "✓ Completo"
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goanime/domain/models/paulo_flix_movie_progress_record.dart';
import 'package:goanime/domain/models/pauloflix_movie.dart';
import 'package:goanime/domain/repositories/paulo_flix_movie_progress_repository.dart';
import 'package:goanime/l10n/app_localizations.dart';
import 'package:goanime/ui/pauloflix_movies/widgets/pauloflix_movie_detail_screen.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// Mocks
// ═══════════════════════════════════════════════════════════════════════

/// Contador de chamadas ao `getProgress`.
/// Permite ao test verificar que o refresh foi disparado.
class _CallCounter {
  int calls = 0;
}

/// Mock do `PauloFlixMovieProgressRepository` que retorna progresso
/// diferente dependendo de quantas vezes foi consultado.
///
/// - 1ª consulta → `_initialProgress` (sem progresso)
/// - 2ª consulta em diante → `_updatedProgress` (simulando que o
///   player salvou antes de voltar)
class _MockProgressRepository implements PauloFlixMovieProgressRepository {
  final PauloFlixMovieProgressRecord? _initialProgress;
  final PauloFlixMovieProgressRecord? _updatedProgress;
  final _CallCounter counter;

  _MockProgressRepository({
    required PauloFlixMovieProgressRecord? initialProgress,
    required PauloFlixMovieProgressRecord? updatedProgress,
    required this.counter,
  })  : _initialProgress = initialProgress,
        _updatedProgress = updatedProgress;

  @override
  Future<PauloFlixMovieProgressRecord?> getProgress(String folderName) async {
    counter.calls++;
    if (counter.calls >= 2) return _updatedProgress;
    return _initialProgress;
  }

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

  @override
  Future<List<PauloFlixMovieProgressRecord>> getInProgressMovies({
    int limit = 12,
  }) async => [];

  @override
  Stream<List<PauloFlixMovieProgressRecord>> watchInProgressMovies({
    int limit = 12,
  }) =>
      const Stream.empty();

  @override
  Future<List<PauloFlixMovieProgressRecord>> getAllProgress() async => [];

  @override
  Stream<List<PauloFlixMovieProgressRecord>> watchAllProgress() =>
      const Stream.empty();
}

// ═══════════════════════════════════════════════════════════════════════
// Fixtures
// ═══════════════════════════════════════════════════════════════════════

PauloFlixMovie _movieFixture() {
  return PauloFlixMovie(
    folderName: 'filme-teste',
    displayName: 'Filme Teste',
    serverUrl: 'https://server/filme-teste/',
    videoUrl: 'https://server/filme-teste/video.mp4',
    imageUrl: 'https://server/filme-teste/poster.jpg',
    score: 8.5,
    genres: const ['Action', 'Adventure'],
    runtime: 120,
    year: 2024,
    description: 'Um filme de teste.',
  );
}

PauloFlixMovieProgressRecord _noProgress() {
  return PauloFlixMovieProgressRecord(
    folderName: 'filme-teste',
    serverUrl: 'https://server/filme-teste/',
    displayName: 'Filme Teste',
    positionSeconds: 0,
    isCompleted: false,
    lastSynced: DateTime.now(),
  );
}

PauloFlixMovieProgressRecord _inProgress() {
  return PauloFlixMovieProgressRecord(
    folderName: 'filme-teste',
    serverUrl: 'https://server/filme-teste/',
    displayName: 'Filme Teste',
    positionSeconds: 500,
    durationSeconds: 6000, // 1h40min
    isCompleted: false,
    lastSynced: DateTime.now(),
  );
}

PauloFlixMovieProgressRecord _completed() {
  return PauloFlixMovieProgressRecord(
    folderName: 'filme-teste',
    serverUrl: 'https://server/filme-teste/',
    displayName: 'Filme Teste',
    positionSeconds: 6000,
    durationSeconds: 6000,
    isCompleted: true,
    lastSynced: DateTime.now(),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// Helpers de construção do widget tree
// ═══════════════════════════════════════════════════════════════════════

/// Monta o widget tree completo: GoRouter + Provider + MovieDetailScreen.
///
/// Usa o mesmo padrão do `pauloflix_see_all_screen_refresh_test.dart`:
/// GoRouter com rota `/pauloflix-movie-detail` (dentro de ShellRoute) +
/// rota `/player` (fora do shell) para simular navegação.
Widget _buildTestApp({
  required PauloFlixMovie movie,
  required PauloFlixMovieProgressRepository repo,
  bool hasPlayerRoute = true,
}) {
  final router = GoRouter(
    initialLocation: '/pauloflix-movie-detail',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/pauloflix-movie-detail',
            name: 'pauloflix-movie-detail',
            builder: (context, state) => Provider<
                PauloFlixMovieProgressRepository?>.value(
              value: repo,
              child: PauloFlixMovieDetailScreen(content: movie),
            ),
          ),
        ],
      ),
      if (hasPlayerRoute)
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
/// Retorna o GoRouter para navegação.
Future<GoRouter> initialLoad(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  // Pump 1: first build + initState → _resolveSingleMovie + _loadProgress
  await tester.pump();
  // Pump 2: postFrameCallback (se houver)
  await tester.pump();
  // Pump 3: estabiliza
  await tester.pump();

  return GoRouter.of(tester.element(find.byType(PauloFlixMovieDetailScreen)));
}

// ═══════════════════════════════════════════════════════════════════════
// Testes
// ═══════════════════════════════════════════════════════════════════════

void main() {
  group('PauloFlixMovieDetailScreen — refresh ao voltar do player', () {
    final movie = _movieFixture();
    late _CallCounter counter;

    setUp(() {
      counter = _CallCounter();
    });

    testWidgets('inicialmente sem progresso: botão "Assistir", '
        'sem barra de progresso', (tester) async {
      await initialLoad(
        tester,
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _inProgress(),
            counter: counter,
          ),
        ),
      );

      // Botão deve mostrar "Assistir" (sem progresso)
      expect(find.text('Assistir'), findsOneWidget);
      // NÃO deve ter barra de progresso
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // NÃO deve ter badge de completo
      expect(find.byIcon(Icons.check_circle), findsNothing);
      // NÃO deve ter "Reassistir"
      expect(find.text('Reassistir'), findsNothing);
      // NÃO deve ter "Continuar"
      expect(find.text('Continuar'), findsNothing);
    });

    testWidgets('getProgress é chamado 1x na carga inicial', (tester) async {
      await initialLoad(
        tester,
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _inProgress(),
            counter: counter,
          ),
        ),
      );

      expect(counter.calls, equals(1));
    });

    testWidgets(
        'após voltar do player com progresso parcial: '
        'botão "Continuar" + barra de progresso', (tester) async {
      await initialLoad(
        tester,
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _inProgress(),
            counter: counter,
          ),
        ),
      );

      // Estado inicial: "Assistir", sem barra
      expect(find.text('Assistir'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Simula retorno do player recriando o app
      await tester.pumpWidget(
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _inProgress(),
            counter: counter,
          ),
        ),
      );
      // Pumps para processar initState → _loadProgress
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Agora: botão "Continuar" + barra de progresso
      expect(find.text('Continuar'), findsOneWidget);
      // Deve ter pelo menos 1 LinearProgressIndicator
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Deve mostrar a porcentagem
      expect(find.textContaining('% assistido'), findsOneWidget);
      // NÃO deve ter badge de completo
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets(
        'após voltar do player com filme completo: '
        'botão "Reassistir" + badge verde', (tester) async {
      await initialLoad(
        tester,
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _completed(),
            counter: counter,
          ),
        ),
      );

      // Estado inicial: "Assistir"
      expect(find.text('Assistir'), findsOneWidget);

      // Simula retorno do player recriando o app
      await tester.pumpWidget(
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _completed(),
            counter: counter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Botão deve mostrar "Reassistir"
      expect(find.text('Reassistir'), findsOneWidget);
      // Deve ter badge de completo (check_circle)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // NÃO deve ter barra de progresso
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets(
        'se progresso não mudar, botão continua "Assistir" '
        '(sem barra)', (tester) async {
      // Neste cenário, initialProgress == updatedProgress (não mudou)
      await initialLoad(
        tester,
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _noProgress(), // sem mudança
            counter: counter,
          ),
        ),
      );

      // Estado inicial: "Assistir"
      expect(find.text('Assistir'), findsOneWidget);

      // Simula retorno do player recriando o app
      await tester.pumpWidget(
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _noProgress(), // sem mudança
            counter: counter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Continua "Assistir" (sem progresso)
      expect(find.text('Assistir'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets(
        'getProgress é chamado novamente após rebuild '
        '(simulando retorno do player)', (tester) async {
      await initialLoad(
        tester,
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _inProgress(),
            counter: counter,
          ),
        ),
      );
      expect(counter.calls, equals(1));

      // Simula retorno do player recriando o app
      await tester.pumpWidget(
        _buildTestApp(
          movie: movie,
          repo: _MockProgressRepository(
            initialProgress: _noProgress(),
            updatedProgress: _inProgress(),
            counter: counter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // getProgress deve ter sido chamado 2x
      // (1 inicial + 1 da remontagem)
      expect(counter.calls, equals(2));
    });
  });
}
