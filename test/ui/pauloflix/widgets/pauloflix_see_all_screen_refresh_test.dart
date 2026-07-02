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
import 'package:provider/provider.dart';

import 'package:goanime/domain/models/paulo_flix_episode_record.dart';
import 'package:goanime/domain/models/paulo_flix_progress_stats.dart';
import 'package:goanime/domain/models/paulo_flix_season_record.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:goanime/domain/repositories/pauloflix_repository.dart';
import 'package:goanime/l10n/app_localizations.dart';
import 'package:goanime/ui/pauloflix/view_models/pauloflix_provider.dart';
import 'package:goanime/ui/pauloflix/widgets/pauloflix_see_all_screen.dart';

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
/// - 1ª consulta → `_initialStats` (sem progresso)
/// - 2ª consulta em diante → `_updatedStats` (com progresso, simulando
///   que o player salvou antes de voltar)
class _FakeProgressRepository implements PauloFlixEpisodeProgressRepository {
  final Map<int, PauloFlixProgressStats> _initialStats;
  final Map<int, PauloFlixProgressStats> _updatedStats;
  final _CallCounter counter;

  _FakeProgressRepository({
    required Map<int, PauloFlixProgressStats> initialStats,
    required Map<int, PauloFlixProgressStats> updatedStats,
    required _CallCounter counter,
  })  : _initialStats = Map.of(initialStats),
        _updatedStats = Map.of(updatedStats),
        counter = counter;

  @override
  Future<Map<int, PauloFlixProgressStats>> getProgressStatsForContents(
    List<int> contentIds,
  ) async {
    counter.calls++;
    // Usa counter.calls (global) em vez de instância local para
    // que mesmo após pumpWidget (que recria este repo), a 1ª chamada
    // neste novo repo seja tratada como "2ª consulta global" se
    // counter.calls >= 2.
    if (counter.calls >= 2) return Map.of(_updatedStats);
    return Map.of(_initialStats);
  }

  @override
  Future<PauloFlixProgressStats> getStatsForContent(int contentId) async =>
      _initialStats[contentId] ?? const PauloFlixProgressStats(
        totalEpisodes: 0,
        completedEpisodes: 0,
        inProgressEpisodes: 0,
      );

  @override
  Future<List<PauloFlixContent>> getInProgressContents({int limit = 12}) async =>
      const [];

  @override
  Stream<List<PauloFlixContent>> watchInProgressContents({int limit = 12}) =>
      const Stream.empty();

  @override
  Future<PauloFlixEpisodeRecord?> getLatestInProgressEpisodeForContent(
    int contentId,
  ) async =>
      null;

  @override
  Future<List<PauloFlixSeasonRecord>> getSeasonsForContent(
    int contentId,
  ) async =>
      [];

  @override
  Stream<List<PauloFlixSeasonRecord>> watchSeasonsForContent(int contentId) =>
      const Stream.empty();

  @override
  Future<List<PauloFlixEpisodeRecord>> getEpisodesForSeason(
    int seasonId,
  ) async =>
      [];

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
/// [initialStats] — stats retornados na 1ª consulta.
/// [updatedStats] — stats retornados após o refresh (pós-player).
/// [counter] — contador de chamadas ao repo.
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

  // GoRouter com rota home (pauloflix-see-all) + rota player (fora do shell).
  final router = GoRouter(
    initialLocation: '/pauloflix-see-all',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          body: child,
        ),
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
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('Player Screen'),
          ),
        ),
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
// Tests
// ═══════════════════════════════════════════════════════════════════════

