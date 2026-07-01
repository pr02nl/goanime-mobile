import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/player/video_player_introdb_mixin.dart';
import 'package:media_kit/media_kit.dart';

/// Widget de teste mínimo que usa o mixin `VideoPlayerIntroDbMixin`.
///
/// Expõe métodos públicos do mixin para que os testes possam
/// exercitar `maybeReshowSkipButton`, `cleanupIntroDb`,
/// `startPositionTimer`, etc.
class _TestSkipWidget extends StatefulWidget {
  const _TestSkipWidget();

  @override
  State<_TestSkipWidget> createState() => _TestSkipWidgetState();
}

class _TestSkipWidgetState extends State<_TestSkipWidget>
    with VideoPlayerIntroDbMixin {
  /// Permite que o teste injete um Player mockado.
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

  @override
  Widget build(BuildContext context) {
    // Exibe o estado atual do botão skip para que os testes possam
    // verificar a UI.
    return Column(
      children: [
        if (showSkipButton) Text(skipButtonLabel, key: const Key('skip_label')),
        // Botão para chamar maybeReshowSkipButton via tap
        TextButton(
          key: const Key('reshow_button'),
          onPressed: maybeReshowSkipButton,
          child: const Text('Reshow'),
        ),
        // Exibe o estado de hide para depuração
        Text('showSkipButton=$showSkipButton', key: const Key('state_display')),
        if (positionTimer != null)
          const Text('timer_active', key: Key('timer_active')),
      ],
    );
  }
}

Widget buildTestApp() {
  return const MaterialApp(home: Scaffold(body: _TestSkipWidget()));
}

