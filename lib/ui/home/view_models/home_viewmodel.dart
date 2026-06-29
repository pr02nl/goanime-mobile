import 'package:flutter/material.dart';

import '../../../data/models/jikan_models.dart';
import '../../../data/repositories/home_repository_impl.dart';
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


}
