import '../../../services/jikan_service.dart';
import '../../data/models/jikan_models.dart';

abstract class HomeRepository {
  Future<HomeData> loadHomeData({bool forceRefresh = false});
  Future<List<JikanAnime>> getAnimesByGenre(int genreId, {int page = 1});
  Future<List<JikanAnime>> searchAnimes(String query, {int page = 1});
}
