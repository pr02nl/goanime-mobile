import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/services/episode_progress_service.dart';
import 'package:goanime/domain/repositories/paulo_flix_episode_progress_repository.dart';

/// Testes do `EpisodeProgressService` (Fase 2.1 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
///
/// Foco:
/// 1. **`shouldResetForResume`** (função pura) — todos os 6 cenários da
///    Decisão 6.
/// 2. **`prepareResumeOrReset`** — chama `resetProgress` quando reset.
/// 3. **`start`** — agenda Timer.periodic de 5s; tick chama updateProgress.
/// 4. **`flush`** — último save + cancela timer; idempotente.
void main() {
  // ─── Função pura: shouldResetForResume ────────────────────────────────

  group('shouldResetForResume (Decisão 6)', () {
    test('isCompleted=true → reset (reassistir)', () {
      expect(
        EpisodeProgressService.shouldResetForResume(
          isCompleted: true,
          positionSeconds: 95,
          durationSeconds: 100,
        ),
        isTrue,
        reason: 'ratio 95% + isCompleted=true = claramente re-assistindo',
      );
    });

    test('isCompleted=true, position=0 → reset (consistente)', () {
      expect(
        EpisodeProgressService.shouldResetForResume(
          isCompleted: true,
          positionSeconds: 0,
          durationSeconds: 100,
        ),
        isTrue,
        reason: 'isCompleted=true sempre reseta, mesmo com position=0',
      );
    });

    test('ratio < 10% sem isCompleted → reset (fechou sem querer)', () {
      expect(
        EpisodeProgressService.shouldResetForResume(
          isCompleted: false,
          positionSeconds: 5,
          durationSeconds: 100,
        ),
        isTrue,
        reason: '5% é provavelmente "abriu e fechou sem querer"',
      );
    });

    test('ratio >= 10% e < 90% → retomar (parou intencionalmente)', () {
      expect(
        EpisodeProgressService.shouldResetForResume(
          isCompleted: false,
          positionSeconds: 30,
          durationSeconds: 100,
        ),
        isFalse,
        reason: '30% é claramente uma pausa intencional',
      );
    });

    test('ratio ~89% → retomar (perto do fim, ainda incompleto)', () {
      expect(
        EpisodeProgressService.shouldResetForResume(
          isCompleted: false,
          positionSeconds: 89,
          durationSeconds: 100,
        ),
        isFalse,
        reason: '89% < 90% = ainda em andamento (não completou)',
      );
    });

    test('duration=0 (sem info) → retomar (não reseta sem dados)', () {
      expect(
        EpisodeProgressService.shouldResetForResume(
          isCompleted: false,
          positionSeconds: 0,
          durationSeconds: 0,
        ),
        isFalse,
        reason: 'sem duration não sabemos se é <10%, então retoma do 0',
      );
    });
  });

  // ─── Recorder: ciclo de vida (mock do repository) ────────────────────

  group('prepareResumeOrReset', () {
    test('reset=true chama repo.resetProgress e retorna true', () async {
      final repo = _MockRepo();
      final service = EpisodeProgressService(
        repo: repo,
        seasonId: 1,
        episodeNumber: 1,
      );

      final shouldReset = await service.prepareResumeOrReset(
        isCompleted: true,
        positionSeconds: 95,
        durationSeconds: 100,
      );

      expect(shouldReset, isTrue);
      expect(repo.resetCalls, 1);
      expect(repo.updateCalls, 0,
          reason: 'reset NÃO chama updateProgress');
    });

    test('reset=false NÃO chama repo.resetProgress e retorna false',
        () async {
      final repo = _MockRepo();
      final service = EpisodeProgressService(
        repo: repo,
        seasonId: 1,
        episodeNumber: 1,
      );

      final shouldReset = await service.prepareResumeOrReset(
        isCompleted: false,
        positionSeconds: 30,
        durationSeconds: 100,
      );

      expect(shouldReset, isFalse);
      expect(repo.resetCalls, 0);
    });
  });

  group('start + flush', () {
    test('start agenda timer e tick chama updateProgress com posição atual',
        () {
      // fakeAsync avança o tempo virtualmente — Timer.periodic(5s)
      // dispara sem precisar esperar 5s reais.
      fakeAsync((async) {
        final repo = _MockRepo();
        final service = EpisodeProgressService(
          repo: repo,
          seasonId: 1,
          episodeNumber: 1,
        );

        // Posição muda a cada chamada (simula o player avançando).
        var pos = 0;
        service.start(
          getCurrentPosition: () => Duration(seconds: pos),
          getDuration: () => const Duration(seconds: 100),
        );

        // Avança 5s + um pouco → 1 tick.
        pos = 5;
        async.elapse(const Duration(seconds: 5, milliseconds: 10));
        expect(repo.updateCalls, 1,
            reason: '1 tick após 5s = 1 updateProgress');
        expect(repo.lastUpdate?.positionSeconds, 5);

        // Avança mais 5s → 2o tick.
        pos = 10;
        async.elapse(const Duration(seconds: 5));
        expect(repo.updateCalls, 2);
        expect(repo.lastUpdate?.positionSeconds, 10,
            reason: 'segundo tick deve gravar posição 10');
      });
    });

    test('NÃO chama updateProgress se posição não mudou (deduplicação)',
        () {
      fakeAsync((async) {
        final repo = _MockRepo();
        final service = EpisodeProgressService(
          repo: repo,
          seasonId: 1,
          episodeNumber: 1,
        );

        service.start(
          getCurrentPosition: () => const Duration(seconds: 5),
          getDuration: () => const Duration(seconds: 100),
        );

        // Avança 30s = 6 ticks esperados, mas posição = 5s constante.
        // Primeiro tick: pos=5 → save (calls=1, _lastSavedPosition=5).
        // Ticks 2-6: pos=5 == _lastSavedPosition → no save.
        async.elapse(const Duration(seconds: 30));
        expect(repo.updateCalls, 1,
            reason: 'posição constante = 1 save no primeiro tick, resto dedup');
      });
    });

    test('flush faz último save e cancela o timer', () {
      fakeAsync((async) {
        final repo = _MockRepo();
        final service = EpisodeProgressService(
          repo: repo,
          seasonId: 1,
          episodeNumber: 1,
        );

        var pos = 50;
        service.start(
          getCurrentPosition: () => Duration(seconds: pos),
          getDuration: () => const Duration(seconds: 100),
        );

        // Avança 5s → 1 tick.
        async.elapse(const Duration(seconds: 5));
        final callsBeforeFlush = repo.updateCalls;
        expect(callsBeforeFlush, 1);

        // Flush: posição muda para 75.
        pos = 75;
        async.flushMicrotasks();
        service
            .flush(
              getCurrentPosition: () => Duration(seconds: pos),
              getDuration: () => const Duration(seconds: 100),
            )
            .then((_) {
              // Posição 75 foi gravada pelo flush.
              expect(repo.lastUpdate?.positionSeconds, 75);

              // Timer foi cancelado — esperas adicionais NÃO geram saves.
              final callsAfterFlush = repo.updateCalls;
              async.elapse(const Duration(seconds: 10));
              expect(repo.updateCalls, callsAfterFlush,
                  reason: 'flush deve ter cancelado o timer');
            });
        async.flushMicrotasks();
      });
    });

    test('flush é idempotente (chamar 2x não duplica save)', () {
      fakeAsync((async) {
        final repo = _MockRepo();
        final service = EpisodeProgressService(
          repo: repo,
          seasonId: 1,
          episodeNumber: 1,
        );

        service.start(
          getCurrentPosition: () => const Duration(seconds: 30),
          getDuration: () => const Duration(seconds: 100),
        );

        // Flush 1: posição 30, primeiro save.
        service
            .flush(
              getCurrentPosition: () => const Duration(seconds: 30),
              getDuration: () => const Duration(seconds: 100),
            )
            .then((_) {
              final callsAfterFirst = repo.updateCalls;
              expect(callsAfterFirst, 1);

              // Flush 2: mesma posição = no-op.
              service
                  .flush(
                    getCurrentPosition: () => const Duration(seconds: 30),
                    getDuration: () => const Duration(seconds: 100),
                  )
                  .then((_) {
                    expect(repo.updateCalls, callsAfterFirst,
                        reason: 'flush com mesma posição = no-op');
                  });
            });
        async.flushMicrotasks();
      });
    });

    test('stop() cancela o timer sem flush', () {
      fakeAsync((async) {
        final repo = _MockRepo();
        final service = EpisodeProgressService(
          repo: repo,
          seasonId: 1,
          episodeNumber: 1,
        );

        service.start(
          getCurrentPosition: () => const Duration(seconds: 5),
          getDuration: () => const Duration(seconds: 100),
        );

        // Avança 5s → 1 tick.
        async.elapse(const Duration(seconds: 5));
        expect(repo.updateCalls, 1);

        service.stop();

        // Avança mais 30s = 6 ticks esperados, mas timer foi cancelado.
        async.elapse(const Duration(seconds: 30));
        expect(repo.updateCalls, 1,
            reason: 'stop() deve ter cancelado o timer');
      });
    });
  });
}

/// Mock manual do `PauloFlixEpisodeProgressRepository` (sem mocktail para
/// evitar mais uma dep). Conta chamadas e guarda o último update.
class _MockRepo implements PauloFlixEpisodeProgressRepository {
  int updateCalls = 0;
  int resetCalls = 0;
  _UpdateCall? lastUpdate;

  @override
  Future<void> updateProgress({
    required int seasonId,
    required int episodeNumber,
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    updateCalls++;
    lastUpdate = _UpdateCall(
      seasonId: seasonId,
      episodeNumber: episodeNumber,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<void> resetProgress({
    required int seasonId,
    required int episodeNumber,
  }) async {
    resetCalls++;
  }

  // Métodos não usados pelos testes — throw para sinalizar.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_MockRepo: ${invocation.memberName} não implementado (não usado '
      'nestes testes)',
    );
  }
}

class _UpdateCall {
  final int seasonId;
  final int episodeNumber;
  final int positionSeconds;
  final int? durationSeconds;
  const _UpdateCall({
    required this.seasonId,
    required this.episodeNumber,
    required this.positionSeconds,
    this.durationSeconds,
  });
}
