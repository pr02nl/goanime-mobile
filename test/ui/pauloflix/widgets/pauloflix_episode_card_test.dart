import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_models.dart';
import 'package:goanime/ui/pauloflix/widgets/pauloflix_episode_card.dart';

void main() {
  Widget buildCard({
    PauloFlixEpisode? episode,
    int? positionSeconds,
    int? durationSeconds,
    bool isCompleted = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PauloflixEpisodeCard(
          episode: episode ??
              const PauloFlixEpisode(
                number: 1,
                title: 'Naruto Returns',
                url: 'https://server/ep1.mkv',
              ),
          seasonNumber: 1,
          onTap: () {},
          positionSeconds: positionSeconds,
          durationSeconds: durationSeconds,
          isCompleted: isCompleted,
        ),
      ),
    );
  }

  group('PauloflixEpisodeCard — sem progresso', () {
    testWidgets('não mostra barra nem ícone ✓ quando sem progresso', (
      tester,
    ) async {
      await tester.pumpWidget(buildCard());

      // Sem positionSeconds/durationSeconds/isCompleted: card "virgem".
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // Sem ícone verde (✓ do "Completo").
      expect(
        find.byIcon(Icons.check_circle).evaluate(),
        isEmpty,
        reason: 'sem ícone check_circle quando sem progresso',
      );
    });
  });

  group('PauloflixEpisodeCard — em progresso (parcial)', () {
    testWidgets(
      'mostra barra de progresso quando position > 0 e !isCompleted',
      (tester) async {
        await tester.pumpWidget(
          buildCard(
            positionSeconds: 720, // 12min de 24min = 50%
            durationSeconds: 1440,
          ),
        );

        // Barra de progresso presente.
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // Sem ícone "Completo" (texto).
        expect(find.text('Completo'), findsNothing);
      },
    );

    testWidgets(
      'NÃO mostra barra se position = 0 (não assistiu)',
      (tester) async {
        await tester.pumpWidget(
          buildCard(
            positionSeconds: 0,
            durationSeconds: 1440,
          ),
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.text('Completo'), findsNothing);
      },
    );

    testWidgets(
      'NÃO mostra barra se isCompleted = true (mostra ✓)',
      (tester) async {
        await tester.pumpWidget(
          buildCard(
            positionSeconds: 1440,
            durationSeconds: 1440,
            isCompleted: true,
          ),
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        // Texto "Completo" presente.
        expect(find.text('Completo'), findsOneWidget);
      },
    );
  });

  group('PauloflixEpisodeCard — completo', () {
    testWidgets('mostra indicador "Completo" quando isCompleted = true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(
          positionSeconds: 1440,
          durationSeconds: 1440,
          isCompleted: true,
        ),
      );
      expect(find.text('Completo'), findsOneWidget);
      // Ícone ✓ no botão (verde grande) + indicador (verde pequeno).
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    });

    testWidgets(
      'NÃO mostra indicador "Completo" se isCompleted = false (mesmo position 100%)',
      (tester) async {
        // Edge case: posição = 100% mas isCompleted ainda false
        // (save antes do recompute). Deve mostrar barra cheia, não ✓.
        await tester.pumpWidget(
          buildCard(
            positionSeconds: 1440,
            durationSeconds: 1440,
            isCompleted: false,
          ),
        );
        expect(find.text('Completo'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );
  });
}
