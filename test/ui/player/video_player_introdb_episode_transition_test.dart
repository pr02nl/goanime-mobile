import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/player/video_player_introdb_mixin.dart';
import 'package:media_kit/media_kit.dart';

/// Widget de teste que simula o estado de um episódio em reprodução
/// para validar a transição (auto-play) entre episódios.
class _EpisodeSimulator extends StatefulWidget {
  const _EpisodeSimulator();

  @override
  State<_EpisodeSimulator> createState() => _EpisodeSimulatorState();
}

class _EpisodeSimulatorState extends State<_EpisodeSimulator>
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

  /// Simula o que _replaceEpisode faz no production code:
  /// 1. cleanupIntroDb() — cancela timers
  /// 2. Reseta todas as flags do skip
  /// 3. Chama maybeReshowSkipButton() — limpa _skipButtonAutoHidden
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

  /// Simula o setup de um novo episódio após _initializeVideoPlayer
  /// completar: seta activeEpisodeKey + dispara loadSkipSegments
  /// (versão síncrona sem HTTP real).
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

Widget buildSimulatorApp() {
  return const MaterialApp(
    home: Scaffold(body: _EpisodeSimulator()),
  );
}

void main() {
  group('Troca de episódio (auto-play) — integração', () {
    Future<_EpisodeSimulatorState> setupState(WidgetTester tester) async {
      await tester.pumpWidget(buildSimulatorApp());
      await tester.pump();
      return tester.state<_EpisodeSimulatorState>(
        find.byType(_EpisodeSimulator),
      );
    }

    // ═══════════════════════════════════════════════════════════════
    // 1. CENÁRIO: Episódio 1 rodando com intro → auto-play → Episódio 2
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'replaceEpisode limpa todos os estados do skip do episódio '
      'anterior',
      (tester) async {
        final state = await setupState(tester);

        // ─── Setup: Episódio 1 rodando ──────────────────────────
        state.activeEpisodeKey = 'naruto_ep1';
        state.updateSkipState(
          visible: true,
          label: 'Pular Intro',
          activeSegment: 'intro',
        );
        state.startPositionTimer();
        await tester.pump();

        // Verifica que o timer do ep1 está ativo.
        expect(state.positionTimer?.isActive, isTrue);
        expect(find.byKey(const Key('position_timer')), findsOneWidget);
        // O botão skip deve estar visível.
        expect(find.text('Pular Intro'), findsOneWidget);

        // ─── Ação: Simula _replaceEpisode ───────────────────────
        state.simulateReplaceEpisode();
        await tester.pump();

        // ─── Verificações ───────────────────────────────────────
        expect(state.positionTimer?.isActive, isFalse, reason:
            'Timer de posição do ep1 deve ser cancelado');
        expect(state.skipButtonAutoHideTimer, isNull, reason:
            'Auto-hide timer nunca foi iniciado');
        expect(state.skipButtonActiveSegment, isNull, reason:
            'Segmento ativo deve ser limpo');
        expect(state.skipButtonDismissed, isFalse, reason:
            'skipButtonDismissed deve ser resetado');
        expect(state.skipButtonAutoHidden, isFalse, reason:
            'skipButtonAutoHidden deve ser false após maybeReshowSkipButton');
        expect(state.showSkipButton, isFalse, reason:
            'Botão deve estar oculto');
        expect(state.skipButtonLabel, isEmpty, reason:
            'Label deve estar vazio');

        // Timer sumiu da UI (positionTimer?.isActive é false).
        expect(find.byKey(const Key('position_timer')), findsNothing);
        // O label de skip sumiu.
        expect(find.text('Pular Intro'), findsNothing);
      },
    );

    testWidgets(
      'após replaceEpisode, novo episódio pode iniciar timer '
      'e exibir botão skip normalmente',
      (tester) async {
        final state = await setupState(tester);

        // ─── Setup: Episódio 1 com estado complexo ─────────────
        state.activeEpisodeKey = 'bleach_ep1';
        state.updateSkipState(
          visible: true,
          label: 'Pular Encerramento',
          activeSegment: 'credits',
        );
        state.startPositionTimer();
        await tester.pump();
        expect(state.positionTimer?.isActive, isTrue);

        // ─── Simula replaceEpisode ──────────────────────────────
        state.simulateReplaceEpisode();
        await tester.pump();

        // ─── Setup: Episódio 2 ──────────────────────────────────
        state.simulateNewEpisode(episodeKey: 'bleach_ep2');
        await tester.pump();

        // O timer do ep2 está ativo.
        expect(state.positionTimer?.isActive, isTrue, reason:
            'Timer de posição do ep2 deve estar ativo');
        expect(find.byKey(const Key('position_timer')), findsOneWidget);

        // O botão skip do ep1 não aparece mais.
        expect(find.text('Pular Encerramento'), findsNothing);

        // activeEpisodeKey foi atualizado.
        expect(state.activeEpisodeKey, 'bleach_ep2');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // 2. CENÁRIO: Race condition — HTTP do ep1 retorna após troca
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'HTTP do episódio anterior que retorna após replaceEpisode '
      'é ignorado (isActiveEpisode protege)',
      (tester) async {
        final state = await setupState(tester);

        // ─── Episódio 1 ──────────────────────────────────────────
        state.activeEpisodeKey = 'one_piece_ep1';
        state.simulateNewEpisode(episodeKey: 'one_piece_ep1');
        await tester.pump();

        // Captura a chave que o HTTP usaria.
        final oldRequestKey = state.activeEpisodeKey;

        // ─── Troca para episódio 2 ─────────────────────────────
        state.simulateReplaceEpisode();
        state.simulateNewEpisode(episodeKey: 'one_piece_ep2');
        await tester.pump();

        // Verifica que o activeEpisodeKey mudou.
        expect(state.activeEpisodeKey, 'one_piece_ep2');

        // Simula o callback HTTP do ep1 retornando:
        // loadSkipSegments capturou requestKey = 'one_piece_ep1'
        // Mas activeEpisodeKey agora é 'one_piece_ep2'
        // Logo isActiveEpisode(requestKey) retorna false.
        expect(state.isActiveEpisode(oldRequestKey), isFalse, reason:
            'Callback HTTP do ep1 deve ser ignorado');
      },
    );

    testWidgets(
      'timer de posição do ep1 é automaticamente cancelado '
      'quando activeEpisodeKey muda',
      (tester) async {
        final state = await setupState(tester);

        // ─── Episódio 1 com timer ativo ─────────────────────────
        state.activeEpisodeKey = 'ep_old';
        state.startPositionTimer();
        await tester.pump();

        expect(state.positionTimer?.isActive, isTrue);

        // ─── Simula replaceEpisode (cancela timer) ──────────────
        state.simulateReplaceEpisode();
        await tester.pump();

        // Timer foi cancelado.
        expect(state.positionTimer?.isActive, isFalse);

        // ─── Simula novo episódio ───────────────────────────────
        state.simulateNewEpisode(episodeKey: 'ep_new');
        await tester.pump();

        // Timer novo está ativo com a chave nova.
        expect(state.positionTimer?.isActive, isTrue, reason:
            'Timer do ep2 deve estar ativo após replace');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // 3. CENÁRIO: Transição entre temporadas
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'transição entre temporadas (season 1 → season 2) '
      'também reseta skip state corretamente',
      (tester) async {
        final state = await setupState(tester);

        // ─── Season 1 ────────────────────────────────────────────
        state.activeEpisodeKey = 'anime_s1_e12';
        state.updateSkipState(
          visible: true,
          label: 'Pular Intro',
          activeSegment: 'intro',
        );
        state.startPositionTimer();
        await tester.pump();

        // ─── Simula replaceEpisode (fim da season 1) ───────────
        state.simulateReplaceEpisode();
        await tester.pump();

        // Todas as flags resetadas.
        expect(state.positionTimer?.isActive, isFalse);
        expect(state.skipButtonActiveSegment, isNull);
        expect(state.showSkipButton, isFalse);
        expect(state.skipButtonLabel, isEmpty);
        expect(state.skipButtonAutoHidden, isFalse);

        // ─── Season 2 ───────────────────────────────────────────
        state.simulateNewEpisode(episodeKey: 'anime_s2_e1');
        await tester.pump();

        // Timer ativo para a nova season.
        expect(state.positionTimer?.isActive, isTrue);
        expect(state.activeEpisodeKey, 'anime_s2_e1');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // 4. CENÁRIO: Múltiplas trocas rápidas (skip vários episódios)
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'múltiplas trocas rápidas de episódio não deixam resíduos '
      'de estado',
      (tester) async {
        final state = await setupState(tester);

        // Simula 3 trocas rápidas.
        for (int i = 1; i <= 3; i++) {
          // Sempre chama replace antes de new para garantir
          // que timers antigos sejam limpos.
          if (state.positionTimer?.isActive == true) {
            state.simulateReplaceEpisode();
          }
          state.simulateNewEpisode(episodeKey: 'fast_ep$i');
          await tester.pump();
        }

        // Após 3 trocas, o estado está limpo para o ep4.
        expect(state.activeEpisodeKey, 'fast_ep3');
        expect(state.positionTimer?.isActive, isTrue,
            reason: 'Timer do último episódio deve estar ativo');
        expect(state.showSkipButton, isFalse,
            reason: 'Botão oculto até entrar na intro');
        expect(state.skipButtonActiveSegment, isNull,
            reason: 'Nenhum segmento ativo');

        // Simula entrada na intro do ep3 usando setState.
        state.updateSkipState(
          visible: true,
          label: 'Pular Intro',
          activeSegment: 'intro',
        );
        await tester.pump();

        expect(find.text('Pular Intro'), findsOneWidget);

        // Troca para ep4.
        state.simulateReplaceEpisode();
        state.simulateNewEpisode(episodeKey: 'fast_ep4');
        await tester.pump();

        // Intro do ep3 não influencia ep4.
        expect(find.text('Pular Intro'), findsNothing);
        expect(state.showSkipButton, isFalse);
        expect(state.skipButtonActiveSegment, isNull);
        expect(state.activeEpisodeKey, 'fast_ep4');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // 5. CENÁRIO: Episódio sem intro → replace → episódio com intro
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'episódio sem intro (hasSegments=false) seguido de episódio '
      'com intro funciona',
      (tester) async {
        final state = await setupState(tester);

        // ─── Ep 1: sem intro, sem timer ─────────────────────────
        state.simulateNewEpisode(
          episodeKey: 'no_intro_ep',
          hasSegments: false,
        );
        await tester.pump();

        expect(state.positionTimer, isNull,
            reason: 'Sem segmentos → sem timer');
        expect(state.showSkipButton, isFalse);
        expect(state.skipButtonLabel, isEmpty);

        // ─── Transição para ep 2 com intro ──────────────────────
        state.simulateReplaceEpisode();
        state.simulateNewEpisode(
          episodeKey: 'with_intro_ep',
          hasSegments: true,
        );
        await tester.pump();

        // Timer do ep2 ativo mesmo sem ter segmentos carregados.
        expect(state.positionTimer?.isActive, isTrue,
            reason: 'Ep com segmentos → timer ativo');
        expect(state.showSkipButton, isFalse,
            reason: 'Ainda não entrou na janela de intro');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // 6. CENÁRIO: cleanupIntroDb é chamado mesmo sem timers ativos
    // ═══════════════════════════════════════════════════════════════

    testWidgets(
      'replaceEpisode sem timers ativos (nunca iniciou) '
      'não lança exceção',
      (tester) async {
        final state = await setupState(tester);

        // Estado inicial: sem timers, sem flags.
        expect(state.positionTimer, isNull);
        expect(state.skipButtonAutoHideTimer, isNull);
        expect(state.showSkipButton, isFalse);

        // replaceEpisode sem nada rodando.
        state.simulateReplaceEpisode();
        await tester.pump();

        // Continua limpo.
        expect(state.positionTimer, isNull);
        expect(state.showSkipButton, isFalse);
        expect(state.skipButtonAutoHidden, isFalse);
      },
    );
  });
}