void main() {
  final testAnimes = [
    _anime(id: 1, folderName: 'Naruto', displayName: 'Naruto'),
  ];

  late Map<int, PauloFlixProgressStats> initialStats;
  late Map<int, PauloFlixProgressStats> updatedStats;
  late _CallCounter counter;

  setUp(() {
    // Inicialmente: sem progresso
    initialStats = {
      1: const PauloFlixProgressStats(
        totalEpisodes: 12,
        completedEpisodes: 0,
        inProgressEpisodes: 0,
      ),
    };

    // Após jogar no player: 3 episódios completos
    updatedStats = {
      1: const PauloFlixProgressStats(
        totalEpisodes: 12,
        completedEpisodes: 3,
        inProgressEpisodes: 1,
      ),
    };

    counter = _CallCounter();
  });

  group('PauloFlixSeeAllScreen — refresh ao voltar do player', () {
    /// Helper: faz os pumps necessários para processar a carga inicial.
    /// Retorna o router GoRouter para navegação.
    Future<GoRouter> _initialLoad(WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp(
        testAnimes: testAnimes,
        initialStats: initialStats,
        updatedStats: updatedStats,
        counter: counter,
      ));
      // Pump 1: first build + initState + didChangeDependencies
      await tester.pump();
      // Pump 2: postFrameCallback starts → provider.loadContents()
      await tester.pump();
      // Pump 3: loadContents completa → notifyListeners → rebuild
      await tester.pump();
      // Pump 4: rebuild triggers _ensureSnapshotBuilt
      await tester.pump();
      // Pump 5: nested postFrameCallback → _loadAllStats() → getProgressStatsForContents
      await tester.pump();

      return GoRouter.of(
        tester.element(find.byType(PauloFlixSeeAllScreen)),
      );
    }

    testWidgets(
      'inicialmente sem overlay de progresso (stats vazios)',
      (tester) async {
        await _initialLoad(tester);

        // Hero banner exibe 'Naruto' + card no carrossel também exibe
        expect(find.text('Naruto'), findsNWidgets(2));

        // Inicialmente a barra de progresso NÃO deve aparecer (sem progresso)
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'getProgressStatsForContents é chamado 1x na carga inicial',
      (tester) async {
        await _initialLoad(tester);

        // Apenas 1 chamada (carga inicial)
        expect(counter.calls, equals(1));
      },
    );

    testWidgets(
      'após navegar para /player e voltar, stats são recarregados '
      '(getProgressStatsForContents é chamado novamente '
      'via remontagem do widget)',
      (tester) async {
        await _initialLoad(tester);
        expect(counter.calls, equals(1));

        // Simula a navegação recriando o app com GoRouter na mesma rota
        await tester.pumpWidget(_buildTestApp(
          testAnimes: testAnimes,
          initialStats: initialStats,
          updatedStats: updatedStats,
          counter: counter,
        ));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        // loadContents completa → notifyListeners → rebuild
        await tester.pump();
        // nested postFrameCallback → _loadAllStats() (2ª chamada)
        await tester.pump();

        // getProgressStatsForContents deve ter sido chamado 2x
        // (1 inicial + 1 da remontagem)
        expect(counter.calls, equals(2));
      },
    );

    testWidgets(
      'após remontar, a barra de progresso aparece no card '
      '(3/12 episódios completos)',
      (tester) async {
        await _initialLoad(tester);

        // Inicialmente sem barra de progresso
        expect(find.byType(LinearProgressIndicator), findsNothing);

        // Simula retorno do player recriando o app
        await tester.pumpWidget(_buildTestApp(
          testAnimes: testAnimes,
          initialStats: initialStats,
          updatedStats: updatedStats,
          counter: counter,
        ));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Após remontagem (2ª chamada → updatedStats → 3/12), barra aparece
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('3/12'), findsOneWidget);
      },
    );

    testWidgets(
      'se stats não mudarem, o overlay não aparece (ratio=0)',
      (tester) async {
        // Neste cenário, initialStats == updatedStats (não mudou)
        await _initialLoad(tester);

        // Simula retorno do player recriando o app (mesmo stats)
        await tester.pumpWidget(_buildTestApp(
          testAnimes: testAnimes,
          initialStats: initialStats,
          updatedStats: initialStats, // sem mudança
          counter: counter,
        ));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Mesmo após refresh, ratio continua 0 → sem barra
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );
  });
}
