import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/repositories/pauloflix_repository.dart';
import 'package:goanime/ui/pauloflix/view_models/pauloflix_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake do repository (Fase 3) — retorna dados em memória.
class FakePauloFlixRepository implements PauloFlixRepository {
  final List<PauloFlixContent> fakeData;
  final bool shouldThrow;

  FakePauloFlixRepository(this.fakeData, {this.shouldThrow = false});

  @override
  Future<List<PauloFlixContent>> getAll() async {
    if (shouldThrow) throw Exception('DB error');
    return fakeData;
  }

  @override
  Future<List<PauloFlixContent>> searchByName(String query) async => fakeData;
  @override
  Future<PauloFlixContent?> getByFolderName(String folderName) async => null;
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

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getTemporaryDirectory':
          case 'getApplicationSupportDirectory':
          case 'getApplicationDocumentsDirectory':
            return Directory.systemTemp.path;
          default:
            return null;
        }
      },
    );
  });

  group('PauloFlixProvider', () {
    final testAnimes = [
      PauloFlixContent(
        folderName: 'Naruto',
        displayName: 'Naruto',
        serverUrl: 'http://server/naruto/',
        imageUrl: 'http://img.com/naruto.jpg',
        genres: ['Action', 'Adventure'],
      ),
      PauloFlixContent(
        folderName: 'One Piece',
        displayName: 'One Piece',
        serverUrl: 'http://server/onepiece/',
        genres: ['Action', 'Comedy'],
      ),
      PauloFlixContent(
        folderName: 'Attack on Titan',
        displayName: 'Shingeki no Kyojin',
        serverUrl: 'http://server/aot/',
        genres: ['Action', 'Drama'],
      ),
    ];

    test('status inicial deve ser initial', () {
      final provider = PauloFlixProvider.withRepository(
        repository: FakePauloFlixRepository([]),
      );
      expect(provider.status, PauloFlixStatus.initial);
      expect(provider.contents, isEmpty);
      expect(provider.errorMessage, isNull);
      expect(provider.isSyncing, false);
      expect(provider.syncProgress, '');
    });

    test('loadContents deve carregar dados do banco', () async {
      final provider = PauloFlixProvider.withRepository(
        repository: FakePauloFlixRepository([testAnimes[0], testAnimes[1]]),
      );

      await provider.loadContents();

      expect(provider.status, PauloFlixStatus.loaded);
      expect(provider.contents.length, 2);
      expect(provider.contents[0].folderName, 'Naruto');
      expect(provider.contents[1].folderName, 'One Piece');
    });

    test('loadContents deve lidar com erro do banco', () async {
      final provider = PauloFlixProvider.withRepository(
        repository: FakePauloFlixRepository([], shouldThrow: true),
      );

      await provider.loadContents();

      expect(provider.status, PauloFlixStatus.error);
      expect(provider.errorMessage, contains('Erro ao carregar conteúdo'));
    });

    test('search deve filtrar por displayName', () async {
      final provider = PauloFlixProvider.withRepository(
        repository: FakePauloFlixRepository([...testAnimes]),
      );
      await provider.loadContents();

      provider.search('naruto');
      await Future.delayed(const Duration(milliseconds: 400));

      expect(provider.contents.length, 1);
      expect(provider.contents[0].folderName, 'Naruto');
    });

    test('search deve filtrar por genero', () async {
      final provider = PauloFlixProvider.withRepository(
        repository: FakePauloFlixRepository([...testAnimes]),
      );
      await provider.loadContents();

      provider.search('comedy');
      await Future.delayed(const Duration(milliseconds: 400));

      expect(provider.contents.length, 1);
      expect(provider.contents[0].folderName, 'One Piece');
    });

    test('search com query vazia deve retornar todos', () async {
      final provider = PauloFlixProvider.withRepository(
        repository: FakePauloFlixRepository([...testAnimes]),
      );
      await provider.loadContents();

      provider.search('');
      await Future.delayed(const Duration(milliseconds: 400));

      expect(provider.contents.length, 3);
    });

    test('clearSearch deve restaurar lista completa', () async {
      final provider = PauloFlixProvider.withRepository(
        repository: FakePauloFlixRepository([...testAnimes]),
      );
      await provider.loadContents();

      provider.search('naruto');
      await Future.delayed(const Duration(milliseconds: 400));
      expect(provider.contents.length, 1);

      provider.clearSearch();
      expect(provider.contents.length, 3);
    });

    test('isAvailableOnPauloFlix deve verificar por nome', () async {
      final provider = PauloFlixProvider.withRepository(
        repository: FakePauloFlixRepository([...testAnimes]),
      );
      await provider.loadContents();

      expect(provider.isAvailableOnPauloFlix('Naruto'), isTrue);
      expect(provider.isAvailableOnPauloFlix('naruto'), isTrue);
      expect(provider.isAvailableOnPauloFlix('Bleach'), isFalse);
    });
  });
}
