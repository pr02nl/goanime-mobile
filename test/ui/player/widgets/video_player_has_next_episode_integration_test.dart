/// Teste de integracao: fluxo completo _hasNextEpisode -> onNextEpisode.
///
/// Usa `AppDatabase` real (SQLite em memoria) + `_MockPlatformPlayer` para
/// o Player media_kit - sem depender de libs nativas.
///
/// Cenarios:
/// 1. PauloFlix com proximo EP -> botao "Proximo episodio" aparece
/// 2. PauloFlix no ultimo EP -> botao NAO aparece
/// 3. Filme/AnimeFire (sem seasonId/repo) -> botao nunca aparece
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/data/services/auth/jwt_token_manager.dart';
import 'package:goanime/domain/models/episode.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:goanime/ui/player/widgets/video_player_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

// ═══════════════════════════════════════════════════════════════════
// Mock PlatformPlayer - permite criar Player sem libs nativas
//
// Diferente dos mocks em outros testes (que testam apenas os
// controles), este mock precisa emitir tracks de video no open()
// para evitar que _initializeVideoPlayer() espere 15s de timeout.
// ═══════════════════════════════════════════════════════════════════

class _MockPlatformPlayer extends PlatformPlayer {
  _MockPlatformPlayer() : super(configuration: const PlayerConfiguration());

