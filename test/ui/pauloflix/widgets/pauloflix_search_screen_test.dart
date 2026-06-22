import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/repositories/pauloflix_repository.dart';
import 'package:goanime/ui/pauloflix/view_models/pauloflix_provider.dart';
import 'package:goanime/ui/pauloflix/widgets/pauloflix_search_screen.dart';

/// Fake do [PauloFlixRepository] — fornece dados em memória sem tocar
/// no disco. Suficiente para popular o [PauloFlixProvider] em testes.
///
/// O comportamento padrão de [searchByName] é devolver a lista inteira
/// — para testes mais finos, o caller pode passar `searchByNameFilter`
/// (função que decide o que devolver com base na query).
class _FakePauloFlixRepository implements PauloFlixRepository {
  final List<PauloFlixContent> fakeData;
  final Future<List<PauloFlixContent>> Function(String query)?
  searchByNameFilter;

  _FakePauloFlixRepository(this.fakeData, {this.searchByNameFilter});

  @override
  Future<List<PauloFlixContent>> getAll() async => fakeData;

  @override
  Future<List<PauloFlixContent>> searchByName(String query) async {
    if (searchByNameFilter != null) return searchByNameFilter!(query);
    return fakeData;
  }

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

  // Filtro in-memory usado pelo fake para simular o `LIKE` do SQL.
  // O fake reproduz o comportamento do `PauloFlixRepositoryImpl.searchByName`
  // (case-insensitive em displayName E em qualquer gênero).
  List<PauloFlixContent> fakeSqlFilter(
    List<PauloFlixContent> data,
    String query,
  ) {
    if (query.isEmpty) return const [];
    final q = query.toLowerCase();
    return data.where((c) {
      return c.displayName.toLowerCase().contains(q) ||
          c.genres.any((g) => g.toLowerCase().contains(q));
    }).toList();
  }

  group('PauloFlixProvider.searchByName (delega ao repository)', () {
    test('query vazia retorna lista vazia (sem chamar SQL)', () async {
      final provider = PauloFlixProvider.withRepository(
        _FakePauloFlixRepository([...testAnimes]),
      );
      final result = await provider.searchByName('');
      expect(result, isEmpty);
    });

    test('query com whitespace só retorna lista vazia', () async {
      final provider = PauloFlixProvider.withRepository(
        _FakePauloFlixRepository([...testAnimes]),
      );
      final result = await provider.searchByName('   ');
      expect(result, isEmpty);
    });

    test('busca por nome é case-insensitive (via SQL LIKE)', () async {
      final provider = PauloFlixProvider.withRepository(
        _FakePauloFlixRepository(
          [...testAnimes],
          searchByNameFilter: (q) async => fakeSqlFilter(testAnimes, q),
        ),
      );
      final result = await provider.searchByName('naruto');
      expect(result, hasLength(1));
      expect(result.first.folderName, 'Naruto');
    });

    test('busca por nome aceita letras maiúsculas e minúsculas', () async {
      // O provider.searchByName NÃO normaliza (é o caller/State que
      // faz isso). Aqui validamos que o repository (faked) lida com
      // ambas as variações via LIKE case-insensitive.
      final provider = PauloFlixProvider.withRepository(
        _FakePauloFlixRepository(
          [...testAnimes],
          searchByNameFilter: (q) async => fakeSqlFilter(testAnimes, q),
        ),
      );
      final resultLower = await provider.searchByName('naruto');
      final resultUpper = await provider.searchByName('NARUTO');
      expect(resultLower, hasLength(1));
      expect(resultUpper, hasLength(1));
      expect(resultLower.first.folderName, 'Naruto');
      expect(resultUpper.first.folderName, 'Naruto');
    });

    test('busca por gênero retorna animes do gênero', () async {
      final provider = PauloFlixProvider.withRepository(
        _FakePauloFlixRepository(
          [...testAnimes],
          searchByNameFilter: (q) async => fakeSqlFilter(testAnimes, q),
        ),
      );
      final result = await provider.searchByName('comedy');
      expect(result, hasLength(1));
      expect(result.first.folderName, 'One Piece');
    });

    test('busca por substring do nome funciona (match parcial)', () async {
      final provider = PauloFlixProvider.withRepository(
        _FakePauloFlixRepository(
          [...testAnimes],
          searchByNameFilter: (q) async => fakeSqlFilter(testAnimes, q),
        ),
      );
      final result = await provider.searchByName('piece');
      expect(result, hasLength(1));
      expect(result.first.folderName, 'One Piece');
    });

    test('busca por gênero compartilhado retorna múltiplos animes', () async {
      // "action" está em Naruto, One Piece e Shingeki no Kyojin
      final provider = PauloFlixProvider.withRepository(
        _FakePauloFlixRepository(
          [...testAnimes],
          searchByNameFilter: (q) async => fakeSqlFilter(testAnimes, q),
        ),
      );
      final result = await provider.searchByName('action');
      expect(result, hasLength(3));
    });

    test('busca sem matches retorna lista vazia', () async {
      final provider = PauloFlixProvider.withRepository(
        _FakePauloFlixRepository(
          [...testAnimes],
          searchByNameFilter: (q) async => fakeSqlFilter(testAnimes, q),
        ),
      );
      final result = await provider.searchByName('xyz123');
      expect(result, isEmpty);
    });

    test('busca não muta a lista do provider (imutabilidade)', () async {
      final provider = PauloFlixProvider.withRepository(
        _FakePauloFlixRepository([...testAnimes]),
      );
      await provider.loadContents();
      final before = provider.contents.length;
      await provider.searchByName('naruto');
      // searchByName NÃO toca no estado do provider — só lê.
      expect(provider.contents, hasLength(before));
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

  // Smoke test: garantir que a tela pode ser instanciada sem crashar
  // (TextField + Provider + SliverAppBar). Não verifica interação de
  // teclado físico — apenas que o widget monta.
  //
  // A tela agora inicia VAZIA (sem snapshot, sem spinner de load). Só
  // carrega o _isTV via post-frame callback. Verificamos que o
  // TextField e o SliverAppBar estão presentes.
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

    // Aguarda o post-frame callback do initState (detecção de TV).
    await tester.pump();

    // SliverAppBar + TextField presentes.
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
    'PauloFlixSearchScreen mostra empty state "Digite para buscar" sem query',
    (tester) async {
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
      await tester.pump();

      // Empty state inicial.
      expect(find.text('Digite para buscar animes'), findsOneWidget);
    },
  );
}
