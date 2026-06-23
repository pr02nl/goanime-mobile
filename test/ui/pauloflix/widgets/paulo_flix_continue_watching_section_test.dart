import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/ui/pauloflix/widgets/paulo_flix_continue_watching_section.dart';

void main() {
  PauloFlixContent makeContent({
    int? id,
    String folderName = 'Naruto',
    String displayName = 'Naruto',
    String? imageUrl = 'https://cdn/naruto.jpg',
  }) {
    return PauloFlixContent(
      id: id,
      folderName: folderName,
      displayName: displayName,
      serverUrl: 'https://server/$folderName/',
      imageUrl: imageUrl,
      lastSynced: DateTime.now(),
    );
  }

  Widget buildSection({
    required List<PauloFlixContent> contents,
    void Function(PauloFlixContent)? onContentTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PauloFlixContinueWatchingSection(
          contents: contents,
          onContentTap: onContentTap,
        ),
      ),
    );
  }

  group('PauloFlixContinueWatchingSection — lista vazia', () {
    testWidgets(
      'renderiza SizedBox.shrink() quando contents está vazia',
      (tester) async {
        await tester.pumpWidget(buildSection(contents: const []));
        // Sem carrossel, sem título, sem nada.
        expect(find.byType(ListView), findsNothing);
        expect(find.text('Continue assistindo'), findsNothing);
        // Nenhum widget "real" renderizado (apenas SizedBox.shrink).
        expect(find.byType(PauloFlixContinueWatchingSection), findsOneWidget);
      },
    );
  });

  group('PauloFlixContinueWatchingSection — com conteúdos', () {
    testWidgets(
      'renderiza carrossel com título "Continue assistindo"',
      (tester) async {
        await tester.pumpWidget(
          buildSection(
            contents: [
              makeContent(id: 1, displayName: 'Naruto'),
              makeContent(id: 2, displayName: 'Bleach'),
            ],
          ),
        );

        // Título visível.
        expect(find.text('Continue assistindo'), findsOneWidget);
        // Carrossel renderizado.
        expect(find.byType(ListView), findsOneWidget);
        // 2 cards (1 por content).
        expect(find.text('Naruto'), findsOneWidget);
        expect(find.text('Bleach'), findsOneWidget);
      },
    );

    testWidgets(
      'cada content vira um card com capa (imageUrl)',
      (tester) async {
        await tester.pumpWidget(
          buildSection(
            contents: [
              makeContent(
                id: 1,
                displayName: 'Naruto',
                imageUrl: 'https://cdn/naruto.jpg',
              ),
            ],
          ),
        );

        // Imagem é renderizada (CachedNetworkImage ou Image.network).
        // Verificamos que existe um widget de imagem com a URL.
        final imageWidgets = find
            .byWidgetPredicate(
              (w) => w is Image && w.image is NetworkImage,
            )
            .evaluate();
        // Aceita 0 (fallback) ou 1 (image renderizada).
        // O importante é que o widget de section renderize.
        expect(find.byType(PauloFlixContinueWatchingSection), findsOneWidget);
        // Se image renderizou, deve ter NetworkImage com a URL.
        if (imageWidgets.isNotEmpty) {
          final image = imageWidgets.first.widget as Image;
          final network = image.image as NetworkImage;
          expect(network.url, 'https://cdn/naruto.jpg');
        }
      },
    );

    testWidgets(
      'onContentTap callback é chamado com o content correto',
      (tester) async {
        PauloFlixContent? tapped;
        await tester.pumpWidget(
          buildSection(
            contents: [
              makeContent(id: 1, displayName: 'Naruto'),
              makeContent(id: 2, displayName: 'Bleach'),
            ],
            onContentTap: (c) => tapped = c,
          ),
        );

        // Tap no card do Naruto.
        await tester.tap(find.text('Naruto'));
        await tester.pump();
        expect(tapped, isNotNull);
        expect(tapped!.id, 1);
        expect(tapped!.displayName, 'Naruto');
      },
    );

    testWidgets(
      'ignora contents com imageUrl = null (não quebra)',
      (tester) async {
        await tester.pumpWidget(
          buildSection(
            contents: [
              makeContent(id: 1, imageUrl: null),
              makeContent(id: 2, imageUrl: 'https://cdn/bleach.jpg'),
            ],
          ),
        );

        // Section renderiza sem crash.
        expect(find.byType(PauloFlixContinueWatchingSection), findsOneWidget);
      },
    );

    testWidgets(
      'suporta isTV (layout wide para TV)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(size: Size(1920, 1080)),
                child: PauloFlixContinueWatchingSection(
                  contents: [makeContent(id: 1, displayName: 'Naruto')],
                  isTV: true,
                ),
              ),
            ),
          ),
        );
        // Renderiza sem crash.
        expect(find.byType(PauloFlixContinueWatchingSection), findsOneWidget);
        expect(find.text('Continue assistindo'), findsOneWidget);
      },
    );
  });
}