  bool _playing = false;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    _playing = play;
    playingController.add(_playing);
    state = state.copyWith(playing: _playing);
    // Emite tracks para desbloquear as awaits em _initializeVideoPlayer:
    // 1. _waitForEmbeddedSubtitleTracks (aguarda tracksController emitir)
    // 2. .firstWhere((t) => t.video.isNotEmpty) (aguarda video nao vazio)
    // Sem isso, cada teste esperaria ~15s ate o timeout.
    tracksController.add(const Tracks(video: [VideoTrack('0', null, null)]));
  }

  @override
  Future<void> play() async {
    _playing = true;
    playingController.add(true);
    state = state.copyWith(playing: true);
  }

  @override
  Future<void> pause() async {
    _playing = false;
    playingController.add(false);
    state = state.copyWith(playing: false);
  }

  @override
  Future<void> playOrPause() async {
    if (_playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> stop() async {
    _playing = false;
    positionController.add(Duration.zero);
    playingController.add(false);
    state = state.copyWith(playing: false, position: Duration.zero);
  }

  @override
  Future<void> seek(Duration duration) async {
    positionController.add(duration);
    state = state.copyWith(position: duration);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setShuffle(bool shuffle) async {}

  @override
  Future<void> setPlaylistMode(PlaylistMode playlistMode) async {}

  @override
  Future<void> add(Media media, {int? index}) async {}

  @override
  Future<void> remove(int index) async {}

  @override
  Future<void> move(int from, int to) async {}

  @override
  Future<void> next({bool autoplay = true}) async {
    _playing = autoplay;
    playingController.add(autoplay);
    state = state.copyWith(playing: autoplay);
  }

  @override
  Future<void> previous({bool autoplay = true}) async {}

  @override
  Future<void> jump(int index, {bool autoplay = true}) async {}

  @override
  Future<void> setVideoTrack(VideoTrack track) async {}

  @override
  Future<void> setAudioTrack(AudioTrack track) async {}

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {}

  @override
  Future<void> setAudioDevice(AudioDevice audioDevice) async {}

  @override
  Future<Uint8List?> screenshot({
    String? format,
    bool includeLibassSubtitles = true,
  }) async => null;

  @override
  Future<int> get handle async => 0;

  @override
  Future<void> dispose() async {
    await playingController.close();
    await positionController.close();
    await durationController.close();
    await bufferingController.close();
    await completedController.close();
    await errorController.close();
    await bufferController.close();
    await tracksController.close();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════
// Helpers de seed do banco
// ═══════════════════════════════════════════════════════════════════

/// Cria um content + season com [episodeCount] episodios.
/// Retorna (contentId, seasonId).
Future<(int, int)> seedSeason(
  AppDatabase db, {
  required int contentId,
  required int episodeCount,
  int seasonNumber = 1,
}) async {
  final seasonId = await db.into(db.pauloFlixSeasons).insert(
        PauloFlixSeasonsCompanion.insert(
          contentId: contentId,
          seasonNumber: seasonNumber,
          displayName: 'Season $seasonNumber',
          folderName: 'Season $seasonNumber',
          episodeCount: Value(episodeCount),
          lastSynced: DateTime.now(),
        ),
      );
  for (var i = 1; i <= episodeCount; i++) {
    await db.into(db.pauloFlixEpisodes).insert(
          PauloFlixEpisodesCompanion.insert(
            seasonId: seasonId,
            episodeNumber: i,
            title: 'ep $i',
            videoUrl: 'https://server/ep$i.mkv',
            contentId: Value(contentId),
            seasonNumber: Value(seasonNumber),
            lastSynced: DateTime.now(),
          ),
        );
  }
  return (contentId, seasonId);
}

Future<int> seedContent(AppDatabase db, {String name = 'Test'}) async {
  return db.into(db.pauloFlixContent).insert(
        PauloFlixContentCompanion.insert(
          folderName: name,
          displayName: name,
          serverUrl: 'https://server/$name/',
          lastSynced: DateTime.now(),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
// Helpers de construcao do widget tree
// ═══════════════════════════════════════════════════════════════════

/// Monta o widget tree completo: Provider + mock Player + ModernVideoPlayerScreen.
/// Usa Provider com tipo nullable para corresponder ao `context.read<T?>()`
/// usado no production code.
Widget _buildPlayerScreenApp({
  required PauloFlixEpisodeProgressRepository? repo,
  required Episode episode,
  required String animeTitle,
  required _MockPlatformPlayer mockPlatform,
  int? seasonId,
  String? episodeNumber,
  int? contentId,
  bool isMovie = false,
}) {
  return MaterialApp(
    home: Provider<PauloFlixEpisodeProgressRepository?>.value(
      value: repo,
      child: Provider<JwtTokenManager?>.value(
        value: null,
        child: ModernVideoPlayerScreen(
          episode: episode,
          animeTitle: animeTitle,
          contentId: contentId,
          seasonId: seasonId,
          episodeNumber: episodeNumber,
          isMovie: isMovie,
          platformPlayer: mockPlatform,
        ),
      ),
    ),
  );
}

/// Aguarda o postFrameCallback de initState ser processado
/// e a query _refreshNextEpisodeAvailability completar.
///
/// NOTA: O _initializeVideoPlayer tem timeouts internos:
/// - _waitForEmbeddedSubtitleTracks: Timer 2s
/// - firstWhere + timeout: 15s
/// Somados ≈ 17s. Como as tracks sao emitidas durante open() (antes dos
/// listeners serem anexados), ambos os timeouts precisam expirar.
/// Este helper usa 25s de runAsync para cobrir ambos com margem.
Future<void> _pumpUntilNextRefresh(WidgetTester tester) async {
  await tester.pump();
  // 25s de tempo real para os timeouts de 2s + 15s expirarem
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(seconds: 25)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ═══════════════════════════════════════════════════════════════════
// Testes
// ═══════════════════════════════════════════════════════════════════

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('ModernVideoPlayerScreen - _hasNextEpisode -> onNextEpisode', () {
    // Cada teste leva ~25s de runAsync. Timeout generoso de 60s.
    const testTimeout = Timeout(Duration(seconds: 60));

    late AppDatabase db;
    late PauloFlixEpisodeProgressRepository repo;
    late _MockPlatformPlayer mockPlatform;
    late Episode testEpisode;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = PauloFlixEpisodeProgressRepositoryImpl(db);
      mockPlatform = _MockPlatformPlayer();
      testEpisode = Episode(
        number: '1',
        url: 'https://server/ep1.mkv',
        title: 'ep 1',
      );
    });

    tearDown(() async {
      await mockPlatform.dispose();
      await db.close();
    });

    testWidgets(
      'PauloFlix com proximo EP: botao aparece (ep1 -> ep2)',
      (tester) async {
        final contentId = await seedContent(db);
        final (_, seasonId) = await seedSeason(
          db,
          contentId: contentId,
          episodeCount: 2,
          seasonNumber: 1,
        );

        await tester.pumpWidget(
          _buildPlayerScreenApp(
            repo: repo,
            episode: testEpisode,
            animeTitle: 'Naruto',
            mockPlatform: mockPlatform,
            seasonId: seasonId,
            episodeNumber: '1',
            contentId: contentId,
          ),
        );

        await _pumpUntilNextRefresh(tester);

        expect(
          find.byIcon(Icons.skip_next_rounded),
          findsOneWidget,
          reason:
              'Botao proximo deve aparecer quando ha proximo EP no banco (ep1 -> ep2)',
        );
      },
      timeout: testTimeout,
    );

    testWidgets(
      'PauloFlix no ultimo EP: botao NAO aparece',
      (tester) async {
        final contentId = await seedContent(db);
        final (_, seasonId) = await seedSeason(
          db,
          contentId: contentId,
          episodeCount: 1,
          seasonNumber: 1,
        );

        await tester.pumpWidget(
          _buildPlayerScreenApp(
            repo: repo,
            episode: testEpisode,
            animeTitle: 'Naruto',
            mockPlatform: mockPlatform,
            seasonId: seasonId,
            episodeNumber: '1',
            contentId: contentId,
          ),
        );

        await _pumpUntilNextRefresh(tester);

        expect(
          find.byIcon(Icons.skip_next_rounded),
          findsNothing,
          reason:
              'Botao proximo NAO deve aparecer quando nao ha proximo EP (ultimo da serie)',
        );
      },
      timeout: testTimeout,
    );

    testWidgets(
      'Cross-season (S01 ultimo -> S02): botao aparece',
      (tester) async {
        final contentId = await seedContent(db);

        final s1 = (await seedSeason(
          db,
          contentId: contentId,
          episodeCount: 1,
          seasonNumber: 1,
        ))
            .$2;

        await seedSeason(
          db,
          contentId: contentId,
          episodeCount: 1,
          seasonNumber: 2,
        );

        await tester.pumpWidget(
          _buildPlayerScreenApp(
            repo: repo,
            episode: testEpisode,
            animeTitle: 'Naruto',
            mockPlatform: mockPlatform,
            seasonId: s1,
            episodeNumber: '1',
            contentId: contentId,
          ),
        );

        await _pumpUntilNextRefresh(tester);

        expect(
          find.byIcon(Icons.skip_next_rounded),
          findsOneWidget,
          reason:
              'Botao proximo deve aparecer quando ha cross-season (S01 -> S02)',
        );
      },
      timeout: testTimeout,
    );

    testWidgets(
      'Filme (isMovie=true, sem seasonId): botao nunca aparece',
      (tester) async {
        final contentId = await seedContent(db);
        await seedSeason(
          db,
          contentId: contentId,
          episodeCount: 1,
        );

        await tester.pumpWidget(
          _buildPlayerScreenApp(
            repo: repo,
            episode: testEpisode,
            animeTitle: 'Meu Filme',
            mockPlatform: mockPlatform,
            contentId: contentId,
            isMovie: true,
          ),
        );

        await _pumpUntilNextRefresh(tester);

        expect(
          find.byIcon(Icons.skip_next_rounded),
          findsNothing,
          reason:
              'Botao proximo nunca deve aparecer para filmes (isMovie=true)',
        );
      },
      timeout: testTimeout,
    );

    testWidgets(
      'AnimeFire (sem seasonId): botao nunca aparece',
      (tester) async {
        await seedContent(db);

        await tester.pumpWidget(
          _buildPlayerScreenApp(
            repo: repo,
            episode: testEpisode,
            animeTitle: 'Anime Qualquer',
            mockPlatform: mockPlatform,
          ),
        );

        await _pumpUntilNextRefresh(tester);

        expect(
          find.byIcon(Icons.skip_next_rounded),
          findsNothing,
          reason:
              'Botao proximo nunca deve aparecer para fluxos nao-PauloFlix',
        );
      },
      timeout: testTimeout,
    );

    testWidgets(
      'Repo null no Provider: botao nunca aparece (fallback seguro)',
      (tester) async {
        await tester.pumpWidget(
          _buildPlayerScreenApp(
            repo: null,
            episode: testEpisode,
            animeTitle: 'Naruto',
            mockPlatform: mockPlatform,
            seasonId: 1,
            episodeNumber: '1',
            contentId: 1,
          ),
        );

        await _pumpUntilNextRefresh(tester);

        expect(
          find.byIcon(Icons.skip_next_rounded),
          findsNothing,
          reason:
              'Com repo=null no Provider, botao nao deve aparecer (fallback seguro)',
        );
      },
      timeout: testTimeout,
    );
  });
}
