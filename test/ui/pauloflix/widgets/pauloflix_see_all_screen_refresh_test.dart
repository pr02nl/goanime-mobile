/// Teste de widget: ao voltar do player, os cards de progresso atualizam.
///
/// Verifica o mecanismo `_onRouteChanged` + `_scheduleStatsRefresh` +
/// `_loadAllStats` que recarrega `_statsById` quando o GoRouter notifica
/// que a rota voltou para `/pauloflix-see-all`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goanime/domain/models/paulo_flix_episode_record.dart';
import 'package:goanime/domain/models/paulo_flix_progress_stats.dart';
import 'package:goanime/domain/models/paulo_flix_season_record.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:goanime/domain/repositories/pauloflix_repository.dart';
import 'package:goanime/l10n/app_localizations.dart';
import 'package:goanime/ui/pauloflix/view_models/pauloflix_provider.dart';
import 'package:goanime/ui/pauloflix/widgets/pauloflix_see_all_screen.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// Mocks
// ═══════════════════════════════════════════════════════════════════════

/// Fake do `PauloFlixRepository` — retorna dados em memória.
class _FakeContentRepository implements PauloFlixRepository {
  final List<PauloFlixContent> data;
  _FakeContentRepository(this.data);

  @override
  Future<List<PauloFlixContent>> getAll() async => data;
  @override
  Future<List<PauloFlixContent>> searchByName(String query) async => data;
  @override
  Future<PauloFlixContent?> getByFolderName(String folderName) async => null;
  @override
  Future<void> saveContent(PauloFlixContent content) async {}
  @override
  Future<void> saveBatch(List<PauloFlixContent> contents) async {}
  @override
  Future<void> markAsUnavailable(String folderName) async {}
  @override
  Future<Map<String, int>> getStats() async => {
    'total': data.length,
    'available': data.length,
    'withMetadata': data.length,
  };
  @override
  Stream<List<PauloFlixContent>> watch() => const Stream.empty();
}

/// Contador de chamadas ao `getProgressStatsForContents`.
/// Permite ao test verificar que o refresh foi disparado.
class _CallCounter {
  int calls = 0;
}

/// Fake do `PauloFlixEpisodeProgressRepository` que retorna stats
/// diferentes dependendo de quantas vezes foi consultado globalmente
/// (via `_CallCounter.calls`, que persiste entre remontagens).
///
/// - 1a consulta -> `_initialStats` (sem progresso)
/// - 2a consulta em diante -> `_updatedStats` (com progresso, simulando
///   que o player salvou antes de voltar)
class _FakeProgressRepository implements PauloFlixEpisodeProgressRepository {
  final Map<int, PauloFlixProgressStats> _initialStats;
  final Map<int, PauloFlixProgressStats> _updatedStats;
  final _CallCounter counter;

  _FakeProgressRepository({
    required Map<int, PauloFlixProgressStats> initialStats,
    required Map<int, PauloFlixProgressStats> updatedStats,
    required this.counter,
  }) : _initialStats = Map.of(initialStats),
       _updatedStats = Map.of(updatedStats);

  @override
  Future<Map<int, PauloFlixProgressStats>> getProgressStatsForContents(
    List<int> contentIds,
  ) async {
    counter.calls++;
    if (counter.calls >= 2) return Map.of(_updatedStats);
    return Map.of(_initialStats);
  }

  @override
  Future<PauloFlixProgressStats> getStatsForContent(int contentId) async =>
      _initialStats[contentId] ??
      const PauloFlixProgressStats(
        totalEpisodes: 0,
        completedEpisodes: 0,
        inProgressEpisodes: 0,
      );

  @override
  Future<List<PauloFlixContent>> getInProgressContents({
    int limit = 12,
  }) async => const [];

  @override
  Stream<List<PauloFlixContent>> watchInProgressContents({int limit = 12}) =>
      const Stream.empty();

  @override
  Future<PauloFlixEpisodeRecord?> getLatestInProgressEpisodeForContent(
    int contentId,
  ) async => null;

