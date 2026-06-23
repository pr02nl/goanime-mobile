import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_models.dart';
import 'package:goanime/ui/pauloflix/widgets/pauloflix_season_selector.dart';

void main() {
  Widget buildSelector({
    required List<PauloFlixSeason> seasons,
    int selectedIndex = 0,
    Map<int, bool>? isCompletedByIndex,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PauloflixSeasonSelector(
          seasons: seasons,
          selectedIndex: selectedIndex,
          onSeasonSelected: (_) {},
          isCompletedByIndex: isCompletedByIndex,
        ),
      ),
    );
  }

  final seasons = <PauloFlixSeason>[
    const PauloFlixSeason(name: 'Season 01', url: 'https://s/1/', number: 1),
    const PauloFlixSeason(name: 'Season 02', url: 'https://s/2/', number: 2),
    const PauloFlixSeason(name: 'Season 03', url: 'https://s/3/', number: 3),
  ];

  group('PauloflixSeasonSelector — sem badge', () {
    testWidgets(
      'NÃO mostra badge quando isCompletedByIndex é null',
      (tester) async {
        await tester.pumpWidget(buildSelector(seasons: seasons));
        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(find.text('Completa'), findsNothing);
      },
    );

    testWidgets(
      'NÃO mostra badge quando isCompletedByIndex é vazio',
      (tester) async {
        await tester.pumpWidget(
          buildSelector(
            seasons: seasons,
            isCompletedByIndex: const {},
          ),
        );
        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(find.text('Completa'), findsNothing);
      },
    );
  });

  group('PauloflixSeasonSelector — com badge', () {
    testWidgets(
      'mostra badge "✓ Completa" quando index 1 tem isCompleted = true',
      (tester) async {
        await tester.pumpWidget(
          buildSelector(
            seasons: seasons,
            isCompletedByIndex: const {1: true},
          ),
        );
        // Badge "Completa" presente na season 1.
        expect(find.text('Completa'), findsOneWidget);
        // Ícone ✓ presente (na season 1).
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      },
    );

    testWidgets(
      'mostra múltiplos badges (2 seasons completas)',
      (tester) async {
        await tester.pumpWidget(
          buildSelector(
            seasons: seasons,
            isCompletedByIndex: const {0: true, 2: true},
          ),
        );
        expect(find.text('Completa'), findsNWidgets(2));
        expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      },
    );

    testWidgets(
      'NÃO mostra badge na season com isCompleted = false',
      (tester) async {
        await tester.pumpWidget(
          buildSelector(
            seasons: seasons,
            isCompletedByIndex: const {1: false},
          ),
        );
        expect(find.text('Completa'), findsNothing);
      },
    );

    testWidgets(
      'NÃO mostra badge na season sem entrada no map',
      (tester) async {
        // Map só tem season 0, season 1 não tem entrada.
        await tester.pumpWidget(
          buildSelector(
            seasons: seasons,
            isCompletedByIndex: const {0: true},
          ),
        );
        // 1 badge (season 0).
        expect(find.text('Completa'), findsOneWidget);
        // ...mas season 1 não deve ter (índice 1 não está no map).
        // Verifica que só há 1 (season 0).
      },
    );
  });

  group('PauloflixSeasonSelector — comportamento geral', () {
    testWidgets(
      'selectedIndex destaca a temporada selecionada (independente do badge)',
      (tester) async {
        await tester.pumpWidget(
          buildSelector(
            seasons: seasons,
            selectedIndex: 1, // season 2 selecionada
            isCompletedByIndex: const {0: true},
          ),
        );
        // O badge é da season 0 (completa), mas selectedIndex = 1.
        expect(find.text('Completa'), findsOneWidget);
        // A label "S02" deve aparecer (season 2 selecionada).
        expect(find.text('S02'), findsOneWidget);
      },
    );
  });
}