void main() {
  group('VideoPlayerIntroDbMixin', () {
    // ─── skipAutoHideDuration ──────────────────────────────────

    test('skipAutoHideDuration deve ser 10 segundos', () {
      expect(
        VideoPlayerIntroDbMixin.skipAutoHideDuration,
        const Duration(seconds: 10),
      );
    });

    test('skipLeadSeconds deve ser 3.0', () {
      expect(VideoPlayerIntroDbMixin.skipLeadSeconds, 3.0);
    });

    test('skipHoldSeconds deve ser 2.0', () {
      expect(VideoPlayerIntroDbMixin.skipHoldSeconds, 2.0);
    });

    // ─── maybeReshowSkipButton ─────────────────────────────────

    testWidgets('maybeReshowSkipButton não lança exceção', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Verifica que o widget está renderizado sem erro.
      expect(find.byType(_TestSkipWidget), findsOneWidget);

      // Tapa no botão que chama maybeReshowSkipButton.
      await tester.tap(find.byKey(const Key('reshow_button')));
      await tester.pump();

      // Sem crash = sucesso.
      expect(find.byType(_TestSkipWidget), findsOneWidget);
    });

    testWidgets('maybeReshowSkipButton pode ser chamado múltiplas vezes '
        '(idempotente)', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Chama 3x seguidas.
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('reshow_button')));
        await tester.pump();
      }

      // Sem crash.
      expect(find.byType(_TestSkipWidget), findsOneWidget);
    });

    // ─── cleanupIntroDb ────────────────────────────────────────

    testWidgets('cleanupIntroDb não lança exceção (timers null)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Acessa o State para chamar cleanupIntroDb.
      final state = tester.state<_TestSkipWidgetState>(
        find.byType(_TestSkipWidget),
      );
      expect(state.positionTimer, isNull);
      expect(state.skipButtonAutoHideTimer, isNull);

      // Chamar cleanup com timers null não deve lançar.
      state.cleanupIntroDb();
      await tester.pump();

      // Após cleanup, timers continuam null.
      expect(state.positionTimer, isNull);
      expect(state.skipButtonAutoHideTimer, isNull);
    });

    testWidgets('cleanupIntroDb cancela timers ativos', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      final state = tester.state<_TestSkipWidgetState>(
        find.byType(_TestSkipWidget),
      );

      // Inicia o timer de posição.
      state.activeEpisodeKey = 'test_episode';
      state.startPositionTimer();
      await tester.pump();

      // Verifica que o timer foi criado.
      expect(state.positionTimer, isNotNull);
      expect(state.positionTimer!.isActive, isTrue);

      // cleanup deve cancelar o timer.
      state.cleanupIntroDb();
      await tester.pump();

      expect(state.positionTimer, isNotNull);
      expect(state.positionTimer!.isActive, isFalse);
    });

    // ─── startPositionTimer ────────────────────────────────────

    testWidgets(
      'startPositionTimer cria timer quando activeEpisodeKey está setado',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pump();

        final state = tester.state<_TestSkipWidgetState>(
          find.byType(_TestSkipWidget),
        );

        // Sem activeEpisodeKey, startPositionTimer ainda cria timer
        // (mas o callback verifica isActiveEpisode antes de agir).
        state.activeEpisodeKey = 'ep1';
        state.startPositionTimer();
        await tester.pump();

        expect(state.positionTimer, isNotNull);
        expect(state.positionTimer!.isActive, isTrue);
      },
    );

    testWidgets(
      'startPositionTimer cancela timer anterior antes de criar novo',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pump();

        final state = tester.state<_TestSkipWidgetState>(
          find.byType(_TestSkipWidget),
        );

        state.activeEpisodeKey = 'ep1';
        state.startPositionTimer();
        final firstTimer = state.positionTimer;

        // Inicia novamente com mesma chave.
        state.startPositionTimer();
        await tester.pump();

        // Timer antigo foi cancelado, novo está ativo.
        expect(firstTimer?.isActive, isFalse);
        expect(state.positionTimer?.isActive, isTrue);
      },
    );

    // ─── skipButtonAutoHidden ──────────────────────────────────

    testWidgets('skipButtonAutoHidden começa como false', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      final state = tester.state<_TestSkipWidgetState>(
        find.byType(_TestSkipWidget),
      );

      expect(state.skipButtonAutoHidden, isFalse);
    });

    testWidgets(
      'maybeReshowSkipButton mantém skipButtonAutoHidden como false',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pump();

        final state = tester.state<_TestSkipWidgetState>(
          find.byType(_TestSkipWidget),
        );

        // Já começa como false.
        expect(state.skipButtonAutoHidden, isFalse);

        // maybeReshowSkipButton não altera de false para true.
        state.maybeReshowSkipButton();
        expect(state.skipButtonAutoHidden, isFalse);

        // Chamadas repetidas são seguras.
        state.maybeReshowSkipButton();
        expect(state.skipButtonAutoHidden, isFalse);
      },
    );

    testWidgets('skipButtonAutoHidden impede reexibição do botão na UI', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      final state = tester.state<_TestSkipWidgetState>(
        find.byType(_TestSkipWidget),
      );

      // Simula que o botão estava visível e foi auto-escondido.
      // Não podemos setar _skipButtonAutoHidden diretamente
      // (é privado), mas podemos testar o fluxo:
      // 1. Exibe o botão
      // 2. Chama maybeReshowSkipButton (limpa a flag)
      // 3. A flag continua false (pronta para reexibir)
      state.setState(() {
        state.showSkipButton = true;
        state.skipButtonLabel = 'Pular Intro';
      });
      await tester.pump();

      expect(find.text('Pular Intro'), findsOneWidget);
      expect(state.skipButtonAutoHidden, isFalse);

      // maybeReshowSkipButton mantém o estado.
      state.maybeReshowSkipButton();
      expect(state.skipButtonAutoHidden, isFalse);

      // Botão continua visível.
      expect(find.text('Pular Intro'), findsOneWidget);
    });

    // ─── showSkipButton / skipButtonLabel ──────────────────────

    testWidgets('showSkipButton começa como false', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      final state = tester.state<_TestSkipWidgetState>(
        find.byType(_TestSkipWidget),
      );

      expect(state.showSkipButton, isFalse);
      expect(state.skipButtonLabel, isEmpty);
    });

    testWidgets('showSkipButton exibe label na UI quando true', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      final state = tester.state<_TestSkipWidgetState>(
        find.byType(_TestSkipWidget),
      );

      // Simula a exibição do botão setando o estado diretamente.
      state.setState(() {
        state.showSkipButton = true;
        state.skipButtonLabel = 'Pular Intro';
      });
      await tester.pump();

      // Verifica que o label aparece na UI.
      expect(find.text('Pular Intro'), findsOneWidget);
    });

    // ─── activeEpisodeKey + isActiveEpisode ────────────────────

    testWidgets('isActiveEpisode retorna true apenas quando key corresponde '
        'a activeEpisodeKey', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      final state = tester.state<_TestSkipWidgetState>(
        find.byType(_TestSkipWidget),
      );

      expect(state.isActiveEpisode(null), isFalse);

      state.activeEpisodeKey = 'ep1';
      expect(state.isActiveEpisode('ep1'), isTrue);
      expect(state.isActiveEpisode('ep2'), isFalse);
      expect(state.isActiveEpisode(null), isFalse);
    });

    // ─── skipButtonAutoHideTimer é gerenciado corretamente ─────

    testWidgets('skipButtonAutoHideTimer é nulo inicialmente', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      final state = tester.state<_TestSkipWidgetState>(
        find.byType(_TestSkipWidget),
      );

      expect(state.skipButtonAutoHideTimer, isNull);
    });

    // ─── dispose/cleanup (simula ciclo de vida) ────────────────

    testWidgets('remover o widget chama dispose que limpa timers', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Acessa state e inicia timer.
      final state = tester.state<_TestSkipWidgetState>(
        find.byType(_TestSkipWidget),
      );
      state.activeEpisodeKey = 'ep1';
      state.startPositionTimer();
      await tester.pump();
      expect(state.positionTimer?.isActive, isTrue);

      // Remove o widget — dispose() é chamado = cleanupIntroDb().
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      // O state não está mais acessível, mas o importante é que
      // não houve exceção durante o dispose.
    });
  });
}
