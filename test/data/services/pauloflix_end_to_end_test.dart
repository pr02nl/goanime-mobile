// Teste end-to-end do fluxo completo:
//   sync JSON index → abrir tela de episódios → abrir player →
//   salvar progresso → reabrir e retomar de onde parou
//
// Estratégia: HTTP mockado + Drift em memória.
// Testa a camada de DADOS (não o player media_kit que é plataforma-dependente).

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/core/database/app_database.dart';
import 'package:goanime/data/repositories/paulo_flix_episode_progress_repository_impl.dart';
import 'package:goanime/data/repositories/pauloflix_repository_impl.dart';
import 'package:goanime/data/services/episode_progress_service.dart';
import 'package:goanime/data/services/pauloflix_service.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// JSON index com 1 show, 1 season, 2 episódios.
const _tvIndexJson = '''{
  "total_shows": 1,
  "shows": [
    {
      "title": "Naruto",
      "path": "Naruto",
      "poster": "/tvshows/Naruto/poster.jpg",
      "fanart": "/tvshows/Naruto/fanart.jpg",
      "seasons": [
        {
          "season": 1,
          "folderName": "Season 01",
          "episodes": [
            {
              "episode": 1,
              "title": "Entrada: Naruto Uzumaki!",
              "file": "/tvshows/Naruto/Season%2001/S01E01.mkv",
              "thumb": "/tvshows/Naruto/Season%2001/S01E01-thumb.jpg",
              "nfo": {}
            },
            {
              "episode": 2,
              "title": "Meu nome é Konohamaru!",
              "file": "/tvshows/Naruto/Season%2001/S01E02.mkv",
              "nfo": {}
            }
          ]
        }
      ]
    }
  ]
}''';

