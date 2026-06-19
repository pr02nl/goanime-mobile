import '../../../models/anime.dart';
import '../../../services/anime_service.dart';
import '../../domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  @override
  Future<List<Anime>> searchAnime(String animeName) async {
    return AnimeService.searchAnime(animeName);
  }
}