  @override
  Future<List<PauloFlixSeasonRecord>> getSeasonsForContent(
    int contentId,
  ) async => [];

  @override
  Stream<List<PauloFlixSeasonRecord>> watchSeasonsForContent(int contentId) =>
      const Stream.empty();

  @override
  Future<List<PauloFlixEpisodeRecord>> getEpisodesForSeason(
    int seasonId,
  ) async => [];

  @override
  Stream<List<PauloFlixEpisodeRecord>> watchEpisodesForSeason(int seasonId) =>
      const Stream.empty();

  @override
  Future<void> updateProgress({
    required int seasonId,
    required int episodeNumber,
    required int positionSeconds,
    int? durationSeconds,
  }) async {}

  @override
  Future<void> resetProgress({
    required int seasonId,
    required int episodeNumber,
  }) async {}

  @override
  Future<int> upsertSeason({
    required int contentId,
    required int seasonNumber,
    required String displayName,
    required String folderName,
    String? seasonDescription,
    String? posterFileName,
    String? fanartFileName,
  }) async => 0;

  @override
  Future<void> upsertEpisode({
    required int seasonId,
    required int episodeNumber,
    required String title,
    required String videoUrl,
    String? thumbnailUrl,
    String? description,
    int? contentId,
    int? seasonNumber,
    String? originalTitle,
    String? outline,
    DateTime? aired,
    double? rating,
    int? runtime,
  }) async {}

  @override
  Future<void> updateSeasonCount(int seasonId, int count) async {}

  @override
  Future<List<int>> removeMissingSeasons({
    required int contentId,
    required Set<int> scrapedSeasonNumbers,
  }) async => [];

  @override
  Future<List<int>> removeMissingEpisodes({
    required int seasonId,
    required Set<int> scrapedEpisodeNumbers,
  }) async => [];

  @override
  Future<Set<int>> getSeasonNumbersForContent(int contentId) async => {};

  @override
  Future<Set<int>> getEpisodeNumbersForSeason(int seasonId) async => {};

  @override
  Future<PauloFlixEpisodeRecord?> getNextEpisode({
    required int seasonId,
    required int episodeNumber,
  }) async => null;
}

// ═══════════════════════════════════════════════════════════════════════
// Fixtures
// ═══════════════════════════════════════════════════════════════════════

PauloFlixContent _anime({
  required int id,
  required String folderName,
  required String displayName,
}) {
  return PauloFlixContent(
    id: id,
    folderName: folderName,
    displayName: displayName,
    serverUrl: 'http://server/$folderName/',
    genres: const ['Action', 'Adventure'],
    score: 8.5,
  );
}

