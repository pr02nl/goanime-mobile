import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/player/video_player_introdb_mixin.dart';
import 'package:media_kit/media_kit.dart';

/// Widget de teste específico para simular o fluxo de loadSkipSegments
/// com delays HTTP configuráveis, reproduzindo o mesmo padrão de guards
/// do production code.
class _HttpDelaySimulator extends StatefulWidget {
  const _HttpDelaySimulator();

  @override
  State<_HttpDelaySimulator> createState() => _HttpDelaySimulatorState();
}

class _HttpDelaySimulatorState extends State<_HttpDelaySimulator>
    with VideoPlayerIntroDbMixin {
  Player? testPlayer;

  @override
  bool isActiveEpisode(String? key) {
    if (key == null) return false;
    return activeEpisodeKey == key;
  }

  @override
  Player? get player => testPlayer;

  @override
  BuildContext get localizationContext => context;

  void updateSkipState({
    required bool visible,
    String label = '',
    String? activeSegment,
  }) {
    setState(() {
      showSkipButton = visible;
      skipButtonLabel = label;
      skipButtonActiveSegment = activeSegment;
    });
  }

  /// Simula _replaceEpisode: cleanup + reset flags.
  void simulateReplaceEpisode() {
    setState(() {
      cleanupIntroDb();
      skipButtonActiveSegment = null;
      skipButtonDismissed = false;
      maybeReshowSkipButton();
      showSkipButton = false;
      skipButtonLabel = '';
    });
  }

  /// Simula o setup de um novo episódio (como _initializeVideoPlayer faz).
  void simulateNewEpisode({
    required String episodeKey,
    bool hasSegments = true,
  }) {
    setState(() {
      activeEpisodeKey = episodeKey;
      if (hasSegments) {
        startPositionTimer();
      }
    });
  }

  /// Simula loadSkipSegments com delay HTTP configurável.
  ///
  /// Reproduz o mesmo padrão de guards do production code:
  /// 1. Captura requestKey no início
  /// 2. Verifica isActiveEpisode (guarda 1)
  /// 3. Verifica tmdbId (guarda 2)
  /// 4. Delay simulando HTTP
  /// 5. Verifica mounted + isActiveEpisode (guarda 3)
  /// 6. Atualiza estado via setState (mesmas flags que o real)
  /// 7. Dupla verificação + inicia timer se houver segmentos (guarda 4)
  ///
  /// Retorna true se o callback foi processado (episódio ainda ativo).
  Future<bool> simulateLoadSkipSegments({
    required String episodeKey,
    int? tmdbId = 123,
    Duration httpDelay = Duration.zero,
    bool httpReturnsSegments = true,
  }) async {
    // Guarda 1: episódio já mudou antes de começar?
    final requestKey = activeEpisodeKey;
    if (!isActiveEpisode(requestKey)) return false;

    // Guarda 2: sem tmdbId disponível
    if (tmdbId == null) return false;

    // Simula delay da requisição HTTP
    if (httpDelay > Duration.zero) {
      await Future.delayed(httpDelay);
    }

    // Guarda 3: episódio mudou durante o HTTP?
    if (!mounted || !isActiveEpisode(requestKey)) return false;

    // Simula o setState do callback HTTP — mesmas flags que o real
    setState(() {
      skipButtonActiveSegment = null;
      skipButtonDismissed = false;
      maybeReshowSkipButton();
      showSkipButton = false;
      skipButtonLabel = '';
    });

    // Guarda 4: dupla verificação pós-build + inicia timer
    if (isActiveEpisode(requestKey) && httpReturnsSegments) {
      startPositionTimer();
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showSkipButton)
          Text(skipButtonLabel, key: const Key('skip_label')),
        if (positionTimer?.isActive == true)
          const Text('position_timer', key: Key('position_timer')),
        Text(
          'activeEpisodeKey=$activeEpisodeKey',
          key: const Key('state_display'),
        ),
      ],
    );
  }
}

Widget buildApp() => const MaterialApp(
      home: Scaffold(body: _HttpDelaySimulator()),
    );

