import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/core/widgets/progress_overlay.dart';

void main() {
  group('ProgressOverlay.build', () {
    test('deve retornar null quando ratio=0 e isCompleted=false', () {
      final widget = ProgressOverlay.build(
        ratio: 0.0,
        isCompleted: false,
      );
      expect(widget, isNull);
    });

    test('deve retornar null quando ratio=0 e isCompleted=false com accentColor', () {
      final widget = ProgressOverlay.build(
        ratio: 0.0,
        isCompleted: false,
        accentColor: const Color(0xFF6366F1),
      );
      expect(widget, isNull);
    });

    testWidgets('deve exibir badge verde quando isCompleted=true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressOverlay.build(
              ratio: 1.0,
              isCompleted: true,
            )!,
          ),
        ),
      );

      // Deve encontrar o ícone de check
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // Deve encontrar o texto "Completo"
      expect(find.text('Completo'), findsOneWidget);
      // NÃO deve encontrar barra de progresso
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('deve exibir badge verde quando isCompleted=true com fractionText', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressOverlay.build(
              ratio: 0.5,
              isCompleted: true,
              fractionText: '5/12',
            )!,
          ),
        ),
      );

      // Deve exibir badge (isCompleted domina sobre ratio>0)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Completo'), findsOneWidget);
      // NÃO deve mostrar fractionText (completo domina)
      expect(find.text('5/12'), findsNothing);
      // NÃO deve ter barra de progresso
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('deve exibir barra de progresso quando ratio>0 e isCompleted=false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressOverlay.build(
              ratio: 0.5,
              isCompleted: false,
            )!,
          ),
        ),
      );

      // Deve encontrar a barra de progresso
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // NÃO deve encontrar badge de completo
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('Completo'), findsNothing);
    });

    testWidgets('deve exibir cor do accentColor na barra de progresso',
        (tester) async {
      const purpleColor = Color(0xFF6366F1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressOverlay.build(
              ratio: 0.3,
              isCompleted: false,
              accentColor: purpleColor,
            )!,
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      // Verifica que a cor do valueColor é a passada como accentColor
      final animation = indicator.valueColor;
      expect(animation, isA<AlwaysStoppedAnimation<Color>>());
      final stopped = animation as AlwaysStoppedAnimation<Color>;
      expect(stopped.value, purpleColor);
    });

    testWidgets('deve exibir fractionText quando fornecido e ratio>0',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressOverlay.build(
              ratio: 0.25,
              isCompleted: false,
              fractionText: '3/12',
            )!,
          ),
        ),
      );

      // Deve encontrar o texto da fração
      expect(find.text('3/12'), findsOneWidget);
      // Deve encontrar a barra de progresso
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('deve exibir LinearProgressIndicator com o valor de ratio correto',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressOverlay.build(
              ratio: 0.75,
              isCompleted: false,
            )!,
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      expect(indicator.value, 0.75);
    });

    testWidgets('deve ser um Column com children quando ratio>0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressOverlay.build(
              ratio: 0.5,
              isCompleted: false,
              fractionText: '6/12',
            )!,
          ),
        ),
      );

      // Verifica que o widget raiz é uma Column
      expect(find.byType(Column), findsOneWidget);

      final column = tester.widget<Column>(find.byType(Column));
      // Deve ter 3 children: SizedBox(progress) + SizedBox(spacer) + Text
      expect(column.children.length, 3);
    });

    testWidgets('deve ser SizedBox com LinearProgressIndicator quando ratio>0 sem fractionText',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressOverlay.build(
              ratio: 0.5,
              isCompleted: false,
            )!,
          ),
        ),
      );

      // Sem fractionText, o wrapper é uma Column com 1 child (apenas o SizedBox da barra)
      final column = tester.widget<Column>(find.byType(Column));
      expect(column.children.length, 1);
      // A barra ainda existe
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
