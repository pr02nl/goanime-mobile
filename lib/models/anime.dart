import 'anilist_models.dart';

enum AnimeSource { animeFire }

class Anime {
  final String name;
  final String url;
  final AnimeSource source;
  final String?
  fallbackImageUrl; // Imagem de fallback antes do AniList carregar
  MediaDetails? aniListData;
  bool isLoadingAniList = false;

  Anime({
    required this.name,
    required this.url,
    this.source = AnimeSource.animeFire,
    this.aniListData,
    this.fallbackImageUrl,
  });

  @override
  String toString() => name;

  String get imageUrl => aniListData?.coverImage.best ?? fallbackImageUrl ?? '';
  String get bannerUrl => aniListData?.bannerImage ?? '';
  String get description => aniListData?.description ?? '';
  int? get malId => aniListData?.idMal;
  int? get anilistId => aniListData?.id;
  List<String> get genres => aniListData?.genres ?? [];
  String? get status => aniListData?.status;
  int? get episodeCount => aniListData?.episodes;
  double? get averageScore => aniListData?.averageScore;
  String get sourceName => 'AnimeFire';
}