void main() {
  group('HTTP delay — integração loadSkipSegments', () {
    Future<_HttpDelaySimulatorState> setupState(WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      return tester.state<_HttpDelaySimulatorState>(
        find.byType(_HttpDelaySimulator),
      );
    }

    // ═══════════════════════════════════════════════════════════════
    // 1. Fluxo normal (sem race condition)
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'HTTP imediato sem troca → callback processado, timer iniciado',
      (tester) async {
        final state = await setupState(tester);
        state.activeEpisodeKey = 'ep1';

        final processed = await state.simulateLoadSkipSegments(
          episodeKey: 'ep1',
          httpDelay: Duration.zero,
          httpReturnsSegments: true,
        );

        expect(processed, isTrue, reason: 'Callback deve ser processado');
        expect(state.positionTimer?.isActive, isTrue,
            reason: 'Timer de 500ms deve ser iniciado');
        expect(state.activeEpisodeKey, 'ep1');
      },
    );

    testWidgets(
      'HTTP com delay sem troca → callback processado, timer iniciado',
      (tester) async {
        final state = await setupState(tester);
        state.activeEpisodeKey = 'ep1';

        // Inicia a simulação com delay de 100ms
        final future = state.simulateLoadSkipSegments(
          episodeKey: 'ep1',
          httpDelay: const Duration(milliseconds: 100),
          httpReturnsSegments: true,
        );

        // Avança o tempo fake para o delay expirar
        await tester.pump(const Duration(milliseconds: 100));
        final processed = await future;

        expect(processed, isTrue, reason:
            'Callback processado (episódio não mudou)');
        expect(state.positionTimer?.isActive, isTrue,
            reason: 'Timer iniciado após delay');
        expect(state.activeEpisodeKey, 'ep1');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // 2. Race condition: troca de episódio DURANTE o HTTP
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'HTTP atrasado com troca externa durante delay → '
      'callback ignorado (guarda 3)',
      (tester) async {
        final state = await setupState(tester);
        state.activeEpisodeKey = 'ep1';

        // Inicia HTTP para ep1 com delay de 100ms
        final future = state.simulateLoadSkipSegments(
          episodeKey: 'ep1',
          httpDelay: const Duration(milliseconds: 100),
          httpReturnsSegments: true,
        );

        // Troca de episódio durante o delay (simula auto-play)
        state.simulateReplaceEpisode();
        state.simulateNewEpisode(episodeKey: 'ep2');
        await tester.pump();

        // activeEpisodeKey já é ep2, timer do ep2 está rodando
        expect(state.activeEpisodeKey, 'ep2');
        expect(state.positionTimer?.isActive, isTrue,
            reason: 'Timer do ep2 ativo');

        // Avança o tempo para o delay do ep1 expirar
        await tester.pump(const Duration(milliseconds: 100));
        final processed = await future;

        // Callback do ep1 foi ignorado pelo guarda 3
        expect(processed, isFalse,
            reason: 'Callback do ep1 ignorado');

        // Estado do ep2 intacto
        expect(state.activeEpisodeKey, 'ep2');
        expect(state.positionTimer?.isActive, isTrue,
            reason: 'Timer do ep2 continua ativo');
        expect(state.showSkipButton, isFalse);
      },
    );

    testWidgets(
      'múltiplos HTTPs atrasados com trocas — apenas o último '
      'é processado',
      (tester) async {
        final state = await setupState(tester);

        // ─── Ep1: inicia HTTP, troca para ep2 durante delay ─────
        state.activeEpisodeKey = 'ep1';
        final future1 = state.simulateLoadSkipSegments(
          episodeKey: 'ep1',
          httpDelay: const Duration(milliseconds: 50),
          httpReturnsSegments: true,
        );

        state.simulateReplaceEpisode();
        state.simulateNewEpisode(episodeKey: 'ep2');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final result1 = await future1;
        expect(result1, isFalse, reason: 'HTTP ep1 ignorado');

        // ─── Ep2: inicia HTTP ──────────────────────────────────
        final future2 = state.simulateLoadSkipSegments(
          episodeKey: 'ep2',
          httpDelay: const Duration(milliseconds: 50),
          httpReturnsSegments: true,
        );

        await tester.pump(const Duration(milliseconds: 50));
        final result2 = await future2;

        expect(result2, isTrue, reason: 'HTTP ep2 processado');
        expect(state.positionTimer?.isActive, isTrue,
            reason: 'Timer do ep2 ativo');
        expect(state.activeEpisodeKey, 'ep2');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // 3. Guardas: tmdbId null e sem segmentos
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'tmdbId null → early return (guarda 2), nenhum efeito colateral',
      (tester) async {
        final state = await setupState(tester);
        state.activeEpisodeKey = 'ep1';

        final processed = await state.simulateLoadSkipSegments(
          episodeKey: 'ep1',
          tmdbId: null,
        );

        expect(processed, isFalse, reason: 'Sem tmdbId → sem callback');
        expect(state.positionTimer, isNull,
            reason: 'Timer nunca criado');
        expect(state.showSkipButton, isFalse);
        expect(state.skipButtonLabel, isEmpty);
      },
    );

    testWidgets(
      'HTTP retorna sem segmentos → callback processado mas sem timer',
      (tester) async {
        final state = await setupState(tester);
        state.activeEpisodeKey = 'ep1';

        final processed = await state.simulateLoadSkipSegments(
          episodeKey: 'ep1',
          httpReturnsSegments: false,
        );

        expect(processed, isTrue,
            reason: 'Callback processado (ep ainda ativo)');
        expect(state.positionTimer, isNull,
            reason: 'Sem segmentos → sem timer');
        expect(state.showSkipButton, isFalse);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // 4. Guarda 1: episódio já trocado antes de loadSkipSegments
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'activeEpisodeKey não corresponde → early return (guarda 1)',
      (tester) async {
        final state = await setupState(tester);

        // activeEpisodeKey é null, isActiveEpisode(null) = false
        final processed = await state.simulateLoadSkipSegments(
          episodeKey: 'ep1',
        );

        expect(processed, isFalse,
            reason: 'activeEpisodeKey não corresponde → early return');
        expect(state.positionTimer, isNull);
      },
    );
  });
}
