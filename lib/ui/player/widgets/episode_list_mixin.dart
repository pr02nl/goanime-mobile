/// Mixin de paginação de episódios compartilhado entre as telas de lista.
///
/// Extrai a lógica duplicada (~150 linhas) de `episode_list_screen.dart` e
/// `modern_episode_list_screen.dart` para um único local.
///
/// ## Uso
///
/// ```dart
/// class _MyScreenState extends State<MyScreen>
///     with EpisodeListPaginationMixin<MyScreen> {
///   @override
///   Anime get anime => widget.anime;
/// }
/// ```
library;

import 'package:flutter/material.dart';

import '../../../data/services/anime_service.dart';
import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';

/// Mixin que adiciona scroll infinito + chunk loading de episódios.
///
/// Fornece:
/// - `episodes`, `isLoading`, `isLoadingMore`, `totalEpisodes`, `errorMessage`
/// - `scrollController` com listener de scroll automático
/// - `loadInitialChunk()` / `loadMoreEpisodes()` públicos
/// - `allEpisodes` (cópia completa, útil para batch download)
mixin EpisodeListPaginationMixin<T extends StatefulWidget> on State<T> {
  /// Tamanho do bloco de episódios carregado por vez.
  static const int chunkSize = 30;

  /// Controller de scroll usado pelo [ScrollView] do consumidor.
  final ScrollController scrollController = ScrollController();

  /// Episódios carregados até o momento (parcial ou total).
  List<Episode> episodes = [];

  /// Cópia completa de todos os episódios (sem thumbnails).
  /// Populado durante [loadInitialChunk] para uso em batch download.
  List<Episode>? allEpisodes;

  /// `true` enquanto o primeiro bloco está sendo carregado.
  bool isLoading = true;

  /// `true` enquanto um bloco adicional está sendo carregado.
  bool isLoadingMore = false;

  /// Total de episódios conhecidos (pode ser > `episodes.length`).
  int totalEpisodes = 0;

  /// Índice do último bloco carregado.
  int currentChunk = 0;

  /// Mensagem de erro, se houver.
  String? errorMessage;

  /// O anime cujos episódios estão sendo carregados.
  Anime get anime;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    _loadInitialChunk();
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.dispose();
  }

  /// Callback de scroll: carrega mais episódios quando o usuário está
  /// próximo do final da lista.
  void _onScroll() {
    if (isLoadingMore) return;
    if (episodes.length >= totalEpisodes && totalEpisodes > 0) return;

    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    // Pré-carrega quando faltam ~600px (≈ 1 tela) para o fim.
    if (maxScroll - currentScroll < 600) {
      loadMoreEpisodes();
    }
  }

  /// Carrega o primeiro bloco de episódios.
  Future<void> loadInitialChunk() => _loadInitialChunk();

  Future<void> _loadInitialChunk() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Parseia a lista completa (cacheada, sem thumbnails).
      final all = await AnimeService.getAnimeEpisodeList(anime);
      allEpisodes = all;
      totalEpisodes = all.length;

      // Carrega o primeiro bloco com thumbnails.
      final result = await AnimeService.getAnimeEpisodesChunk(
        anime,
        chunkIndex: 0,
        chunkSize: chunkSize,
      );
      currentChunk = 0;

      if (mounted) {
        setState(() {
          episodes = result.episodes;
          totalEpisodes = result.total;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[$runtimeType] Error loading initial chunk: $e');
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  /// Carrega o próximo bloco de episódios e adiciona à lista.
  Future<void> loadMoreEpisodes() => _loadMoreEpisodes();

  Future<void> _loadMoreEpisodes() async {
    if (isLoadingMore || episodes.length >= totalEpisodes) return;

    setState(() => isLoadingMore = true);

    try {
      final nextChunk = currentChunk + 1;
      final result = await AnimeService.getAnimeEpisodesChunk(
        anime,
        chunkIndex: nextChunk,
        chunkSize: chunkSize,
      );
      currentChunk = nextChunk;

      if (mounted) {
        setState(() {
          episodes.addAll(result.episodes);
          isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[$runtimeType] Error loading more episodes: $e');
      if (mounted) {
        setState(() => isLoadingMore = false);
      }
    }
  }

  /// Builder do indicador de loading de mais episódios.
  /// Pode ser usado em [SliverToBoxAdapter] no final da lista.
  Widget buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
