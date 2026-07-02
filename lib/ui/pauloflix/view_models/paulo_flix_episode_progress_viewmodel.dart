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
  /// Limitado a 3 seasons para evitar crescimento infinito — seasons mais
  /// antigas são removidas quando o limite é excedido.
  final Map<int, List<PauloFlixEpisodeRecord>> _episodesBySeason = {};

  /// Máximo de seasons cacheadas em `_episodesBySeason`.
  static const int _maxCachedSeasons = 3;

  /// Ordem de acesso das seasons (para evict LRU).
  final List<int> _seasonAccessOrder = [];

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
    } catch (e, st) {
      log(
        '[PauloFlixEpisodeProgressViewModel] Erro ao carregar seasons: $e',
        name: 'PauloFlixEpisodeProgressViewModel',
        error: e,
        stackTrace: st,
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

  void _evictOldestSeason() {
    while (_episodesBySeason.length >= _maxCachedSeasons) {
      final oldest = _seasonAccessOrder.removeAt(0);
      _episodesBySeason.remove(oldest);
    }
  }

  void _loadEpisodesForSelected() {
    final season = selectedSeason;
    if (season == null || season.id == null) return;

    final seasonId = season.id!;

    // Atualiza ordem de acesso (LRU).
    _seasonAccessOrder.remove(seasonId);
    _seasonAccessOrder.add(seasonId);

    // Evita cache infinito — só faz evicção se for uma nova season
    // (cache miss). Em cache hit, preserva os dados das outras seasons.
    if (!_episodesBySeason.containsKey(seasonId)) {
      _evictOldestSeason();
    }

    // ═══════════════════════════════════════════════════════════════════
    // SEMPRE recria a subscrição no stream, mesmo se os episódios já
    // estão em cache. Antes, retornávamos cedo no cache hit sem criar
    // uma nova subscrição, o que quebrava a reatividade: se o usuário
    // trocasse de temporada e voltasse, o stream anterior já havia sido
    // cancelado e a UI nunca recebia updates de progresso ao retornar
    // do player.
    // ═══════════════════════════════════════════════════════════════════
    _episodesSub?.cancel();
    _episodesSub = _repository.watchEpisodesForSeason(seasonId).listen((eps) {
      _episodesBySeason[seasonId] = eps;
      _safeNotify();
    });

    // Se já temos dados em cache, notifica para exibir imediatamente
    // (evita flicker de "vazio" enquanto o stream não emite).
    if (_episodesBySeason.containsKey(seasonId)) {
      _safeNotify();
    }
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
    _seasonAccessOrder.clear();
    _seasonsSub?.cancel();
    _seasonsSub = null;
    _episodesSub?.cancel();
    _episodesSub = null;
    _episodesBySeason.clear();
    super.dispose();
  }
}
