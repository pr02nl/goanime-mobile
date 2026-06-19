import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English (default)
    Locale('pt', 'BR'), // Portuguese
  ];

  // Common
  String get appName => locale.languageCode == 'pt' ? 'PauloFlix' : 'PauloFlix';
  String get search => locale.languageCode == 'pt' ? 'Buscar' : 'Search';
  String get settings =>
      locale.languageCode == 'pt' ? 'Configurações' : 'Settings';
  String get loading =>
      locale.languageCode == 'pt' ? 'Carregando...' : 'Loading...';
  String get error => locale.languageCode == 'pt' ? 'Erro' : 'Error';
  String get retry =>
      locale.languageCode == 'pt' ? 'Tentar Novamente' : 'Retry';
  String get close => locale.languageCode == 'pt' ? 'Fechar' : 'Close';

  // Anime Detail Screen
  String get watchEpisodes =>
      locale.languageCode == 'pt' ? 'Assistir Episódios' : 'Watch Episodes';
  String get genres => locale.languageCode == 'pt' ? 'Gêneros' : 'Genres';
  String get synopsis =>
      locale.languageCode == 'pt' ? 'Sinopse' : 'Synopsis';
  String get information =>
      locale.languageCode == 'pt' ? 'Informações' : 'Information';
  String get seasonLabel =>
      locale.languageCode == 'pt' ? 'Temporada' : 'Season';
  String get anilistId => locale.languageCode == 'pt' ? 'AniList ID' : 'AniList ID';
  String get malId =>
      locale.languageCode == 'pt' ? 'MyAnimeList ID' : 'MyAnimeList ID';
  String get popularity =>
      locale.languageCode == 'pt' ? 'Popularidade' : 'Popularity';
  String get winter => locale.languageCode == 'pt' ? 'Inverno' : 'Winter';
  String get spring => locale.languageCode == 'pt' ? 'Primavera' : 'Spring';
  String get summer => locale.languageCode == 'pt' ? 'Verão' : 'Summer';
  String get fall => locale.languageCode == 'pt' ? 'Outono' : 'Fall';
  String get aired =>
      locale.languageCode == 'pt' ? 'Lançado' : 'Aired';
  String get notYetAired =>
      locale.languageCode == 'pt' ? 'Não Lançado' : 'Not Yet Aired';
  String get currentlyAiring =>
      locale.languageCode == 'pt' ? 'Em Exibição' : 'Currently Airing';
  String get cancelled =>
      locale.languageCode == 'pt' ? 'Cancelado' : 'Cancelled';
  String get hiatus =>
      locale.languageCode == 'pt' ? 'Em Hiato' : 'On Hiatus';

  // Home Screen
  String get home => locale.languageCode == 'pt' ? 'Início' : 'Home';
  String get trending => locale.languageCode == 'pt' ? 'Em Alta' : 'Trending';
  String get topAnime =>
      locale.languageCode == 'pt' ? 'Top Anime' : 'Top Anime';
  String get action => locale.languageCode == 'pt' ? 'Ação' : 'Action';
  String get romance => locale.languageCode == 'pt' ? 'Romance' : 'Romance';
  String get comedy => locale.languageCode == 'pt' ? 'Comédia' : 'Comedy';
  String get fantasy => locale.languageCode == 'pt' ? 'Fantasia' : 'Fantasy';
  String get currentSeason =>
      locale.languageCode == 'pt' ? 'Temporada Atual' : 'Current Season';
  String get seasonHighlights => locale.languageCode == 'pt'
      ? 'Destaques da Temporada'
      : 'Season Highlights';
  String get seeAll => locale.languageCode == 'pt' ? 'Ver Todos' : 'See All';
  String get errorLoadingAnime => locale.languageCode == 'pt'
      ? 'Erro ao carregar animes'
      : 'Error loading anime';

  // Search Screen
  String get searchAnime =>
      locale.languageCode == 'pt' ? 'Buscar Anime...' : 'Search Anime...';
  String get searchHint => locale.languageCode == 'pt'
      ? 'Buscar por título, saga ou estúdio...'
      : 'Search by title, saga or studio...';
  String get searchingBestEpisodes => locale.languageCode == 'pt'
      ? 'Procurando pelos melhores episódios...'
      : 'Searching for the best episodes...';
  String get exploreCatalog =>
      locale.languageCode == 'pt' ? 'Explore o catálogo' : 'Explore the catalog';
  String get searchPrompt => locale.languageCode == 'pt'
      ? 'Pesquise por títulos populares, gêneros ou utilize sua lista de favoritos.'
      : 'Search for popular titles, genres or use your favorites list.';
  String get searchErrorTitle => locale.languageCode == 'pt'
      ? 'Não foi possível concluir sua busca'
      : 'Could not complete your search';
  String get tryAgainLater => locale.languageCode == 'pt'
      ? 'Tente novamente em instantes.'
      : 'Try again in a moment.';
  String resultsFound(int count) => locale.languageCode == 'pt'
      ? '$count resultado${count == 1 ? '' : 's'} encontrado${count == 1 ? '' : 's'}'
      : '$count result${count == 1 ? '' : 's'} found';
  String get lightMode =>
      locale.languageCode == 'pt' ? 'Tema claro' : 'Light mode';
  String get darkMode =>
      locale.languageCode == 'pt' ? 'Tema escuro' : 'Dark mode';
  String get startMarathon =>
      locale.languageCode == 'pt' ? 'Comece uma nova maratona' : 'Start a new marathon';
  String get searchScreenSubtitle => locale.languageCode == 'pt'
      ? 'Pesquise por títulos, sagas ou estúdios para encontrar seu anime.'
      : 'Search for titles, sagas or studios to find your anime.';
  String get recentSearches =>
      locale.languageCode == 'pt' ? 'Buscas Recentes' : 'Recent Searches';
  String get trending30Days =>
      locale.languageCode == 'pt' ? 'Em Alta (30 dias)' : 'Trending (30 days)';
  String get filterByGenre =>
      locale.languageCode == 'pt' ? 'Filtrar por Gênero' : 'Filter by Genre';
  String get clearHistory =>
      locale.languageCode == 'pt' ? 'Limpar Histórico' : 'Clear History';
  String get noRecentSearches => locale.languageCode == 'pt'
      ? 'Nenhuma busca recente'
      : 'No recent searches';
  String get searchForAnime => locale.languageCode == 'pt'
      ? 'Busque por seu anime favorito'
      : 'Search for your favorite anime';
  String get noResultsFound => locale.languageCode == 'pt'
      ? 'Nenhum resultado encontrado'
      : 'No results found';
  String get tryDifferentKeywords => locale.languageCode == 'pt'
      ? 'Tente palavras-chave diferentes'
      : 'Try different keywords';

  // Genres
  String get allGenres => locale.languageCode == 'pt' ? 'Todos' : 'All';
  String get adventure =>
      locale.languageCode == 'pt' ? 'Aventura' : 'Adventure';
  String get drama => locale.languageCode == 'pt' ? 'Drama' : 'Drama';
  String get sciFi =>
      locale.languageCode == 'pt' ? 'Ficção Científica' : 'Sci-Fi';
  String get horror => locale.languageCode == 'pt' ? 'Terror' : 'Horror';
  String get mystery => locale.languageCode == 'pt' ? 'Mistério' : 'Mystery';
  String get supernatural =>
      locale.languageCode == 'pt' ? 'Sobrenatural' : 'Supernatural';
  String get sports => locale.languageCode == 'pt' ? 'Esportes' : 'Sports';
  String get sliceOfLife =>
      locale.languageCode == 'pt' ? 'Slice of Life' : 'Slice of Life';

  // PauloFlix / Movies
  String get pauloFlix =>
      locale.languageCode == 'pt' ? 'PauloFlix' : 'PauloFlix';
  String get sync =>
      locale.languageCode == 'pt' ? 'Sincronizar' : 'Sync';
  String get movies =>
      locale.languageCode == 'pt' ? 'Filmes' : 'Movies';
  String movieCount(int count) => locale.languageCode == 'pt'
      ? '$count ${count == 1 ? 'filme' : 'filmes'}'
      : '$count ${count == 1 ? 'movie' : 'movies'}';
  String get noMoviesAvailable =>
      locale.languageCode == 'pt' ? 'Nenhum filme disponível' : 'No movies available';
  String get syncMovies =>
      locale.languageCode == 'pt' ? 'Sincronizar Filmes' : 'Sync Movies';
  String get syncContent =>
      locale.languageCode == 'pt' ? 'Sincronizar Conteúdo' : 'Sync Content';
  String get tmdbNotConfigured => locale.languageCode == 'pt'
      ? 'TMDB não configurado. Vá em Configurações → API Keys para adicionar a chave.'
      : 'TMDB not configured. Go to Settings → API Keys to add the key.';
  String get availableEpisodes =>
      locale.languageCode == 'pt' ? 'Episódios disponíveis' : 'Available Episodes';

  // Settings Screen
  String get apiKeys =>
      locale.languageCode == 'pt' ? 'API Keys' : 'API Keys';
  String get theMovieDatabase =>
      locale.languageCode == 'pt' ? 'The Movie Database (TMDB)' : 'The Movie Database (TMDB)';
  String get configured =>
      locale.languageCode == 'pt' ? 'Configurado' : 'Configured';
  String get notConfigured =>
      locale.languageCode == 'pt' ? 'Não configurado' : 'Not Configured';
  String get addYourKey =>
      locale.languageCode == 'pt' ? 'Adicione sua chave TMDB' : 'Add your TMDB key';
  String get pasteApiKeyHint =>
      locale.languageCode == 'pt' ? 'Cole aqui sua API key v3' : 'Paste your API key v3 here';
  String get save => locale.languageCode == 'pt' ? 'Salvar' : 'Save';
  String get validKeyRequired =>
      locale.languageCode == 'pt' ? 'Digite uma chave válida' : 'Enter a valid key';
  String get tmdbKeySaved => locale.languageCode == 'pt'
      ? 'Chave do TMDB salva com sucesso'
      : 'TMDB key saved successfully';
  String get tmdbKeyRemoved => locale.languageCode == 'pt'
      ? 'Chave do TMDB removida'
      : 'TMDB key removed';
  String get unsavedWarning => locale.languageCode == 'pt'
      ? 'A chave não foi salva'
      : 'The key was not saved';

  // Downloads Screen
  String get downloads =>
      locale.languageCode == 'pt' ? 'Downloads' : 'Downloads';
  String get activeTab =>
      locale.languageCode == 'pt' ? 'Ativos' : 'Active';
  String get completedTab =>
      locale.languageCode == 'pt' ? 'Concluídos' : 'Completed';
  String get downloadSettings =>
      locale.languageCode == 'pt' ? 'Configurações de Download' : 'Download Settings';
  String get maxConcurrentDownloads => locale.languageCode == 'pt'
      ? 'Downloads Simultâneos'
      : 'Max Concurrent Downloads';
  String get noActiveDownloads =>
      locale.languageCode == 'pt' ? 'Nenhum download ativo' : 'No active downloads';
  String get noCompletedDownloads =>
      locale.languageCode == 'pt' ? 'Nenhum download concluído' : 'No completed downloads';
  String get deleteDownload =>
      locale.languageCode == 'pt' ? 'Excluir Download' : 'Delete Download';
  String get deleteDownloadConfirmation => locale.languageCode == 'pt'
      ? 'Tem certeza que deseja excluir este download?'
      : 'Are you sure you want to delete this download?';
  String episodesCount(int count) => locale.languageCode == 'pt'
      ? '$count ${count == 1 ? 'episódio' : 'episódios'}'
      : '$count ${count == 1 ? 'episode' : 'episodes'}';
  String get paused => locale.languageCode == 'pt' ? 'Pausado' : 'Paused';
  String get waiting => locale.languageCode == 'pt' ? 'Aguardando...' : 'Waiting...';
  String failedWith(String error) => locale.languageCode == 'pt'
      ? 'Falhou: $error'
      : 'Failed: $error';
  String get unknownError =>
      locale.languageCode == 'pt' ? 'Erro desconhecido' : 'Unknown error';
  String get clearAllCompleted =>
      locale.languageCode == 'pt' ? 'Limpar Concluídos' : 'Clear All Completed';
  String get delete => locale.languageCode == 'pt' ? 'Excluir' : 'Delete';

  // Episode List Screen
  String get episodes => locale.languageCode == 'pt' ? 'Episódios' : 'Episodes';
  String episode(String number) =>
      locale.languageCode == 'pt' ? 'Episódio $number' : 'Episode $number';
  String get episodeCount => locale.languageCode == 'pt' ? 'eps' : 'eps';
  String get total => locale.languageCode == 'pt' ? 'Total' : 'Total';
  String get status => locale.languageCode == 'pt' ? 'Status' : 'Status';
  String get finished =>
      locale.languageCode == 'pt' ? 'Finalizado' : 'Finished';
  String get ongoing => locale.languageCode == 'pt' ? 'Em Exibição' : 'Ongoing';
  String get tapToWatch =>
      locale.languageCode == 'pt' ? 'Toque para assistir' : 'Tap to watch';
  String get watchNow =>
      locale.languageCode == 'pt' ? 'Assistir Agora' : 'Watch Now';
  String get searching =>
      locale.languageCode == 'pt' ? 'Buscando...' : 'Searching...';
  String get selectVersion =>
      locale.languageCode == 'pt' ? 'Selecione a Versão' : 'Select Version';
  String get loadingEpisodes => locale.languageCode == 'pt'
      ? 'Carregando episódios...'
      : 'Loading episodes...';
  String get errorLoadingEpisodes => locale.languageCode == 'pt'
      ? 'Erro ao carregar episódios'
      : 'Error loading episodes';
  String get noEpisodesFound => locale.languageCode == 'pt'
      ? 'Nenhum episódio encontrado'
      : 'No episodes found';
  String get noAnimeFound => locale.languageCode == 'pt'
      ? 'Nenhum anime encontrado'
      : 'No anime found';
  String get animeNotFoundOnAllAnime => locale.languageCode == 'pt'
      ? 'Anime não encontrado no AllAnime'
      : 'Anime not found on AllAnime';
  String get animeNotFoundOnAnimeFire => locale.languageCode == 'pt'
      ? 'Anime não encontrado no AnimeFire'
      : 'Anime not found on AnimeFire';

  // Video Player Screen
  String get nowPlaying =>
      locale.languageCode == 'pt' ? 'Agora reproduzindo' : 'Now playing';
  String get loadingStream => locale.languageCode == 'pt'
      ? 'Carregando stream...'
      : 'Loading stream...';
  String get preparingServer => locale.languageCode == 'pt'
      ? 'Preparando o melhor servidor para você'
      : 'Preparing the best server for you';
  String get playerError =>
      locale.languageCode == 'pt' ? 'Erro no Player' : 'Player Error';
  String get serverInUse =>
      locale.languageCode == 'pt' ? 'Servidor em uso' : 'Server in use';
  String get copyLink =>
      locale.languageCode == 'pt' ? 'Copiar link' : 'Copy link';
  String get syncStream =>
      locale.languageCode == 'pt' ? 'Sincronizar' : 'Synchronize';
  String get alternativePlayer => locale.languageCode == 'pt'
      ? 'Abrir player alternativo'
      : 'Open alternative player';
  String get linkCopied =>
      locale.languageCode == 'pt' ? 'Link copiado!' : 'Link copied!';
  String get dynamicQuality =>
      locale.languageCode == 'pt' ? 'Dynamic quality' : 'Dynamic quality';
  String get optimizedPlayer =>
      locale.languageCode == 'pt' ? 'Optimized player' : 'Optimized player';
  String get googleVideo =>
      locale.languageCode == 'pt' ? 'Google Video' : 'Google Video';
  String get skipIntro =>
      locale.languageCode == 'pt' ? 'Pular Intro' : 'Skip Intro';
  String get skipOutro =>
      locale.languageCode == 'pt' ? 'Pular Encerramento' : 'Skip Outro';
  String get nextEpisode =>
      locale.languageCode == 'pt' ? 'Próximo Ep.' : 'Next Ep.';
  String get previousEpisode =>
      locale.languageCode == 'pt' ? 'Ep. Anterior' : 'Previous Ep.';
  String get subtitles =>
      locale.languageCode == 'pt' ? 'Legendas' : 'Subtitles';
  String get subtitleSelector =>
      locale.languageCode == 'pt' ? 'Legendas' : 'Subtitles';
  String get autoRecommended => locale.languageCode == 'pt'
      ? 'Automático (recomendado)'
      : 'Auto (recommended)';
  String get autoDescription => locale.languageCode == 'pt'
      ? 'Deixa o media_kit escolher a melhor faixa.'
      : 'Let media_kit choose the best track.';
  String get auto => locale.languageCode == 'pt' ? 'Automático' : 'Auto';
  String get subtitlesOff =>
      locale.languageCode == 'pt' ? 'Sem legenda' : 'Subtitles Off';
  String get subtitlesOffDescription => locale.languageCode == 'pt'
      ? 'Desativa todas as legendas.'
      : 'Disable all subtitles.';
  String get embeddedSubtitles => locale.languageCode == 'pt'
      ? 'Embutidas no vídeo'
      : 'Embedded in video';
  String get externalSubtitles =>
      locale.languageCode == 'pt' ? 'Externas (.srt)' : 'External (.srt)';
  String get unknownLanguage =>
      locale.languageCode == 'pt' ? 'Idioma desconhecido' : 'Unknown language';
  String subtitleError(String error) => locale.languageCode == 'pt'
      ? 'Erro ao trocar legenda: $error'
      : 'Error switching subtitle: $error';
  String get subtitleEmbedded =>
      locale.languageCode == 'pt' ? 'Embutida' : 'Embedded';
  String get noSubtitle =>
      locale.languageCode == 'pt' ? 'Sem legenda' : 'No subtitle';

  // Watchlist Screen
  String get watchlist =>
      locale.languageCode == 'pt' ? 'Watchlist' : 'Watchlist';
  String get clearWatchlist =>
      locale.languageCode == 'pt' ? 'Limpar watchlist' : 'Clear watchlist';
  String get watchlistEmpty => locale.languageCode == 'pt'
      ? 'Sua watchlist está vazia'
      : 'Your watchlist is empty';
  String get addAnimesToWatchLater => locale.languageCode == 'pt'
      ? 'Adicione animes para assistir depois'
      : 'Add anime to watch later';
  String get addedToWatchlist => locale.languageCode == 'pt'
      ? 'Adicionado à watchlist'
      : 'Added to watchlist';
  String get removedFromWatchlistShort => locale.languageCode == 'pt'
      ? 'Removido da watchlist'
      : 'Removed from watchlist';
  String removedFromWatchlist(String title) => locale.languageCode == 'pt'
      ? '$title removido da watchlist'
      : '$title removed from watchlist';
  String get clearWatchlistQuestion =>
      locale.languageCode == 'pt' ? 'Limpar Watchlist?' : 'Clear Watchlist?';
  String get clearWatchlistConfirmation => locale.languageCode == 'pt'
      ? 'Tem certeza que deseja remover todos os animes da watchlist?'
      : 'Are you sure you want to remove all anime from the watchlist?';
  String get cancel => locale.languageCode == 'pt' ? 'Cancelar' : 'Cancel';
  String get clear => locale.languageCode == 'pt' ? 'Limpar' : 'Clear';
  String get watchlistCleared =>
      locale.languageCode == 'pt' ? 'Watchlist limpa' : 'Watchlist cleared';

  // Settings Screen
  String get language => locale.languageCode == 'pt' ? 'Idioma' : 'Language';
  String get selectLanguage =>
      locale.languageCode == 'pt' ? 'Selecione o idioma' : 'Select language';
  String get english => locale.languageCode == 'pt' ? 'Inglês' : 'English';
  String get portuguese =>
      locale.languageCode == 'pt' ? 'Português' : 'Portuguese';
  String get appearance =>
      locale.languageCode == 'pt' ? 'Aparência' : 'Appearance';
  String get about => locale.languageCode == 'pt' ? 'Sobre' : 'About';
  String get version => locale.languageCode == 'pt' ? 'Versão' : 'Version';
  String get languageChanged => locale.languageCode == 'pt'
      ? 'Idioma alterado com sucesso'
      : 'Language changed successfully';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'pt'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
