import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/paulo_flix_episode_record.dart';
import 'package:goanime/domain/models/paulo_flix_season_record.dart';

void main() {
  group('PauloFlixSeasonRecord', () {
    test('campos obrigatórios e defaults', () {
      final s = PauloFlixSeasonRecord(
        id: 1,
        contentId: 10,
        seasonNumber: 1,
        displayName: 'Season 01',
        folderName: 'Season 01',
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(s.id, 1);
      expect(s.contentId, 10);
      expect(s.seasonNumber, 1);
      expect(s.displayName, 'Season 01');
      expect(s.folderName, 'Season 01');
      expect(s.episodeCount, 0); // default
      expect(s.isCompleted, false); // default
      expect(s.lastSynced, DateTime(2026, 1, 1));
    });

    test('aceita episodeCount customizado', () {
      final s = PauloFlixSeasonRecord(
        id: 2,
        contentId: 10,
        seasonNumber: 1,
        displayName: 'S01',
        folderName: 'S01',
        episodeCount: 12,
        isCompleted: true,
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(s.episodeCount, 12);
      expect(s.isCompleted, true);
    });

    test('equality por (contentId, seasonNumber) — não por id', () {
      // Mesmo conteúdo, mesma season, ids diferentes (sync 1x vs sync 2x).
      // Devem ser consideradas iguais — chave de negócio é (content, season).
      final a = PauloFlixSeasonRecord(
        id: 1,
        contentId: 10,
        seasonNumber: 1,
        displayName: 'S01',
        folderName: 'S01',
        lastSynced: DateTime(2026, 1, 1),
      );
      final b = PauloFlixSeasonRecord(
        id: 999,
        contentId: 10,
        seasonNumber: 1,
        displayName: 'Season 01 - atualizada',
        folderName: 'Season 01 - atualizada',
        episodeCount: 24,
        isCompleted: true,
        lastSynced: DateTime(2026, 6, 22),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('seasons diferentes (mesmo content, seasonNumber diferente) são diferentes', () {
      final a = PauloFlixSeasonRecord(
        id: 1,
        contentId: 10,
        seasonNumber: 1,
        displayName: 'S01',
        folderName: 'S01',
        lastSynced: DateTime(2026, 1, 1),
      );
      final b = PauloFlixSeasonRecord(
        id: 2,
        contentId: 10,
        seasonNumber: 2,
        displayName: 'S02',
        folderName: 'S02',
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(a, isNot(equals(b)));
    });

    test('seasons diferentes (content diferente, mesmo seasonNumber) são diferentes', () {
      final a = PauloFlixSeasonRecord(
        id: 1,
        contentId: 10,
        seasonNumber: 1,
        displayName: 'S01',
        folderName: 'S01',
        lastSynced: DateTime(2026, 1, 1),
      );
      final b = PauloFlixSeasonRecord(
        id: 2,
        contentId: 20,
        seasonNumber: 1,
        displayName: 'S01',
        folderName: 'S01',
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('PauloFlixEpisodeRecord', () {
    test('campos obrigatórios e defaults (positionSeconds=0, isCompleted=false, lastWatched=null)', () {
      final e = PauloFlixEpisodeRecord(
        id: 1,
        seasonId: 10,
        episodeNumber: 1,
        title: 'ep 1',
        videoUrl: 'https://server/S01E01.mkv',
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(e.id, 1);
      expect(e.seasonId, 10);
      expect(e.episodeNumber, 1);
      expect(e.title, 'ep 1');
      expect(e.videoUrl, 'https://server/S01E01.mkv');
      expect(e.durationSeconds, isNull);
      expect(e.positionSeconds, 0); // default
      expect(e.isCompleted, false); // default
      expect(e.lastWatched, isNull); // default
      expect(e.lastSynced, DateTime(2026, 1, 1));
    });

    test('aceita campos de progresso customizados', () {
      final e = PauloFlixEpisodeRecord(
        id: 1,
        seasonId: 10,
        episodeNumber: 1,
        title: 'ep 1',
        videoUrl: 'https://server/S01E01.mkv',
        durationSeconds: 1440, // 24min
        positionSeconds: 720, // 12min
        isCompleted: false,
        lastWatched: DateTime(2026, 6, 22, 14, 30),
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(e.durationSeconds, 1440);
      expect(e.positionSeconds, 720);
      expect(e.isCompleted, false);
      expect(e.lastWatched, DateTime(2026, 6, 22, 14, 30));
    });

    test('progressRatio é 0.0 quando durationSeconds é null', () {
      // Edge case: primeira vez que o user abre o episode, duration ainda
      // não foi descoberta pelo player. Sem info, ratio = 0.0 (sem
      // progresso conhecido).
      final e = PauloFlixEpisodeRecord(
        id: 1,
        seasonId: 10,
        episodeNumber: 1,
        title: 'ep 1',
        videoUrl: 'https://server/S01E01.mkv',
        positionSeconds: 100,
        durationSeconds: null,
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(e.progressRatio, 0.0);
    });

    test('progressRatio é 0.0 quando durationSeconds = 0', () {
      // Divisão por zero: retorna 0.0 (evita NaN/Infinity).
      final e = PauloFlixEpisodeRecord(
        id: 1,
        seasonId: 10,
        episodeNumber: 1,
        title: 'ep 1',
        videoUrl: 'https://server/S01E01.mkv',
        positionSeconds: 0,
        durationSeconds: 0,
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(e.progressRatio, 0.0);
    });

    test('progressRatio é position/duration quando ambos conhecidos', () {
      final e = PauloFlixEpisodeRecord(
        id: 1,
        seasonId: 10,
        episodeNumber: 1,
        title: 'ep 1',
        videoUrl: 'https://server/S01E01.mkv',
        positionSeconds: 720,
        durationSeconds: 1440,
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(e.progressRatio, 0.5);
    });

    test('progressRatio é 1.0 quando position >= duration (defensivo)', () {
      // Edge case: clock drift, seek manual ou save após fim. Não pode
      // dar > 1.0 (quebraria heurística 90% na UI).
      final e = PauloFlixEpisodeRecord(
        id: 1,
        seasonId: 10,
        episodeNumber: 1,
        title: 'ep 1',
        videoUrl: 'https://server/S01E01.mkv',
        positionSeconds: 1500,
        durationSeconds: 1440,
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(e.progressRatio, 1.0);
    });

    test('equality por (seasonId, episodeNumber) — não por id', () {
      // Mesma chave de negócio: mesma season, mesmo episode number, ids
      // diferentes. Devem ser iguais (sync reescreve a row).
      final a = PauloFlixEpisodeRecord(
        id: 1,
        seasonId: 10,
        episodeNumber: 1,
        title: 'ep 1',
        videoUrl: 'https://server/S01E01.mkv',
        lastSynced: DateTime(2026, 1, 1),
      );
      final b = PauloFlixEpisodeRecord(
        id: 999,
        seasonId: 10,
        episodeNumber: 1,
        title: 'ep 1 - atualizado',
        videoUrl: 'https://server/S01E01-novo.mkv',
        durationSeconds: 1440,
        positionSeconds: 100,
        lastSynced: DateTime(2026, 6, 22),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('episodes diferentes (mesma season, número diferente) são diferentes', () {
      final a = PauloFlixEpisodeRecord(
        id: 1,
        seasonId: 10,
        episodeNumber: 1,
        title: 'ep 1',
        videoUrl: 'https://server/S01E01.mkv',
        lastSynced: DateTime(2026, 1, 1),
      );
      final b = PauloFlixEpisodeRecord(
        id: 2,
        seasonId: 10,
        episodeNumber: 2,
        title: 'ep 2',
        videoUrl: 'https://server/S01E02.mkv',
        lastSynced: DateTime(2026, 1, 1),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
