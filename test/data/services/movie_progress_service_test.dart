/// Testes do `MovieProgressService`.
///
/// Foco:
/// 1. **`shouldResetForResume`** (função pura) — mesma heurística do
///    `EpisodeProgressService`.
/// 2. **`prepareResumeOrReset`** — chama `resetProgress` quando reset.
/// 3. **`start`** — agenda Timer.periodic de 5s; tick chama updateProgress.
/// 4. **`flush`** — último save + cancela timer; idempotente.
/// 5. **`stop`** — cancela timer sem save.
/// 6. **Erro de streaming: `stop()` impede que posição 0 (corrompida)
///    sobrescreva o progresso salvo.**
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/services/movie_progress_service.dart';
import 'package:goanime/domain/models/paulo_flix_movie_progress_record.dart';
import 'package:goanime/domain/repositories/paulo_flix_movie_progress_repository.dart';

void main() {
  // ─── Função pura: shouldResetForResume ───────────────────────────

  group('shouldResetForResume', () {
    test('isCompleted=true → reset (reassistir)', () {
      expect(
        MovieProgressService.shouldResetForResume(
          isCompleted: true,
          positionSeconds: 95,
          durationSeconds: 100,
        ),
        isTrue,
        reason: 'completado = claramente re-assistindo',
      );
    });

    test('ratio < 10% sem isCompleted → reset (fechou sem querer)', () {
      expect(
        MovieProgressService.shouldResetForResume(
          isCompleted: false,
          positionSeconds: 5,
          durationSeconds: 100,
        ),
        isTrue,
        reason: '5% é "abriu e fechou sem querer"',
      );
    });

    test('ratio >= 10% → retomar', () {
      expect(
        MovieProgressService.shouldResetForResume(
          isCompleted: false,
          positionSeconds: 30,
          durationSeconds: 100,
        ),
        isFalse,
        reason: '30% é pausa intencional',
      );
    });

    test('duration=0 → retomar (sem dados não reseta)', () {
      expect(
        MovieProgressService.shouldResetForResume(
          isCompleted: false,
          positionSeconds: 0,
          durationSeconds: 0,
        ),
        isFalse,
        reason: 'sem duração não sabemos ratio → retoma do 0',
      );
    });
  });

  // ─── Ciclo de vida (mock do repository) ─────────────────────────

  group('prepareResumeOrReset', () {
    test('reset=true chama repo.resetProgress e retorna true', () async {
      final repo = _MockMovieRepo();
      final service = MovieProgressService(
        repository: repo,
        folderName: 'filme-teste',
        serverUrl: 'https://example.com',
        displayName: 'Filme Teste',
      );

      final shouldReset = await service.prepareResumeOrReset(
        isCompleted: true,
        positionSeconds: 95,
        durationSeconds: 100,
      );

      expect(shouldReset, isTrue);
      expect(repo.resetCalls, 1);
    });

    test('reset=false NÃO chama repo.resetProgress e retorna false',
        () async {
      final repo = _MockMovieRepo();
      final service = MovieProgressService(
        repository: repo,
        folderName: 'filme-teste',
        serverUrl: 'https://example.com',
        displayName: 'Filme Teste',
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
    test('start agenda timer e tick chama updateProgress', () {
      fakeAsync((async) {
        final repo = _MockMovieRepo();
        final service = MovieProgressService(
          repository: repo,
          folderName: 'filme-teste',
          serverUrl: 'https://example.com',
          displayName: 'Filme Teste',
        );

        var pos = 0;
        service.start(
          getCurrentPosition: () => Duration(seconds: pos),
          getDuration: () => const Duration(seconds: 100),
        );

        pos = 5;
        async.elapse(const Duration(seconds: 5, milliseconds: 10));
        expect(repo.updateCalls, 1,
            reason: '1 tick após 5s = 1 updateProgress');
        expect(repo.lastUpdate?.positionSeconds, 5);

        pos = 10;
        async.elapse(const Duration(seconds: 5));
        expect(repo.updateCalls, 2);
        expect(repo.lastUpdate?.positionSeconds, 10);
      });
    });

    test('NÃO chama updateProgress se posição não mudou (deduplicação)',
        () {
      fakeAsync((async) {
        final repo = _MockMovieRepo();
        final service = MovieProgressService(
          repository: repo,
          folderName: 'filme-teste',
          serverUrl: 'https://example.com',
          displayName: 'Filme Teste',
        );

        service.start(
          getCurrentPosition: () => const Duration(seconds: 5),
          getDuration: () => const Duration(seconds: 100),
        );

        async.elapse(const Duration(seconds: 30));
        expect(repo.updateCalls, 1,
            reason: 'posição constante = 1 save, resto dedup');
      });
    });

    test('flush faz último save e cancela o timer', () {
      fakeAsync((async) {
        final repo = _MockMovieRepo();
        final service = MovieProgressService(
          repository: repo,
          folderName: 'filme-teste',
          serverUrl: 'https://example.com',
          displayName: 'Filme Teste',
        );

        var pos = 50;
        service.start(
          getCurrentPosition: () => Duration(seconds: pos),
          getDuration: () => const Duration(seconds: 100),
        );

        async.elapse(const Duration(seconds: 5));
        expect(repo.updateCalls, 1);

        pos = 75;
        async.flushMicrotasks();
        service
            .flush(
              getCurrentPosition: () => Duration(seconds: pos),
              getDuration: () => const Duration(seconds: 100),
            )
            .then((_) {
              expect(repo.lastUpdate?.positionSeconds, 75);
              final callsAfterFlush = repo.updateCalls;
              async.elapse(const Duration(seconds: 10));
              expect(repo.updateCalls, callsAfterFlush,
                  reason: 'timer cancelado após flush');
            });
        async.flushMicrotasks();
      });
    });
  });

  group('stop() — proteção contra erro de streaming', () {
    test('stop() cancela o timer sem fazer save', () {
      fakeAsync((async) {
        final repo = _MockMovieRepo();
        final service = MovieProgressService(
          repository: repo,
          folderName: 'filme-teste',
          serverUrl: 'https://example.com',
          displayName: 'Filme Teste',
        );

        service.start(
          getCurrentPosition: () => const Duration(seconds: 5),
          getDuration: () => const Duration(seconds: 100),
        );

        // 1 tick salva posição 5.
        async.elapse(const Duration(seconds: 5));
        expect(repo.updateCalls, 1);
        expect(repo.lastUpdate?.positionSeconds, 5);

        service.stop();

        // Após stop, mesmo avançando o timer não deve salvar.
        async.elapse(const Duration(seconds: 30));
        expect(repo.updateCalls, 1,
            reason: 'stop() cancelou o timer');
      });
    });

    test('erro de streaming: stop() ANTES que posição 0 corroa o save',
        () {
      // Cenário: usuário assistiu até 50s, erro ocorre, player.state.position
      // zera para 0. O onPlayerError chama stop() antes do próximo tick.
      // Verificamos que o progresso salvo (50s) NÃO é sobrescrito com 0.
      fakeAsync((async) {
        final repo = _MockMovieRepo();
        final service = MovieProgressService(
          repository: repo,
          folderName: 'filme-teste',
          serverUrl: 'https://example.com',
          displayName: 'Filme Teste',
        );

        // Posição inicia em 0 e sobe até 50 (simula playback normal).
        var pos = 0;
        service.start(
          getCurrentPosition: () => Duration(seconds: pos),
          getDuration: () => const Duration(seconds: 100),
        );

        // Avança 50s = 10 ticks, posição vai de 0 a 50.
        // O último tick aos 45s salva posição 45.
        // Precisamos simular: tick aos 5s (pos=5), 10s (10), ..., 50s.
        for (int i = 0; i < 10; i++) {
          pos = (i + 1) * 5;
          async.elapse(const Duration(seconds: 5));
        }
        expect(repo.updateCalls, 10);
        expect(repo.lastUpdate?.positionSeconds, 50);

        // ─── ERRO DE STREAMING ─────────────────────────────────
        // A posição do player zera para 0 (player.state.position corrompido).
        pos = 0;

        // onPlayerError → stop() é chamado ANTES do próximo tick.
        service.stop();

        // Avança 30s extras — NENHUM save deve acontecer.
        async.elapse(const Duration(seconds: 30));
        expect(repo.updateCalls, 10,
            reason: 'stop() impediu que posição 0 sobrescrevesse o '
                'progresso salvo');
        expect(repo.lastUpdate?.positionSeconds, 50,
            reason: 'último progresso válido (50s) deve ser preservado');
      });
    });

    test('erro de streaming: saveProgress manual com posição capturada '
        'funciona mesmo após stop()', () {
      // Cenário: após onPlayerError + stop(), o dispose salva o progresso
      // final com a posição CAPTURADA (não a posição corrompida).
      fakeAsync((fa) async {
        final repo = _MockMovieRepo();
        final service = MovieProgressService(
          repository: repo,
          folderName: 'filme-teste',
          serverUrl: 'https://example.com',
          displayName: 'Filme Teste',
        );

        service.start(
          getCurrentPosition: () => const Duration(seconds: 50),
          getDuration: () => const Duration(seconds: 100),
        );

        fa.elapse(const Duration(seconds: 5));
        expect(repo.updateCalls, 1);
        expect(repo.lastUpdate?.positionSeconds, 50);

        // Erro → stop()
        service.stop();

        // Dispose captura a posição ANTES de parar o player.
        // Mesmo que player.state.position já esteja 0, usamos o
        // VALOR CAPTURADO.
        await service.saveProgress(
          positionSeconds: 50, // valor capturado antes do stop
          durationSeconds: 100,
        );

        // saveProgress com valores capturados deve salvar a posição correta,
        // não a corrompida (0).
        expect(repo.updateCalls, 2,
            reason: 'saveProgress manual após stop() salvou posição capturada');
        expect(repo.lastUpdate?.positionSeconds, 50,
            reason: 'progresso final deve ser 50s, não 0');

        fa.flushMicrotasks();
      });
    });
  });
}

/// Mock manual do `PauloFlixMovieProgressRepository`.
class _MockMovieRepo implements PauloFlixMovieProgressRepository {
  int updateCalls = 0;
  int resetCalls = 0;
  _MovieUpdateCall? lastUpdate;

  @override
  Future<void> updateProgress({
    required String folderName,
    required String serverUrl,
    required String displayName,
    String? imageUrl,
    String? videoUrl,
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    updateCalls++;
    lastUpdate = _MovieUpdateCall(
      folderName: folderName,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<void> resetProgress(String folderName) async {
    resetCalls++;
  }

  @override
  Future<PauloFlixMovieProgressRecord?> getProgress(String folderName) =>
      Future.value(null);

  @override
  Future<List<PauloFlixMovieProgressRecord>> getInProgressMovies({
    int limit = 12,
  }) =>
      Future.value([]);

  @override
  Stream<List<PauloFlixMovieProgressRecord>> watchInProgressMovies({
    int limit = 12,
  }) =>
      const Stream.empty();

  @override
  Future<List<PauloFlixMovieProgressRecord>> getAllProgress() =>
      Future.value([]);

  @override
  Stream<List<PauloFlixMovieProgressRecord>> watchAllProgress() =>
      const Stream.empty();
}

class _MovieUpdateCall {
  final String folderName;
  final int positionSeconds;
  final int? durationSeconds;
  const _MovieUpdateCall({
    required this.folderName,
    required this.positionSeconds,
    this.durationSeconds,
  });
}
