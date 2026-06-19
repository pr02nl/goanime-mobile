import '../../../models/jikan_models.dart';
import '../../../services/jikan_service.dart';
import '../../domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final JikanService _jikanService;

  HomeRepositoryImpl({JikanService? jikanService})
      : _jikanService = jikanService ?? JikanService();

  @override
  Future<HomeData> loadHomeData({bool forceRefresh = false}) async {
    return _jikanService.loadHomeData(forceRefresh: forceRefresh);
  }

  @override
  Future<List<JikanAnime>> getAnimesByGenre(int genreId, {int page = 1}) async {
    return _jikanService.getAnimesByGenre(genreId, page: page);
  }

  @override
  Future<List<JikanAnime>> searchAnimes(String query, {int page = 1}) async {
    return _jikanService.searchAnimes(query, page: page);
  }
}
