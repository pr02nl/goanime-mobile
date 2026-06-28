import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/core/widgets/completed_badge.dart';

void main() {
  group('CompletedBadge.cardOverlay', () {
    testWidgets('deve exibir ícone check_circle e texto "Completo"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.cardOverlay())),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Completo'), findsOneWidget);
    });

    testWidgets('deve ter fundo verde sólido (90% opaco)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.cardOverlay())),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      // Mesma expressão usada no construtor
      expect(decoration.color, Colors.green.withValues(alpha: 0.9));
      // Sem borda
      expect(decoration.border, isNull);
    });

    testWidgets('deve ter padding pequeno e borderRadius 4', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.cardOverlay())),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(
        container.padding,
        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(4));
    });

    testWidgets('deve ter ícone e texto brancos com fontSize 9', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.cardOverlay())),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, Colors.white);
      expect(icon.size, 10);

      final textWidget = tester.widget<Text>(find.text('Completo'));
      expect(textWidget.style?.color, Colors.white);
      expect(textWidget.style?.fontSize, 9);
      expect(textWidget.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('deve ser um Row com 3 children (Icon + SizedBox + Text)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.cardOverlay())),
      );

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.children.length, 3);
      expect(row.children[0], isA<Icon>());
      expect(row.children[1], isA<SizedBox>());
      expect(row.children[2], isA<Text>());
    });
  });

  group('CompletedBadge.heroBanner', () {
    testWidgets('deve exibir ícone check_circle e texto "Completo"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.heroBanner())),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Completo'), findsOneWidget);
    });

    testWidgets('deve ter fundo verde sólido com borda greenAccent', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.heroBanner())),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      // Mesma expressão usada no construtor
      expect(decoration.color, Colors.green.withValues(alpha: 0.9));

      // Borda greenAccent 50% — mesma expressão do construtor
      expect(decoration.border, isA<Border>());
      final border = decoration.border as Border;
      expect(border.left.color, Colors.greenAccent.withValues(alpha: 0.5));
    });

    testWidgets('deve ter padding maior e borderRadius 6', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.heroBanner())),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(
        container.padding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(6));
    });

    testWidgets('deve ter ícone e texto brancos com fontSize 13 e bold', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.heroBanner())),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, Colors.white);
      expect(icon.size, 16);

      final textWidget = tester.widget<Text>(find.text('Completo'));
      expect(textWidget.style?.color, Colors.white);
      expect(textWidget.style?.fontSize, 13);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('deve ter gap de 6 entre ícone e texto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.heroBanner())),
      );

      final row = tester.widget<Row>(find.byType(Row));
      final sizedBox = row.children[1] as SizedBox;
      expect(sizedBox.width, 6);
    });
  });

  group('CompletedBadge.detailScreen', () {
    testWidgets('deve exibir ícone check_circle e texto "Completo"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.detailScreen())),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Completo'), findsOneWidget);
    });

    testWidgets(
      'deve ter fundo verde translúcido (20%) com borda verde (50%)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: CompletedBadge.detailScreen())),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        // Mesmas expressões usadas no construtor
        expect(decoration.color, Colors.green.withValues(alpha: 0.2));

        final border = decoration.border as Border;
        expect(border.left.color, Colors.green.withValues(alpha: 0.5));
      },
    );

    testWidgets('deve ter ícone e texto verdes com fontSize 12', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.detailScreen())),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
      expect(icon.color, Colors.green);
      expect(icon.size, 14);

      final textWidget = tester.widget<Text>(find.text('Completo'));
      expect(textWidget.style?.color, Colors.green);
      expect(textWidget.style?.fontSize, 12);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('deve ter gap de 4 entre ícone e texto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.detailScreen())),
      );

      final row = tester.widget<Row>(find.byType(Row));
      final sizedBox = row.children[1] as SizedBox;
      expect(sizedBox.width, 4);
    });

    testWidgets('deve ter padding: horizontal 8, vertical 4', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CompletedBadge.detailScreen())),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(
        container.padding,
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      );
    });
  });

  group('CompletedBadge (custom)', () {
    testWidgets(
      'deve aceitar parâmetros customizados via construtor primário',
      (tester) async {
        const customBadge = CompletedBadge(
          padding: EdgeInsets.all(20),
          backgroundColor: Colors.purple,
          borderRadius: 10,
          icon: Icons.star,
          iconColor: Colors.amber,
          iconSize: 24,
          gap: 8,
          label: 'Custom',
          textColor: Colors.amber,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        );

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: customBadge)),
        );

        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.text('Custom'), findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, const EdgeInsets.all(20));

        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, Colors.purple);
        expect(decoration.borderRadius, BorderRadius.circular(10));

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.color, Colors.amber);
        expect(icon.size, 24);

        final textWidget = tester.widget<Text>(find.text('Custom'));
        expect(textWidget.style?.color, Colors.amber);
        expect(textWidget.style?.fontSize, 16);
        expect(textWidget.style?.fontWeight, FontWeight.w400);
      },
    );
  });
}
