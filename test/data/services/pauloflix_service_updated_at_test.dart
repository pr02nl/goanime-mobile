// Testes da verificação de `updated_at` no `PauloFlixService.syncContent()`.
//
// Estratégia: HTTP mockado com `MockClient` + `SharedPreferences`
// mockado via `setMockInitialValues`. O service compara o `updated_at`
// do JSON baixado com o último valor salvo em SharedPreferences. Se
// igual, pula o processamento (retorna true sem tocar no banco).
//
// Usamos `SharedPreferences.setMockInitialValues` que é o padrão
// Flutter para mockar SharedPreferences em testes.

import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/services/pauloflix_service.dart';
import 'package:goanime/domain/models/pauloflix_content.dart';
import 'package:goanime/domain/repositories/pauloflix_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chave usada pelo PauloFlixService para armazenar o último updated_at.
const _lastUpdatedAtKey = 'last_tv_index_updated_at';

/// JSON index com 1 show e updated_at definido.
const _tvIndexJson = '''{
  "updated_at": "2026-06-27T13:53:47.099092+00:00",
  "total_shows": 1,
  "shows": [
    {
      "title": "Test Anime",
      "path": "Test Anime",
      "poster": "/tvshows/Test Anime/poster.jpg",
      "fanart": "/tvshows/Test Anime/fanart.jpg",
      "seasons": []
    }
  ]
}''';

/// JSON com mesmo updated_at — simula índice inalterado.
const _tvIndexSameUpdatedAt = '''{
  "updated_at": "2026-06-27T13:53:47.099092+00:00",
  "total_shows": 1,
  "shows": [
    {
      "title": "Test Anime",
      "path": "Test Anime",
      "poster": "/tvshows/Test Anime/poster.jpg",
      "fanart": "/tvshows/Test Anime/fanart.jpg",
      "seasons": []
    }
  ]
}''';

/// JSON sem a chave `updated_at` — testa compatibilidade retroativa.
const _tvIndexWithoutUpdatedAt = '''{
  "total_shows": 1,
  "shows": [
    {
      "title": "Legacy Anime",
      "path": "Legacy Anime",
      "poster": "/tvshows/Legacy Anime/poster.jpg",
      "fanart": "/tvshows/Legacy Anime/fanart.jpg",
      "seasons": []
    }
  ]
}''';

void main() {
  late _MockRepository mockRepo;

  setUp(() {
    mockRepo = _MockRepository();
    PauloFlixService.configure(http.Client());
  });

  group('PauloFlixService.syncContent — updated_at', () {
    test('updated_at diferente → processa (saveBatch é chamado)', () async {
      SharedPreferences.setMockInitialValues({});

      PauloFlixService.configure(
        MockClient((_) async => http.Response(_tvIndexJson, 200)),
      );

      await PauloFlixService.syncContent(repository: mockRepo);

      // syncContent chama getAll + saveBatch quando processa
      expect(
        mockRepo.getAllCallCount,
        greaterThan(0),
        reason: 'getAll deve ser chamado ao processar',
      );
      expect(
        mockRepo.saveBatchCallCount,
        greaterThan(0),
        reason: 'updated_at diferente deve processar o JSON',
      );
    });

    test(
      'updated_at igual → PULA processamento (getAll/saveBatch NÃO chamados)',
      () async {
        SharedPreferences.setMockInitialValues({
          _lastUpdatedAtKey: '2026-06-27T13:53:47.099092+00:00',
        });

        PauloFlixService.configure(
          MockClient((_) async => http.Response(_tvIndexSameUpdatedAt, 200)),
        );

        final result = await PauloFlixService.syncContent(repository: mockRepo);

        expect(
          result,
          isTrue,
          reason: 'deve retornar true mesmo quando pula o processamento',
        );
        expect(
          mockRepo.getAllCallCount,
          0,
          reason: 'getAll não deve ser chamado no skip',
        );
        expect(
          mockRepo.saveBatchCallCount,
          0,
          reason: 'updated_at igual → NÃO deve processar o JSON',
        );
      },
    );

    test(
      'sem updated_at no JSON → processa (compatibilidade retroativa)',
      () async {
        SharedPreferences.setMockInitialValues({});

        PauloFlixService.configure(
          MockClient((_) async => http.Response(_tvIndexWithoutUpdatedAt, 200)),
        );

        await PauloFlixService.syncContent(repository: mockRepo);

        expect(
          mockRepo.saveBatchCallCount,
          greaterThan(0),
          reason: 'sem updated_at no JSON → deve processar normalmente',
        );
      },
    );

    test('primeira sync (sem chave no prefs) → processa', () async {
      SharedPreferences.setMockInitialValues({});

      PauloFlixService.configure(
        MockClient((_) async => http.Response(_tvIndexJson, 200)),
      );

      await PauloFlixService.syncContent(repository: mockRepo);

      expect(
        mockRepo.saveBatchCallCount,
        greaterThan(0),
        reason: 'primeira sync sem chave no prefs deve processar',
      );
    });

    test(
      'updated_at igual → skip ocorre antes de qualquer acesso ao banco',
      () async {
        SharedPreferences.setMockInitialValues({
          _lastUpdatedAtKey: '2026-06-27T13:53:47.099092+00:00',
        });

        PauloFlixService.configure(
          MockClient((_) async => http.Response(_tvIndexSameUpdatedAt, 200)),
        );

        final result = await PauloFlixService.syncContent(repository: mockRepo);

        expect(result, isTrue);
        expect(
          mockRepo.getAllCallCount,
          0,
          reason: 'skip por updated_at deve ocorrer antes de getAll',
        );
        expect(
          mockRepo.saveBatchCallCount,
          0,
          reason: 'skip por updated_at deve ocorrer antes de saveBatch',
        );
      },
    );
  });
}

/// Mock do PauloFlixRepository que rastreia chamadas a getAll e saveBatch.
class _MockRepository implements PauloFlixRepository {
  int getAllCallCount = 0;
  int saveBatchCallCount = 0;

  @override
  Future<List<PauloFlixContent>> getAll() async {
    getAllCallCount++;
    return [];
  }

  @override
  Future<void> saveBatch(List<PauloFlixContent> contents) async {
    saveBatchCallCount++;
  }

  @override
  Future<PauloFlixContent?> getByFolderName(String folderName) async => null;

  @override
  Future<void> saveContent(PauloFlixContent content) async {}

  @override
  Future<void> markAsUnavailable(String folderName) async {}

  @override
  Future<Map<String, int>> getStats() async => {};

  @override
  Future<List<PauloFlixContent>> searchByName(String query) async => [];

  @override
  Stream<List<PauloFlixContent>> watch() => const Stream.empty();
}