const _baseHost = 'https://media.oliveira.braga.nom.br';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late PauloFlixRepositoryImpl repo;
  late PauloFlixEpisodeProgressRepository episodeRepo;
  late int contentId;
  late int seasonId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    repo = PauloFlixRepositoryImpl(db);
    episodeRepo = PauloFlixEpisodeProgressRepositoryImpl(db);
  });

  tearDown(() async {
    PauloFlixService.configure(http.Client());
  });

  /// Helper: executa o sync e retorna o contentId + seasonId.
  Future<void> runSync() async {
    final mockClient = MockClient((request) async {
      return http.Response(
        _tvIndexJson,
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    PauloFlixService.configure(mockClient);

    final result = await PauloFlixService.syncContent(
      repository: repo,
      episodeRepository: episodeRepo,
    );
    expect(result, isTrue, reason: 'sync deve ser bem-sucedido');

    // Obtém o contentId do show sincronizado
    final all = await repo.getAll();
    expect(all, hasLength(1));
    contentId = all.first.id!;

    // Obtém o seasonId
    final seasons = await episodeRepo.getSeasonsForContent(contentId);
    expect(seasons, hasLength(1));
    seasonId = seasons.first.id!;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Fluxo completo
  // ═══════════════════════════════════════════════════════════════════════

  test('Fluxo completo: sync → ler progresso → salvar → reabrir → retomar',
      () async {
    // ─── PASSO 1: Sync JSON index ──────────────────────────────────────
    await runSync();

    // Verifica que o show foi salvo
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.first.displayName, 'Naruto');

    // Verifica que a season foi salva
    final seasons = await episodeRepo.getSeasonsForContent(contentId);
    expect(seasons, hasLength(1));
    expect(seasons.first.seasonNumber, 1);

    // Verifica que os episódios foram salvos
    final episodes = await episodeRepo.getEpisodesForSeason(seasonId);
    expect(episodes, hasLength(2));
    expect(episodes[0].episodeNumber, 1);
    expect(episodes[0].title, 'Entrada: Naruto Uzumaki!');
    expect(episodes[0].videoUrl,
        '$_baseHost/tvshows/Naruto/Season%2001/S01E01.mkv');
    expect(episodes[0].positionSeconds, 0); // nunca assistido
    expect(episodes[0].isCompleted, false);
    expect(episodes[1].episodeNumber, 2);

    // ─── PASSO 2: Abrir player (ler progresso salvo) ───────────────────
    // Simula o que o player faz em _loadSavedProgress()
    final ep1Record = episodes.firstWhere((e) => e.episodeNumber == 1);
    expect(ep1Record.positionSeconds, 0, reason: 'progresso inicial = 0');
    expect(ep1Record.isCompleted, false);

    // Simula a decisão de reset/retomar (primeira vez = sem progresso)
    final service = EpisodeProgressService(
      repo: episodeRepo,
      seasonId: seasonId,
      episodeNumber: 1,
    );

    // Primeira abertura: sem progresso salvo → ratio 0/1440 < 0.1
    // → reseta (idempotente: já está em 0, sem side effect)
    final shouldReset1 = await service.prepareResumeOrReset(
      isCompleted: false,
      positionSeconds: 0,
      durationSeconds: 1440,
    );
    expect(shouldReset1, isTrue,
        reason: 'ratio 0/1440 = 0 < 0.1 → reseta (já está em 0)');

    // ─── PASSO 3: Salvar progresso durante playback ────────────────────
    // Simula o timer de 5s do EpisodeProgressService._save()
    // O usuário assistiu até 300s (5 min de 24 min)
    await episodeRepo.updateProgress(
      seasonId: seasonId,
      episodeNumber: 1,
      positionSeconds: 300,
      durationSeconds: 1440,
    );

    // Verifica que o progresso foi salvo
    var updatedEps = await episodeRepo.getEpisodesForSeason(seasonId);
    var updatedEp1 = updatedEps.firstWhere((e) => e.episodeNumber == 1);
    expect(updatedEp1.positionSeconds, 300);
    expect(updatedEp1.isCompleted, false,
        reason: '300/1440 ≈ 21% → não completou');

    // ─── PASSO 4: Reabrir e retomar ────────────────────────────────────
    // Simula o que o player faz na segunda abertura
    // Lê o progresso salvo (como _loadSavedProgress faz)
    final savedEps = await episodeRepo.getEpisodesForSeason(seasonId);
    final saved = savedEps.firstWhere((e) => e.episodeNumber == 1);

    expect(saved.positionSeconds, 300,
        reason: 'progresso recuperado do banco');
    expect(saved.durationSeconds, 1440);
    expect(saved.isCompleted, false);

    // Decide se deve resetar ou retomar
    // ratio = 300/1440 ≈ 0.21 → >= 0.1 → NÃO reseta → retoma
    final service2 = EpisodeProgressService(
      repo: episodeRepo,
      seasonId: seasonId,
      episodeNumber: 1,
    );
    final shouldReset2 = await service2.prepareResumeOrReset(
      isCompleted: saved.isCompleted,
      positionSeconds: saved.positionSeconds,
      durationSeconds: saved.durationSeconds!,
    );

    expect(shouldReset2, isFalse,
        reason: '21% ≥ 10% → deve retomar (não resetar)');
    // O player fará: if (!shouldReset2 && pos > 0) → player.seek(300s)
    // Isso é a retomada correta!

    // ─── PASSO 5: Assistir até o fim e reabrir ─────────────────────────
    // Usuário termina o episódio (90%+)
    await episodeRepo.updateProgress(
      seasonId: seasonId,
      episodeNumber: 1,
      positionSeconds: 1400,
      durationSeconds: 1440,
    );

    // Verifica que foi marcado como completo
    var finalEps = await episodeRepo.getEpisodesForSeason(seasonId);
    var finalEp1 = finalEps.firstWhere((e) => e.episodeNumber == 1);
    expect(finalEp1.isCompleted, true,
        reason: '1400/1440 ≈ 97% ≥ 90% → completou');

    // Season 1: só tem episódio 1 completo (ep 2 ainda não)
    var finalSeason = (await episodeRepo.getSeasonsForContent(contentId)).first;
    expect(finalSeason.isCompleted, false,
        reason: 'só 1/2 episódios completo → season não completa');

    // ─── PASSO 6: Reabrir episódio completo → reset (reassistir) ───────
    final service3 = EpisodeProgressService(
      repo: episodeRepo,
      seasonId: seasonId,
      episodeNumber: 1,
    );
    final shouldReset3 = await service3.prepareResumeOrReset(
      isCompleted: true,
      positionSeconds: 1400,
      durationSeconds: 1440,
    );

    expect(shouldReset3, isTrue,
        reason: 'isCompleted=true → deve resetar (reassistir)');

    // Verifica que o reset zerou o progresso
    var afterReset = await episodeRepo.getEpisodesForSeason(seasonId);
    var afterResetEp1 = afterReset.firstWhere((e) => e.episodeNumber == 1);
    expect(afterResetEp1.positionSeconds, 0,
        reason: 'reset zerou positionSeconds');
    expect(afterResetEp1.isCompleted, false,
        reason: 'reset zerou isCompleted');
  });

  test(
      'Fluxo: começar episódio e fechar rápido (<10%) → reabrir começa do zero',
      () async {
    await runSync();

    // Usuário abre, assiste 30s de um episódio de 24min (≈2%) e fecha
    await episodeRepo.updateProgress(
      seasonId: seasonId,
      episodeNumber: 1,
      positionSeconds: 30,
      durationSeconds: 1440,
    );

    // Reabre: ratio = 30/1440 ≈ 0.02 < 0.1 → reseta (começa do zero)
    final service = EpisodeProgressService(
      repo: episodeRepo,
      seasonId: seasonId,
      episodeNumber: 1,
    );
    final shouldReset = await service.prepareResumeOrReset(
      isCompleted: false,
      positionSeconds: 30,
      durationSeconds: 1440,
    );

    expect(shouldReset, isTrue,
        reason: '2% < 10% → deve resetar (começar do zero)');

    // Verifica que o progresso foi zerado
    final episodes = await episodeRepo.getEpisodesForSeason(seasonId);
    final ep1 = episodes.firstWhere((e) => e.episodeNumber == 1);
    expect(ep1.positionSeconds, 0, reason: 'reset zerou posição');
  });

  test('Fluxo: completar todos episódios → season fica completa', () async {
    await runSync();

    // Completa episódio 1
    await episodeRepo.updateProgress(
      seasonId: seasonId,
      episodeNumber: 1,
      positionSeconds: 1440,
      durationSeconds: 1440,
    );

    // Season ainda não completa (só 1/2)
    var season = (await episodeRepo.getSeasonsForContent(contentId)).first;
    expect(season.isCompleted, false);

    // Completa episódio 2
    await episodeRepo.updateProgress(
      seasonId: seasonId,
      episodeNumber: 2,
      positionSeconds: 1440,
      durationSeconds: 1440,
    );

    // Season completa (2/2)
    season = (await episodeRepo.getSeasonsForContent(contentId)).first;
    expect(season.isCompleted, true,
        reason: '2/2 episódios completos → season completa');

    // Reabre a season → todos os episódios estão completos
    final episodes = await episodeRepo.getEpisodesForSeason(seasonId);
    expect(episodes.every((e) => e.isCompleted), isTrue);
  });
}
