import 'package:flutter/material.dart';

import '../../../data/models/jikan_models.dart';
import '../../../data/repositories/home_repository_impl.dart';
import '../../../data/services/image_precache_service.dart';
import '../../../domain/repositories/home_repository.dart';

class HomeViewModel extends ChangeNotifier {
  final HomeRepository _repository;

  HomeViewModel({HomeRepository? repository})
    : _repository = repository ?? HomeRepositoryImpl();

  double headerOpacity = 1.0;
  bool isLoading = true;
  bool isTV = false;

  List<JikanAnime> seasonAnimes = [];
  List<JikanAnime> topAnimes = [];
  List<JikanAnime> actionAnimes = [];
  List<JikanAnime> romanceAnimes = [];
  List<JikanAnime> comedyAnimes = [];
  List<JikanAnime> fantasyAnimes = [];

  Future<void> loadHomeData({bool forceRefresh = false}) async {
    if (!forceRefresh && seasonAnimes.isNotEmpty) return;

    isLoading = true;
    notifyListeners();

    try {
      final homeData = await _repository.loadHomeData(
        forceRefresh: forceRefresh,
      );

      seasonAnimes = homeData.seasonAnimes;
      topAnimes = homeData.topAnimes;
      actionAnimes = homeData.actionAnimes;
      romanceAnimes = homeData.romanceAnimes;
      comedyAnimes = homeData.comedyAnimes;
      fantasyAnimes = homeData.fantasyAnimes;

      // Se é forceRefresh, limpa o histórico de URLs já prefetched
      // para que imagens novas/atualizadas sejam re-baixadas.
      if (forceRefresh) {
        ImagePrecacheService.clearHistory();
      }
      _precacheImages();
    } catch (e) {
      debugPrint('Error loading home data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setTVMode(bool tv) {
    isTV = tv;
    notifyListeners();
  }

  /// Pré-carrega as imagens dos cards visíveis em background.
  ///
  /// Coleta todas as URLs de imagem (imageUrl + largImageUrl) de todas
  /// as seções carregadas e dispara o download para o cache de disco.
  void _precacheImages() {
    final urls = <String>[
      // Hero banner (primeiro anime da season).
      if (seasonAnimes.isNotEmpty) ...[
        seasonAnimes.first.largImageUrl ?? seasonAnimes.first.imageUrl,
      ],
      // Todos os cards de todas as seções.
      ...seasonAnimes.map((a) => a.imageUrl),
      ...topAnimes.map((a) => a.imageUrl),
      ...actionAnimes.map((a) => a.imageUrl),
      ...romanceAnimes.map((a) => a.imageUrl),
      ...comedyAnimes.map((a) => a.imageUrl),
      ...fantasyAnimes.map((a) => a.imageUrl),
    ];
    ImagePrecacheService.prefetchImages(urls);
  }
}
