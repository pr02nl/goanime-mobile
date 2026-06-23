import 'dart:async';

import '../../domain/repositories/paulo_flix_episode_progress_repository.dart';

/// Service de gravação de progresso de episódio usado pelo player.
///
/// **Fase 2.1 do plano**
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`.
///
/// ## Por que "Service" (e não "Recorder" no nome) e por que em `data/services/`?
///
/// Seguindo o padrão do projeto:
/// - `PauloFlixEpisodeSyncService` (sync HTTP)
/// - `DownloadService` (downloads locais)
/// - `TmdbService` (cache de gêneros)
/// - **Nomenclatura**: todos terminam em `Service` (sem "Recorder"/"Manager"/"Helper" no nome).
/// - **Localização**: `lib/data/services/` — services de I/O e persistência.
///   Nada de UI aqui; o player **consome** este service via injeção.
///
/// ## Responsabilidades
///
/// 1. Decidir se o player deve retomar de `positionSeconds` ou começar do
///    zero (`shouldResetForResume` — função pura testável).
/// 2. Gravar progresso a cada 5s durante playback (timer periódico).
/// 3. Garantir último save no `dispose` do player (flush).
///
/// ## Design: o service NÃO conhece `Player`/`VideoController`
///
/// Recebe `getCurrentPosition`/`getDuration` como callbacks. Vantagem:
/// 100% testável sem mockar `media_kit`. O player passa closures que
/// retornam `_player!.state.position`/`_player!.state.duration`.
///
/// ## Quando usar
///
/// ```dart
/// final service = EpisodeProgressService(
///   repo: context.read<PauloFlixEpisodeProgressRepository>(),
///   seasonId: routeData.seasonId!,
///   episodeNumber: routeData.episodeNumber!,
/// );
/// final shouldReset = await service.prepareResumeOrReset(...);
/// // ...abre o vídeo...
/// service.start(getPos: getPos, getDur: getDur);
/// // ...no dispose:
/// await service.flush(getPos: getPos, getDur: getDur);
/// ```
class EpisodeProgressService {
  final PauloFlixEpisodeProgressRepository _repository;
  final int seasonId;
  final int episodeNumber;

  /// Intervalo entre gravações durante playback.
  static const Duration _saveInterval = Duration(seconds: 5);

  /// Última posição gravada (segundos). `-1` = nunca gravou.
  /// Usado para deduplicar saves: se a posição não mudou, não chama
  /// o repo.
  int _lastSavedPosition = -1;

  Timer? _timer;

  EpisodeProgressService({
    required PauloFlixEpisodeProgressRepository repo,
    required this.seasonId,
    required this.episodeNumber,
  }) : _repository = repo;

  // ═══════════════════════════════════════════════════════════════════════
  // Decisão 6: heurística de reset vs retomar (função pura)
  // ═══════════════════════════════════════════════════════════════════════

  /// Função pura (testável diretamente) que decide se o player deve
  /// começar do zero (reset) ou retomar de `positionSeconds` antes do
  /// `Media.open`.
  ///
  /// **Reset** quando:
  /// - `isCompleted == true` (usuário quer reassistir)
  /// - `positionSeconds / durationSeconds < 0.1` (provavelmente fechou
  ///   sem querer)
  ///
  /// **Retomar** caso contrário (parou intencionalmente entre 10% e 90%).
  static bool shouldResetForResume({
    required bool isCompleted,
    required int positionSeconds,
    required int durationSeconds,
  }) {
    if (isCompleted) return true;
    if (durationSeconds <= 0) {
      // Sem info de duração, não sabemos o ratio. Retoma do 0 (não
      // sobrescreve nada).
      return false;
    }
    final ratio = positionSeconds / durationSeconds;
    return ratio < 0.1;
  }

  /// Chamado **ANTES** de `Media.open`. Se retornar `true`, o caller
  /// deve abrir do zero (sem seek). Se retornar `false`, o caller deve
  /// abrir normal e depois fazer `player.seek(positionSeconds)`.
  ///
  /// Se reset: chama `repo.resetProgress` (zera `positionSeconds`/
  /// `isCompleted` no banco) e força o próximo save (`_lastSavedPosition
  /// = -1`).
  Future<bool> prepareResumeOrReset({
    required bool isCompleted,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    final shouldReset = shouldResetForResume(
      isCompleted: isCompleted,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
    );
    if (shouldReset) {
      await _repository.resetProgress(
        seasonId: seasonId,
        episodeNumber: episodeNumber,
      );
      _lastSavedPosition = -1; // força próximo save
    }
    return shouldReset;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Timer periódico
  // ═══════════════════════════════════════════════════════════════════════

  /// Inicia o timer que chama `_save` a cada 5s.
  ///
  /// [getCurrentPosition] deve retornar a posição atual do player.
  /// [getDuration] deve retornar a duração total do vídeo.
  ///
  /// Para parar, use [stop] (sem flush) ou [flush] (com último save).
  void start({
    required Duration Function() getCurrentPosition,
    required Duration Function() getDuration,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(
      _saveInterval,
      (_) => _save(getCurrentPosition, getDuration),
    );
  }

  /// Cancela o timer sem flush. Use [flush] se quiser último save.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Chamado em `dispose` do player. Cancela o timer E faz último save.
  Future<void> flush({
    required Duration Function() getCurrentPosition,
    required Duration Function() getDuration,
  }) async {
    _timer?.cancel();
    _timer = null;
    await _save(getCurrentPosition, getDuration);
  }

  Future<void> _save(
    Duration Function() getCurrentPosition,
    Duration Function() getDuration,
  ) async {
    final pos = getCurrentPosition();
    final dur = getDuration();
    // Deduplicação: se a posição não mudou, evita write desnecessário.
    if (pos.inSeconds == _lastSavedPosition) return;
    _lastSavedPosition = pos.inSeconds;
    await _repository.updateProgress(
      seasonId: seasonId,
      episodeNumber: episodeNumber,
      positionSeconds: pos.inSeconds,
      durationSeconds: dur.inSeconds > 0 ? dur.inSeconds : null,
    );
  }
}
