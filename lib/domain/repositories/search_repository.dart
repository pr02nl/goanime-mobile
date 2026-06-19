import '../../../models/anime.dart';

abstract class SearchRepository {
  Future<List<Anime>> searchAnime(String animeName);
}