/// Cria um widget de teste com providers mockados e GoRouter.
///
/// [initialStats] - stats retornados na 1a consulta.
/// [updatedStats] - stats retornados apos o refresh (pos-player).
/// [counter] - contador de chamadas ao repo.
Widget _buildTestApp({
  required List<PauloFlixContent> testAnimes,
  required Map<int, PauloFlixProgressStats> initialStats,
  required Map<int, PauloFlixProgressStats> updatedStats,
  required _CallCounter counter,
}) {
  final contentRepo = _FakeContentRepository(testAnimes);
  final progressRepo = _FakeProgressRepository(
    initialStats: initialStats,
    updatedStats: updatedStats,
    counter: counter,
  );

  final provider = PauloFlixProvider.withRepository(repository: contentRepo);

  final router = GoRouter(
    initialLocation: '/pauloflix-see-all',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/pauloflix-see-all',
            name: 'pauloflix-see-all',
            builder: (context, state) => MultiProvider(
              providers: [
                ChangeNotifierProvider<PauloFlixProvider>.value(
                  value: provider,
                ),
                Provider<PauloFlixEpisodeProgressRepository>.value(
                  value: progressRepo,
                ),
              ],
              child: const PauloFlixSeeAllScreen(),
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

// ═══════════════════════════════════════════════════════════════════════
// Fixtures: animes de teste
// ═══════════════════════════════════════════════════════════════════════

final _singleAnime = [
  _anime(id: 1, folderName: 'Naruto', displayName: 'Naruto'),
];

final _multipleAnimes = [
  _anime(id: 1, folderName: 'Naruto', displayName: 'Naruto'),
  _anime(id: 2, folderName: 'Bleach', displayName: 'Bleach'),
  _anime(id: 3, folderName: 'OnePiece', displayName: 'One Piece'),
];

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

/// Faz os pumps para processar a carga inicial da SeeAllScreen.
Future<void> pumpUntilReady(
  WidgetTester tester, {
  required List<PauloFlixContent> testAnimes,
  required Map<int, PauloFlixProgressStats> initialStats,
  required Map<int, PauloFlixProgressStats> updatedStats,
  required _CallCounter counter,
}) async {
  await tester.pumpWidget(
    _buildTestApp(
      testAnimes: testAnimes,
      initialStats: initialStats,
      updatedStats: updatedStats,
      counter: counter,
    ),
  );
  await tester.pump(); // Pump 1: build + initState
  await tester.pump(); // Pump 2: postFrameCallback -> loadContents()
  await tester.pump(); // Pump 3: loadContents completa -> rebuild
  await tester.pump(); // Pump 4: _ensureSnapshotBuilt
  await tester.pump(); // Pump 5: _loadAllStats -> getProgressStatsForContents
}

/// Simula o retorno do player recriando o app (mesmo padrao do
/// see_all_screen_refresh_test original).
Future<void> pumpAfterReturn(
  WidgetTester tester, {
  required List<PauloFlixContent> testAnimes,
  required Map<int, PauloFlixProgressStats> initialStats,
  required Map<int, PauloFlixProgressStats> updatedStats,
  required _CallCounter counter,
}) async {
  await tester.pumpWidget(
    _buildTestApp(
      testAnimes: testAnimes,
      initialStats: initialStats,
      updatedStats: updatedStats,
      counter: counter,
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

// ═══════════════════════════════════════════════════════════════════════
// Tests - Grupo 1: Refresh basico (1 anime, progresso parcial)
// ═══════════════════════════════════════════════════════════════════════

void main() {
  group('PauloFlixSeeAllScreen -- refresh ao voltar do player', () {
    late Map<int, PauloFlixProgressStats> initialStats;
    late Map<int, PauloFlixProgressStats> updatedStats;
    late _CallCounter counter;

    setUp(() {
      initialStats = {
        1: const PauloFlixProgressStats(
          totalEpisodes: 12, completedEpisodes: 0, inProgressEpisodes: 0,
        ),
      };
      updatedStats = {
        1: const PauloFlixProgressStats(
          totalEpisodes: 12, completedEpisodes: 3, inProgressEpisodes: 1,
        ),
      };
      counter = _CallCounter();
    });

    testWidgets('inicialmente sem overlay de progresso (stats vazios)', (
      tester,
    ) async {
      await pumpUntilReady(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );

      expect(find.text('Naruto'), findsNWidgets(2));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('getProgressStatsForContents e chamado 1x na carga inicial', (
      tester,
    ) async {
      await pumpUntilReady(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );
      expect(counter.calls, equals(1));
    });

    testWidgets('apos voltar do player com progresso parcial: '
        'barra aparece com "3/12"', (tester) async {
      await pumpUntilReady(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await pumpAfterReturn(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );

      expect(find.byType(LinearProgressIndicator), findsAtLeastNWidgets(1));
      expect(find.text('3/12'), findsOneWidget);
    });

    testWidgets('se stats nao mudarem, o overlay nao aparece (ratio=0)', (
      tester,
    ) async {
      await pumpUntilReady(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );

      await pumpAfterReturn(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: initialStats,
        counter: counter,
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('getProgressStatsForContents e chamado novamente apos rebuild',
        (tester) async {
      await pumpUntilReady(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );
      expect(counter.calls, equals(1));

      await pumpAfterReturn(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );
      expect(counter.calls, equals(2));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Tests - Grupo 2: Completed badge (anime 100% completo)
  // ═══════════════════════════════════════════════════════════════════

  group('PauloFlixSeeAllScreen -- completed badge', () {
    late Map<int, PauloFlixProgressStats> initialStats;
    late Map<int, PauloFlixProgressStats> updatedStats;
    late _CallCounter counter;

    setUp(() {
      initialStats = {
        1: const PauloFlixProgressStats(
          totalEpisodes: 12, completedEpisodes: 0, inProgressEpisodes: 0,
        ),
      };
      // Anime 100% completo (12/12)
      updatedStats = {
        1: const PauloFlixProgressStats(
          totalEpisodes: 12, completedEpisodes: 12, inProgressEpisodes: 0,
        ),
      };
      counter = _CallCounter();
    });

    testWidgets('apos voltar do player com anime completo: '
        'badge verde + texto "Completo"', (tester) async {
      await pumpUntilReady(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );

      // Inicialmente sem "Completo"
      expect(find.text('Completo'), findsNothing);

      await pumpAfterReturn(
        tester,
        testAnimes: _singleAnime,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );

      // Deve mostrar "Completo" (CompletedBadge)
      expect(find.text('Completo'), findsAtLeastNWidgets(1));
      // Barra de progresso NAO deve aparecer (substituida pelo badge)
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Tests - Grupo 3: Multiplos animes com diferentes progressos
  // ═══════════════════════════════════════════════════════════════════

  group('PauloFlixSeeAllScreen -- multiplos animes', () {
    late Map<int, PauloFlixProgressStats> initialStats;
    late Map<int, PauloFlixProgressStats> updatedStats;
    late _CallCounter counter;

    setUp(() {
      // Inicialmente: todos sem progresso
      initialStats = {
        1: const PauloFlixProgressStats(
          totalEpisodes: 12, completedEpisodes: 0, inProgressEpisodes: 0,
        ),
        2: const PauloFlixProgressStats(
          totalEpisodes: 8, completedEpisodes: 0, inProgressEpisodes: 0,
        ),
        3: const PauloFlixProgressStats(
          totalEpisodes: 24, completedEpisodes: 0, inProgressEpisodes: 0,
        ),
      };
      // Apos jogar no player:
      // - Anime 1: parcial (3/12)
      // - Anime 2: completo (8/8)
      // - Anime 3: sem mudanca (0/24)
      updatedStats = {
        1: const PauloFlixProgressStats(
          totalEpisodes: 12, completedEpisodes: 3, inProgressEpisodes: 1,
        ),
        2: const PauloFlixProgressStats(
          totalEpisodes: 8, completedEpisodes: 8, inProgressEpisodes: 0,
        ),
        3: const PauloFlixProgressStats(
          totalEpisodes: 24, completedEpisodes: 0, inProgressEpisodes: 0,
        ),
      };
      counter = _CallCounter();
    });

    testWidgets('cada anime exibe o overlay correto: '
        'parcial (3/12), completo, e sem progresso', (tester) async {
      await pumpUntilReady(
        tester,
        testAnimes: _multipleAnimes,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );

      // Inicialmente sem overlays
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Completo'), findsNothing);

      await pumpAfterReturn(
        tester,
        testAnimes: _multipleAnimes,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );

      // Anime 1 (parcial): barra de progresso + "3/12"
      expect(find.byType(LinearProgressIndicator), findsAtLeastNWidgets(1));
      expect(find.text('3/12'), findsOneWidget);

      // Anime 2 (completo): badge "Completo"
      expect(find.text('Completo'), findsAtLeastNWidgets(1));

      // Todos os titulos estao presentes
      expect(find.text('Naruto'), findsWidgets);
      expect(find.text('Bleach'), findsWidgets);
      expect(find.text('One Piece'), findsWidgets);
    });

    testWidgets('getProgressStatsForContents e chamado com todos os '
        '3 contentIds no refresh', (tester) async {
      await pumpUntilReady(
        tester,
        testAnimes: _multipleAnimes,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );
      expect(counter.calls, equals(1));

      await pumpAfterReturn(
        tester,
        testAnimes: _multipleAnimes,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      );
      expect(counter.calls, equals(2));
    });
  });
}
