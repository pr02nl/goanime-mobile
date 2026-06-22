import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/repositories/pauloflix_repository.dart';
import 'package:goanime/ui/pauloflix/view_models/pauloflix_provider.dart';
import 'package:goanime/ui/pauloflix/widgets/pauloflix_search_screen.dart';

/// Fake do [PauloFlixRepository] — fornece dados em memória sem tocar
/// no disco. Suficiente para popular o [PauloFlixProvider] em testes.
class _FakePauloFlixRepository implements PauloFlixRepository {
  final List<PauloFlixContent> fakeData;

  _FakePauloFlixRepository(this.fakeData);

  @override
  Future<List<PauloFlixContent>> getAll() async => fakeData;

  @override
  Future<List<PauloFlixContent>> searchByName(String query) async => fakeData;
  @override
  Future<PauloFlixContent?> getByFolderName(String folderName) async => null;
  @override
  Future<PauloFlixContent?> getByMalId(int malId) async => null;
  @override
  Future<void> saveContent(PauloFlixContent content) async {}
  @override
  Future<void> saveBatch(List<PauloFlixContent> contents) async {}
  @override
  Future<void> markAsUnavailable(String folderName) async {}
  @override
  Future<Map<String, int>> getStats() async =>
      {'total': 0, 'available': 0, 'withMetadata': 0};
  @override
  Stream<List<PauloFlixContent>> watch() => const Stream.empty();
}

PauloFlixContent _anime({
  required String folderName,
  required String displayName,
  List<String> genres = const [],
  int? malId,
}) {
  return PauloFlixContent(
    folderName: folderName,
    displayName: displayName,
    serverUrl: 'http://server/$folderName/',
    genres: genres,
    malId: malId,
  );
}

