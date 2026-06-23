import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/paulo_flix_progress_stats.dart';

void main() {
  group('PauloFlixProgressStats', () {
    test('progressRatio é 0.0 quando totalEpisodes = 0 (sem episodes)', () {
      const stats = PauloFlixProgressStats(
        totalEpisodes: 0,
        completedEpisodes: 0,
        inProgressEpisodes: 0,
      );
      expect(stats.progressRatio, 0.0);
    });

    test('progressRatio é 0.5 quando metade dos episodes estão completos', () {
      const stats = PauloFlixProgressStats(
        totalEpisodes: 10,
        completedEpisodes: 5,
        inProgressEpisodes: 0,
      );
      expect(stats.progressRatio, 0.5);
    });

    test('progressRatio é 1.0 quando todos os episodes estão completos', () {
      const stats = PauloFlixProgressStats(
        totalEpisodes: 24,
        completedEpisodes: 24,
        inProgressEpisodes: 0,
      );
      expect(stats.progressRatio, 1.0);
    });

    test('isAnimeCompleted é true quando total == completed (e total > 0)', () {
      const stats = PauloFlixProgressStats(
        totalEpisodes: 12,
        completedEpisodes: 12,
        inProgressEpisodes: 0,
      );
      expect(stats.isAnimeCompleted, isTrue);
    });

    test('isAnimeCompleted é false quando ainda falta pelo menos 1', () {
      const stats = PauloFlixProgressStats(
        totalEpisodes: 12,
        completedEpisodes: 11,
        inProgressEpisodes: 1,
      );
      expect(stats.isAnimeCompleted, isFalse);
    });

    test('isAnimeCompleted é false em anime sem episodes (total=0)', () {
      // Decisão 7: anime "completo" sem episodes não faz sentido.
      // Sem episodes = "nunca abriu o anime" ≠ "completou tudo".
      const stats = PauloFlixProgressStats(
        totalEpisodes: 0,
        completedEpisodes: 0,
        inProgressEpisodes: 0,
      );
      expect(stats.isAnimeCompleted, isFalse);
    });

    test('isAnimeInProgress é true quando tem pelo menos 1 episode parcial', () {
      const stats = PauloFlixProgressStats(
        totalEpisodes: 12,
        completedEpisodes: 3,
        inProgressEpisodes: 1,
      );
      expect(stats.isAnimeInProgress, isTrue);
    });

    test('isAnimeInProgress é false quando não tem episodes parciais', () {
      const stats = PauloFlixProgressStats(
        totalEpisodes: 12,
        completedEpisodes: 12,
        inProgressEpisodes: 0,
      );
      expect(stats.isAnimeInProgress, isFalse);
    });

    test('isAnimeInProgress é false em anime sem episodes', () {
      const stats = PauloFlixProgressStats(
        totalEpisodes: 0,
        completedEpisodes: 0,
        inProgressEpisodes: 0,
      );
      expect(stats.isAnimeInProgress, isFalse);
    });

    test('equality é por valor (data class behavior)', () {
      const a = PauloFlixProgressStats(
        totalEpisodes: 10,
        completedEpisodes: 5,
        inProgressEpisodes: 2,
      );
      const b = PauloFlixProgressStats(
        totalEpisodes: 10,
        completedEpisodes: 5,
        inProgressEpisodes: 2,
      );
      const c = PauloFlixProgressStats(
        totalEpisodes: 10,
        completedEpisodes: 6,
        inProgressEpisodes: 2,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode é consistente com equality', () {
      const a = PauloFlixProgressStats(
        totalEpisodes: 10,
        completedEpisodes: 5,
        inProgressEpisodes: 2,
      );
      const b = PauloFlixProgressStats(
        totalEpisodes: 10,
        completedEpisodes: 5,
        inProgressEpisodes: 2,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
