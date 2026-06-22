import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/core/utils/pagination.dart';
import 'package:goanime/ui/core/widgets/paginated_letter_grid.dart';

/// Item dummy usado para testar o `PaginatedLetterGrid` genérico sem
/// depender de `PauloFlixMovie` ou `PauloFlixContent`.
class _TestItem {
  final String name;
  const _TestItem(this.name);
}

PaginationResult<_TestItem> _buildPagination(List<_TestItem> items,
    {int perPage = 24}) {
  if (items.isEmpty) {
    return const PaginationResult<_TestItem>(
      pages: [],
      letterToPageIndex: {},
      availableLetters: [],
    );
  }
  final pages = <List<_TestItem>>[];
  for (var i = 0; i < items.length; i += perPage) {
    final end = i + perPage > items.length ? items.length : i + perPage;
    pages.add(items.sublist(i, end));
  }
  final letterToPageIndex = <String, int>{};
  for (var i = 0; i < pages.length; i++) {
    for (final item in pages[i]) {
      if (item.name.isEmpty) continue;
      final first = item.name[0].toUpperCase();
      letterToPageIndex.putIfAbsent(first, () => i);
    }
  }
  return PaginationResult<_TestItem>(
    pages: pages,
    letterToPageIndex: letterToPageIndex,
    availableLetters: letterToPageIndex.keys.toList(),
  );
}

void main() {
  group('PaginatedLetterGrid', () {
    testWidgets('com pages vazias retorna SizedBox.shrink', (tester) async {
      const empty = PaginationResult<int>(
        pages: [],
        letterToPageIndex: {},
        availableLetters: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedLetterGrid<int>(
              pagination: empty,
              cardBuilder: (_, i) => Text('$i'),
              nameOf: (i) => '$i',
            ),
          ),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renderiza primeira página com cards', (tester) async {
      final pagination = _buildPagination([
        const _TestItem('Apple'),
        const _TestItem('Banana'),
        const _TestItem('Cherry'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedLetterGrid<_TestItem>(
              pagination: pagination,
              cardBuilder: (_, item) => Text(item.name),
              nameOf: (item) => item.name,
            ),
          ),
        ),
      );
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Cherry'), findsOneWidget);
    });

    testWidgets(
      'PageView com várias páginas: primeira página é a inicial',
      (tester) async {
        // Viewport grande o suficiente para não dar overflow.
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pagination = _buildPagination(
          List.generate(
            50,
            (i) => _TestItem('Item ${i.toString().padLeft(2, '0')}'),
          ),
          perPage: 10,
        );
        expect(pagination.pages.length, 5);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PaginatedLetterGrid<_TestItem>(
                pagination: pagination,
                cardBuilder: (_, item) => SizedBox(
                  width: 100,
                  height: 50,
                  child: Text(item.name),
                ),
                nameOf: (item) => item.name,
              ),
            ),
          ),
        );

        // Primeira página: Item 00 a Item 09 visíveis.
        expect(find.text('Item 00'), findsOneWidget);
        expect(find.text('Item 09'), findsOneWidget);
        // Item 10 NÃO está visível ainda (outra página).
        expect(find.text('Item 10'), findsNothing);
      },
    );

    testWidgets('PageIndicator mostra "Pág. X de Y" no formato correto',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pagination = _buildPagination(
        List.generate(50, (i) => _TestItem('M$i')),
        perPage: 10,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedLetterGrid<_TestItem>(
              pagination: pagination,
              cardBuilder: (_, item) => Text(item.name),
              nameOf: (item) => item.name,
            ),
          ),
        ),
      );
      expect(find.text('Pág. 1 de 5'), findsOneWidget);
    });

    testWidgets('accentColor customizada aparece no PageIndicator',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pagination = _buildPagination(
        List.generate(10, (i) => _TestItem('M$i')),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedLetterGrid<_TestItem>(
              pagination: pagination,
              accentColor: const Color(0xFF00FF00),
              cardBuilder: (_, item) => Text(item.name),
              nameOf: (item) => item.name,
            ),
          ),
        ),
      );
      // Verifica que o accentColor foi aplicado.
      final indicator = find.text('Pág. 1 de 1');
      expect(indicator, findsOneWidget);
      // O TextStyle do indicator usa accentColor.
      final textWidget = tester.widget<Text>(indicator);
      expect(textWidget.style!.color, const Color(0xFF00FF00));
    });
  });
}