void main() {
  // Dados de fixture compartilhados entre os testes.
  final testAnimes = [
    _anime(
      folderName: 'Naruto',
      displayName: 'Naruto',
      genres: ['Action', 'Adventure'],
      malId: 20,
    ),
    _anime(
      folderName: 'One Piece',
      displayName: 'One Piece',
      genres: ['Action', 'Comedy'],
      malId: 21,
    ),
    _anime(
      folderName: 'Shingeki no Kyojin',
      displayName: 'Shingeki no Kyojin',
      genres: ['Action', 'Drama'],
      malId: 22,
    ),
  ];

  group('PauloFlixSearchScreen.applyFilter', () {
    test('query vazia retorna lista original (sem filtro)', () {
      final result = PauloFlixSearchScreen.applyFilter(
        testAnimes,
        '',
      );
      expect(result, testAnimes);
    });

    test('busca por nome é case-insensitive', () {
      final result = PauloFlixSearchScreen.applyFilter(
        testAnimes,
        'naruto',
      );
      expect(result, hasLength(1));
      expect(result.first.folderName, 'Naruto');
    });

    test('busca por nome aceita letras maiúsculas e minúsculas', () {
      // O caller (State) normaliza com toLowerCase().trim() antes de
      // chamar applyFilter — então o teste simula esse pré-processamento.
      final resultLower = PauloFlixSearchScreen.applyFilter(
        testAnimes,
        'naruto'.toLowerCase().trim(),
      );
      final resultUpper = PauloFlixSearchScreen.applyFilter(
        testAnimes,
        'NARUTO'.toLowerCase().trim(),
      );
      expect(resultLower, hasLength(1));
      expect(resultUpper, hasLength(1));
      expect(resultLower.first.folderName, 'Naruto');
      expect(resultUpper.first.folderName, 'Naruto');
    });

    test('busca por gênero retorna animes do gênero', () {
      // Pre-normalizado: 'comedy' já é minúsculo.
      final result = PauloFlixSearchScreen.applyFilter(
        testAnimes,
        'comedy'.toLowerCase().trim(),
      );
      expect(result, hasLength(1));
      expect(result.first.folderName, 'One Piece');
    });

    test('busca por substring do nome funciona (match parcial)', () {
      final result = PauloFlixSearchScreen.applyFilter(
        testAnimes,
        'piece'.toLowerCase().trim(),
      );
      expect(result, hasLength(1));
      expect(result.first.folderName, 'One Piece');
    });

    test('busca por gênero compartilhado retorna múltiplos animes', () {
      // "action" está em Naruto, One Piece e Shingeki no Kyojin
      final result = PauloFlixSearchScreen.applyFilter(
        testAnimes,
        'action'.toLowerCase().trim(),
      );
      expect(result, hasLength(3));
    });

    test('busca sem matches retorna lista vazia', () {
      final result = PauloFlixSearchScreen.applyFilter(
        testAnimes,
        'xyz123'.toLowerCase().trim(),
      );
      expect(result, isEmpty);
    });

    test('filtro não muta a lista original (imutabilidade)', () {
      final originalLength = testAnimes.length;
      PauloFlixSearchScreen.applyFilter(
        testAnimes,
        'naruto'.toLowerCase().trim(),
      );
      expect(testAnimes, hasLength(originalLength));
    });
  });

  group('PauloFlixProvider — integração com search screen', () {
    test(
      'loadContents popula contents e search() filtra o estado global',
      () async {
        final provider = PauloFlixProvider.withRepository(
          _FakePauloFlixRepository([...testAnimes]),
        );
        await provider.loadContents();
        expect(provider.contents, hasLength(3));

        // provider.search() filtra o estado GLOBAL — é o que a search
        // screen DEVE EVITAR fazer (anti-pattern #12). Aqui só
        // documentamos o comportamento existente do provider.
        provider.search('naruto');
        await Future.delayed(const Duration(milliseconds: 400));
        expect(provider.contents, hasLength(1));
        expect(provider.contents.first.folderName, 'Naruto');
      },
    );

    test(
      'carga inicial do provider retorna a lista completa (3 animes)',
      () async {
        final provider = PauloFlixProvider.withRepository(
          _FakePauloFlixRepository([...testAnimes]),
        );
        await provider.loadContents();
        expect(provider.contents, hasLength(3));
      },
    );
  });

  group('Snapshot local — comportamento esperado na search screen', () {
    test('List.from() cria cópia defensiva (mutação não propaga)', () {
      // A search screen usa `List<PauloFlixContent>.from(provider.contents)`
      // para criar o snapshot local. Se a lista retornada pelo provider
      // fosse mutada, o snapshot não deveria ser afetado.
      final source = [...testAnimes];
      final snapshot = List<PauloFlixContent>.from(source);

      // Simula mudança no provider (sync, filtro, etc).
      source.clear();
      source.add(_anime(
        folderName: 'New',
        displayName: 'New Anime',
      ));

      // Snapshot mantém os dados originais.
      expect(snapshot, hasLength(3));
      expect(
        snapshot.map((c) => c.folderName).toSet(),
        {'Naruto', 'One Piece', 'Shingeki no Kyojin'},
      );
    });

    test('filtro sobre snapshot não afeta a lista-fonte', () {
      final source = [...testAnimes];
      final snapshot = List<PauloFlixContent>.from(source);

      // Aplica filtro (o que a search screen faria ao digitar).
      final filtered = PauloFlixSearchScreen.applyFilter(
        snapshot,
        'naruto',
      );

      // Source e snapshot permanecem inalterados.
      expect(source, hasLength(3));
      expect(snapshot, hasLength(3));
      // Filtered tem apenas 1 resultado.
      expect(filtered, hasLength(1));
    });
  });

  // Smoke test: garantir que a tela pode ser instanciada sem crashar
  // (TextField + Provider + SliverAppBar). Não verifica interação de
  // teclado físico — apenas que o widget monta.
  testWidgets('PauloFlixSearchScreen monta sem erros com provider vazio', (
    tester,
  ) async {
    final provider = PauloFlixProvider.withRepository(
      _FakePauloFlixRepository([]),
    );
    await provider.loadContents();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<PauloFlixProvider>.value(
          value: provider,
          child: const PauloFlixSearchScreen(),
        ),
      ),
    );

    // Aguarda o post-frame callback do initState.
    await tester.pump();

    // SliverAppBar + TextField presentes.
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
