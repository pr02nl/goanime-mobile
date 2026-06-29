import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/data/models/jikan_models.dart';
import 'package:goanime/data/services/jikan_service.dart';
import 'package:goanime/domain/repositories/home_repository.dart';
import 'package:goanime/ui/home/view_models/home_viewmodel.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHomeRepository extends Mock implements HomeRepository {}

void main() {
  late HomeViewModel viewModel;
  late MockHomeRepository mockRepository;

  final testAnime = JikanAnime(
    malId: 1,
    title: 'Test Anime',
    imageUrl: 'https://example.com/image.jpg',
    synopsis: 'Test synopsis',
    score: 8.5,
    episodes: 12,
    status: 'Finished Airing',
    genres: [],
  );

  final testHomeData = HomeData(
    seasonAnimes: [testAnime],
    topAnimes: [],
    actionAnimes: [],
    romanceAnimes: [],
    comedyAnimes: [],
    fantasyAnimes: [],
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    // Mock path_provider para suportar DefaultCacheManager
    // (usado pelo ImagePrecacheService dentro de loadHomeData).
    // Nota: path_provider retorna String diretamente (não Map).
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

  setUp(() {
    mockRepository = MockHomeRepository();
    viewModel = HomeViewModel(repository: mockRepository);
  });

  group('HomeViewModel', () {
    test('initial state has isLoading true', () {
      expect(viewModel.isLoading, true);
      expect(viewModel.seasonAnimes, isEmpty);
      expect(viewModel.topAnimes, isEmpty);
    });

    test('loadHomeData loads data on success', () async {
      when(
        () => mockRepository.loadHomeData(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async => testHomeData);

      await viewModel.loadHomeData();

      expect(viewModel.isLoading, false);
      expect(viewModel.seasonAnimes.length, 1);
      expect(viewModel.seasonAnimes.first.title, 'Test Anime');
      expect(viewModel.seasonAnimes.first.score, 8.5);
    });

    test('loadHomeData handles error gracefully', () async {
      when(
        () => mockRepository.loadHomeData(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenThrow(Exception('API error'));

      await viewModel.loadHomeData();

      expect(viewModel.isLoading, false);
      expect(viewModel.seasonAnimes, isEmpty);
    });

    test('loadHomeData does not reload if data already loaded', () async {
      when(
        () => mockRepository.loadHomeData(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async => testHomeData);

      await viewModel.loadHomeData();
      await viewModel.loadHomeData();

      verify(
        () => mockRepository.loadHomeData(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).called(1);
    });

    test('loadHomeData forceRefresh reloads even with existing data', () async {
      when(
        () => mockRepository.loadHomeData(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async => testHomeData);

      await viewModel.loadHomeData();
      await viewModel.loadHomeData(forceRefresh: true);

      verify(
        () => mockRepository.loadHomeData(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).called(2);
    });

    test('setTVMode updates isTV and notifies', () {
      var notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.setTVMode(true);

      expect(viewModel.isTV, true);
      expect(notified, true);
    });

    test('dispose does not throw', () {
      expect(() => viewModel.dispose(), returnsNormally);
    });
  });
}
