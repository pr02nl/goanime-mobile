/// ViewModel para a tela de episódios do PauloFlix com persistência de
/// progresso (Fase 3 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`).
///
/// **Substitui o `PauloFlixEpisodeListViewModel` legacy** (que mantinha
/// cache in-memory). Esta versão:
/// 1. Sincroniza seasons/episodes on-demand via `syncService` (Fase 1.4).
/// 2. Lê seasons/episodes do banco via `watchSeasonsForContent` /
///    `watchEpisodesForSeason` (streams reativas — atualizam UI
///    automaticamente).
/// 3. Expõe `isCompletedByIndex` derivado das seasons para alimentar
///    o `PauloflixSeasonSelector` (Task 3.3).
/// 4. Reage a updates do player (`updateProgress`/`resetProgress`) sem
///    precisar re-inicializar a tela.
///
/// **Uso:**
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => PauloFlixEpisodeProgressViewModel(
///     content: content,
///     repository: context.read<PauloFlixEpisodeProgressRepository>(),
///     syncService: context.read<PauloFlixEpisodeSyncService>(),
///   )..loadSeasons(),
///   child: ...,
/// )
/// ```
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/services/paulo_flix_episode_sync_service.dart';
import '../../../domain/models/paulo_flix_episode_record.dart';
import '../../../domain/models/paulo_flix_season_record.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';

/// Estados possíveis do ViewModel. Mantido do VM legacy para
/// compatibilidade com a UI existente.
enum PauloFlixEpisodeStatus { initial, loading, loaded, error }

class PauloFlixEpisodeProgressViewModel extends ChangeNotifier {
  final PauloFlixContent content;
  final PauloFlixEpisodeProgressRepository _repository;

  /// Opcional. Quando `null`, o VM assume que seasons/episodes já
  /// estão no banco (vindos de um sync anterior ou do home). O
  /// `loadSeasons` nesse caso apenas lê do banco.
  final PauloFlixEpisodeSyncService? _syncService;

  PauloFlixEpisodeProgressViewModel({
    required this.content,
    required PauloFlixEpisodeProgressRepository repository,
    PauloFlixEpisodeSyncService? syncService,
  }) : _repository = repository,
       _syncService = syncService;

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

  /// Episodes da season selecionada (do cache em memória,
  /// atualizado pelo stream).
  List<PauloFlixEpisodeRecord> get episodes {
    if (_seasons.isEmpty) return const [];
    final i = _selectedSeasonIndex.clamp(0, _seasons.length - 1);
    return _episodesBySeason[_seasons[i].id] ?? const [];
  }

  /// Temporada atualmente selecionada (record de banco).
  PauloFlixSeasonRecord? get selectedSeason {
    if (_seasons.isEmpty) return null;
    final i = _selectedSeasonIndex.clamp(0, _seasons.length - 1);
    return _seasons[i];
  }

  /// `true` se a season selecionada está marcada como completa no banco.
  bool get isSelectedSeasonCompleted {
    final s = selectedSeason;
    return s?.isCompleted ?? false;
  }

  /// Mapa `seasonIndex → isCompleted` para o `PauloflixSeasonSelector`.
  ///
  /// `null` enquanto as seasons não foram carregadas. Atualiza
  /// automaticamente via stream de seasons.
  ///
  /// **Constrói o map diretamente** (sem inversão de chaves) — mais
  /// legível e O(n) sem o overhead de `.map` adicional.
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

  /// Carrega as seasons do banco. Se `syncService` foi injetado e o
  /// banco está vazio, faz sync HTTP primeiro.
  ///
  /// Idempotente: chamar 2x não duplica seasons (UNIQUE em
  /// `contentId+seasonNumber`).
  Future<void> loadSeasons() async {
    if (_status == PauloFlixEpisodeStatus.loading) return;
    _status = PauloFlixEpisodeStatus.loading;
    _errorMessage = null;
    _safeNotify();

    try {
      // 1. Verifica se já tem seasons no banco.
      final existing = await _repository.getSeasonsForContent(content.id!);

      // 2. Se banco vazio E syncService disponível → HTTP.
      if (existing.isEmpty && _syncService != null && content.id != null) {
        await _syncService.syncSeasonEpisodes(
          contentId: content.id!,
          contentServerUrl: content.serverUrl,
        );
      }

      // 3. Assina o watch stream (reativo a updates futuros).
      _seasonsSub?.cancel();
      _seasonsSub = _repository
          .watchSeasonsForContent(content.id!)
          .listen(_onSeasonsUpdate);

      _status = PauloFlixEpisodeStatus.loaded;
      _safeNotify();
    } catch (e) {
      _errorMessage = 'Erro ao carregar temporadas: $e';
      _status = PauloFlixEpisodeStatus.error;
      _safeNotify();
    }
  }

  /// Seleciona uma temporada e carrega os episodes dela.
  ///
  /// Idempotente: selecionar a mesma season não recarrega. Trocar
  /// cancela o subscription anterior e cria novo.
  void selectSeason(int index) {
    if (index == _selectedSeasonIndex) return;
    if (index < 0 || index >= _seasons.length) return;
    _selectedSeasonIndex = index;
    _safeNotify();
    _loadEpisodesForSelected();
  }

  void _onSeasonsUpdate(List<PauloFlixSeasonRecord> seasons) {
    _seasons = seasons;
    // Se a season selecionada sumiu (caso raro), reseta para 0.
    if (_selectedSeasonIndex >= _seasons.length) {
      _selectedSeasonIndex = 0;
    }
    // Carrega episodes da season atual (se ainda não temos).
    if (_seasons.isNotEmpty) {
      _loadEpisodesForSelected();
    }
    _safeNotify();
  }

  void _loadEpisodesForSelected() {
    final season = selectedSeason;
    if (season == null || season.id == null) return;

    // Se já temos cache, não re-assina.
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

  /// Limpa cache em memória + cancela subscriptions. Chamado em
  /// `dispose` ou `refresh()`.
  void _clearCache() {
    _episodesBySeason.clear();
    _episodesSub?.cancel();
    _episodesSub = null;
  }

  /// Recarrega tudo (útil em pull-to-refresh).
  Future<void> refresh() async {
    _seasonsSub?.cancel();
    _seasonsSub = null;
    _clearCache();
    await loadSeasons();
  }

  @override
  void dispose() {
    _disposed = true;
    // Cancela subscriptions ANTES de limpar o cache (evita
    // concurrent modification se o stream emitir durante o cancel).
    _seasonsSub?.cancel();
    _seasonsSub = null;
    _episodesSub?.cancel();
    _episodesSub = null;
    _episodesBySeason.clear();
    super.dispose();
  }
}
