/// ViewModel para a tela de episódios do PauloFlix com persistência de
/// progresso.
///
/// **Uso:**
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => PauloFlixEpisodeProgressViewModel(
///     content: content,
///     repository: context.read<PauloFlixEpisodeProgressRepository>(),
///   )..loadSeasons(),
///   child: ...,
/// )
/// ```
library;

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../../../domain/models/paulo_flix_episode_record.dart';
import '../../../domain/models/paulo_flix_season_record.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/models/pauloflix_models.dart' as scraping;
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';

/// Estados possíveis do ViewModel.
enum PauloFlixEpisodeStatus { initial, loading, loaded, error }

class PauloFlixEpisodeProgressViewModel extends ChangeNotifier {
  final PauloFlixContent content;
  final PauloFlixEpisodeProgressRepository _repository;

  PauloFlixEpisodeProgressViewModel({
    required this.content,
    required PauloFlixEpisodeProgressRepository repository,
  }) : _repository = repository;

  // ─── Estado ────────────────────────────────────────────────────────

  PauloFlixEpisodeStatus _status = PauloFlixEpisodeStatus.initial;
  List<PauloFlixSeasonRecord> _seasons = [];
  int _selectedSeasonIndex = 0;
  String? _errorMessage;
  bool _disposed = false;

  /// Stream subscription das seasons (cancelada em dispose).
  StreamSubscription<List<PauloFlixSeasonRecord>>? _seasonsSub;

  /// Stream subscription dos episodes da season selecionada.
  StreamSubscription<List<PauloFlixEpisodeRecord>>? _episodesSub;

  /// Cache dos episodes da season selecionada (atualizado pelo stream).
  final Map<int, List<PauloFlixEpisodeRecord>> _episodesBySeason = {};

  // ─── Getters ────────────────────────────────────────────────────────

  PauloFlixEpisodeStatus get status => _status;
  List<PauloFlixSeasonRecord> get seasons => _seasons;
  int get selectedSeasonIndex => _selectedSeasonIndex;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == PauloFlixEpisodeStatus.loading;
  bool get hasSeasons => _seasons.isNotEmpty;

  List<PauloFlixEpisodeRecord> get episodes {
    if (_seasons.isEmpty) return const [];
    final i = _selectedSeasonIndex.clamp(0, _seasons.length - 1);
    return _episodesBySeason[_seasons[i].id] ?? const [];
  }

  PauloFlixSeasonRecord? get selectedSeason {
    if (_seasons.isEmpty) return null;
    final i = _selectedSeasonIndex.clamp(0, _seasons.length - 1);
    return _seasons[i];
  }

  bool get isSelectedSeasonCompleted {
    final s = selectedSeason;
    return s?.isCompleted ?? false;
  }

  String? get selectedSeasonHeroUrl {
    final s = selectedSeason;
    if (s != null && s.fanartFileName != null && s.fanartFileName!.isNotEmpty) {
      final scrapingSeason = _findScrapingSeasonFor(s);
      if (scrapingSeason != null) {
        return s.fanartUrlWith(scrapingSeason.url);
      }
      return s.fanartUrl;
    }
    if (content.bannerUrl != null && content.bannerUrl!.isNotEmpty) {
      return content.bannerUrl;
    }
    return null;
  }

  String? get selectedSeasonPosterUrl {
    final s = selectedSeason;
    if (s == null) return null;
    if (s.posterFileName == null || s.posterFileName!.isEmpty) {
      return null;
    }
    final scrapingSeason = _findScrapingSeasonFor(s);
    if (scrapingSeason == null) return s.posterUrl;
    return s.posterUrlWith(scrapingSeason.url);
  }

  scraping.PauloFlixSeason? _findScrapingSeasonFor(
    PauloFlixSeasonRecord record,
  ) {
    for (final scraping in scrapingSeasons) {
      if (scraping.number == record.seasonNumber) return scraping;
    }
    return null;
  }

  List<scraping.PauloFlixSeason> get scrapingSeasons {
    return _seasons
        .map(
          (s) => scraping.PauloFlixSeason(
            name: s.displayName,
            url: '${content.serverUrl}${s.folderName}/',
            number: s.seasonNumber,
          ),
        )
        .toList();
  }

  List<scraping.PauloFlixEpisode> get scrapingEpisodesForSelected {
    return episodes
        .map(
          (e) => scraping.PauloFlixEpisode(
            number: e.episodeNumber,
            title: e.title,
            url: e.videoUrl,
            fileSize: null,
            thumbnailUrl: e.thumbnailUrl,
          ),
        )
        .toList();
  }

  Map<int, bool>? get isCompletedByIndex {
    if (_seasons.isEmpty) return null;
    return {
      for (var i = 0; i < _seasons.length; i++) i: _seasons[i].isCompleted,
    };
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ─── Ações ──────────────────────────────────────────────────────────

  /// Carrega as seasons do banco via watch stream.
  ///
  /// O banco já deve estar populado pelo sync do JSON index
  /// (`PauloFlixService.syncContent`). Se estiver vazio, mostra
  /// estado vazio — o usuário deve sincronizar primeiro.
  Future<void> loadSeasons() async {
    if (_status == PauloFlixEpisodeStatus.loading) return;
    _status = PauloFlixEpisodeStatus.loading;
    _errorMessage = null;
    _safeNotify();

    try {
      // Assina o watch stream (reativo a updates futuros).
      _seasonsSub?.cancel();
      _seasonsSub = _repository
          .watchSeasonsForContent(content.id!)
          .listen(_onSeasonsUpdate);

      _status = PauloFlixEpisodeStatus.loaded;
      _safeNotify();
    } catch (e) {
      log(
        '[PauloFlixEpisodeProgressViewModel] Erro ao carregar seasons: $e',
        name: 'PauloFlixEpisodeProgressViewModel',
        error: e,
      );
      _errorMessage = 'Erro ao carregar temporadas: $e';
      _status = PauloFlixEpisodeStatus.error;
      _safeNotify();
    }
  }

  void selectSeason(int index) {
    if (index == _selectedSeasonIndex) return;
    if (index < 0 || index >= _seasons.length) return;
    _selectedSeasonIndex = index;
    _safeNotify();
    _loadEpisodesForSelected();
  }

  void _onSeasonsUpdate(List<PauloFlixSeasonRecord> seasons) {
    _seasons = seasons;
    if (_selectedSeasonIndex >= _seasons.length) {
      _selectedSeasonIndex = 0;
    }
    if (_seasons.isNotEmpty) {
      _loadEpisodesForSelected();
    }
    _safeNotify();
  }

  void _loadEpisodesForSelected() {
    final season = selectedSeason;
    if (season == null || season.id == null) return;

    if (_episodesBySeason.containsKey(season.id)) {
      _safeNotify();
      return;
    }

    final seasonId = season.id!;
    _episodesSub?.cancel();
    _episodesSub = _repository.watchEpisodesForSeason(seasonId).listen((eps) {
      _episodesBySeason[seasonId] = eps;
      _safeNotify();
    });
  }

  void _clearCache() {
    _episodesBySeason.clear();
    _episodesSub?.cancel();
    _episodesSub = null;
  }

  Future<void> refresh() async {
    _seasonsSub?.cancel();
    _seasonsSub = null;
    _clearCache();
    await loadSeasons();
  }

  @override
  void dispose() {
    _disposed = true;
    _seasonsSub?.cancel();
    _seasonsSub = null;
    _episodesSub?.cancel();
    _episodesSub = null;
    _episodesBySeason.clear();
    super.dispose();
  }
}
