/// ViewModel para a tela de lista de episódios do PauloFlix.
///
/// Segue o padrão MVVM do projeto: ChangeNotifier com estado reativo
/// para a UI consumir via Consumer/context.watch.
library;

import 'package:flutter/material.dart';

import '../../../data/services/pauloflix_service.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/models/pauloflix_models.dart';

/// Estados possíveis do ViewModel.
enum PauloFlixEpisodeStatus { initial, loading, loaded, error }

/// ViewModel para gerenciar o estado da tela de episódios.
///
/// [Uso]:
/// ```dart
/// // Na tela
/// ChangeNotifierProvider(
///   create: (_) => PauloFlixEpisodeListViewModel(content: content),
///   child: Consumer<PauloFlixEpisodeListViewModel>(
///     builder: (context, vm, _) {
///       if (vm.status == PauloFlixEpisodeStatus.loading) {
///         return CircularProgressIndicator();
///       }
///       // ... construir UI com vm.seasons, vm.episodes, etc.
///     },
///   ),
/// )
/// ```
class PauloFlixEpisodeListViewModel extends ChangeNotifier {
  final PauloFlixContent content;

  PauloFlixEpisodeListViewModel({required this.content});

  // --- Estado ---
  PauloFlixEpisodeStatus _status = PauloFlixEpisodeStatus.initial;
  List<PauloFlixSeason> _seasons = [];
  int _selectedSeasonIndex = 0;
  String? _errorMessage;
  bool _disposed = false;

  // Cache de episódios por índice de temporada
  final Map<int, List<PauloFlixEpisode>> _episodesCache = {};
  final Map<int, bool> _loadingEpisodes = {};
  final Map<int, String?> _episodeErrors = {};

  // --- Getters ---
  PauloFlixEpisodeStatus get status => _status;
  List<PauloFlixSeason> get seasons => _seasons;
  int get selectedSeasonIndex => _selectedSeasonIndex;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == PauloFlixEpisodeStatus.loading;
  bool get hasSeasons => _seasons.isNotEmpty;

  /// Episódios da temporada selecionada.
  List<PauloFlixEpisode> get episodes =>
      _episodesCache[_selectedSeasonIndex] ?? [];

  /// true se os episódios da temporada selecionada estão carregando.
  bool get isLoadingEpisodes =>
      _loadingEpisodes[_selectedSeasonIndex] == true;

  /// Erro ao carregar episódios da temporada selecionada.
  String? get episodeError => _episodeErrors[_selectedSeasonIndex];

  /// Temporada atualmente selecionada.
  PauloFlixSeason? get selectedSeason =>
      _seasons.isNotEmpty ? _seasons[_selectedSeasonIndex] : null;

  // --- Helpers ---

  /// Notifica listeners apenas se o ViewModel ainda não foi disposed.
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // --- Ações ---

  /// Carrega as temporadas do show.
  Future<void> loadSeasons() async {
    _status = PauloFlixEpisodeStatus.loading;
    _errorMessage = null;
    _safeNotify();

    try {
      _seasons = await PauloFlixService.fetchShowSeasons(content.serverUrl);
      if (_disposed) return;

      _status = PauloFlixEpisodeStatus.loaded;

      // Carrega episódios da primeira temporada automaticamente
      if (_seasons.isNotEmpty) {
        _selectedSeasonIndex = 0;
        _safeNotify();
        await loadEpisodes(0);
      } else {
        _safeNotify();
      }
    } catch (e) {
      if (_disposed) return;
      _errorMessage = 'Erro ao carregar temporadas: $e';
      _status = PauloFlixEpisodeStatus.error;
      _safeNotify();
    }
  }

  /// Seleciona uma temporada e carrega seus episódios.
  Future<void> selectSeason(int index) async {
    if (index == _selectedSeasonIndex) return;
    if (index < 0 || index >= _seasons.length) return;

    _selectedSeasonIndex = index;
    _safeNotify();

    // Carrega episódios se ainda não tiver em cache
    await loadEpisodes(index);
  }

  /// Carrega os episódios de uma temporada específica.
  Future<void> loadEpisodes(int seasonIndex) async {
    // Já está em cache
    if (_episodesCache.containsKey(seasonIndex)) return;

    // Já está carregando
    if (_loadingEpisodes[seasonIndex] == true) return;

    _loadingEpisodes[seasonIndex] = true;
    _episodeErrors[seasonIndex] = null;
    _safeNotify();

    try {
      final episodes = await PauloFlixService.fetchSeasonEpisodes(
        _seasons[seasonIndex].url,
      );
      if (_disposed) return;

      _episodesCache[seasonIndex] = episodes;
      _loadingEpisodes[seasonIndex] = false;
      _safeNotify();
    } catch (e) {
      if (_disposed) return;
      _episodeErrors[seasonIndex] = 'Erro ao carregar episódios: $e';
      _loadingEpisodes[seasonIndex] = false;
      _safeNotify();
    }
  }

  /// Limpa o cache de episódios e recarrega a temporada atual.
  Future<void> refresh() async {
    _episodesCache.clear();
    _loadingEpisodes.clear();
    _episodeErrors.clear();
    await loadSeasons();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
