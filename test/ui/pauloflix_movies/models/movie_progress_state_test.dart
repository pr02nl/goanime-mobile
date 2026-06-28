import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/pauloflix_movies/models/movie_progress_state.dart';

void main() {
  group('MovieProgressState.buildOverlayWidget', () {
    test('deve retornar null quando progress é null', () {
      final widget = MovieProgressState.buildOverlayWidget(null);
      expect(widget, isNull);
    });

    test('deve retornar null quando ratio=0 e isCompleted=false', () {
      const state = MovieProgressState(ratio: 0.0, isCompleted: false);
      final widget = MovieProgressState.buildOverlayWidget(state);
      expect(widget, isNull);
    });

    testWidgets('deve exibir barra de progresso vermelha quando em andamento', (
      tester,
    ) async {
      const redColor = Color(0xFFDC2626);
      const state = MovieProgressState(ratio: 0.5, isCompleted: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MovieProgressState.buildOverlayWidget(state)!),
        ),
      );

      // Deve encontrar a barra de progresso
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // NÃO deve encontrar badge de completo
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('Completo'), findsNothing);

      // Verifica a cor vermelha dos filmes
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final animation = indicator.valueColor;
      expect(animation, isA<AlwaysStoppedAnimation<Color>>());
      final stopped = animation as AlwaysStoppedAnimation<Color>;
      expect(stopped.value, redColor);
    });

    testWidgets('deve exibir badge verde quando isCompleted=true', (
      tester,
    ) async {
      const state = MovieProgressState(ratio: 1.0, isCompleted: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MovieProgressState.buildOverlayWidget(state)!),
        ),
      );

      // Deve encontrar o badge de completo
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Completo'), findsOneWidget);
      // NÃO deve encontrar barra de progresso
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    test('deve propagar ratio e isCompleted corretamente para ProgressOverlay', () {
      // ProgressOverlay retorna null quando ratio=0 (sem delegar a CompletedBadge)
      // Esta é a prova de que a delegação acontece: ProgressOverlay decide o visual,
      // MovieProgressState apenas passa os parâmetros.
      const state1 = MovieProgressState(ratio: 0.0, isCompleted: false);
      expect(MovieProgressState.buildOverlayWidget(state1), isNull);

      const state2 = MovieProgressState(ratio: 0.0, isCompleted: true);
      expect(MovieProgressState.buildOverlayWidget(state2), isNotNull);
    });
  });
}
