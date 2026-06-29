import 'dart:async';

import '../../domain/repositories/paulo_flix_movie_progress_repository.dart';

/// Service de gravação de progresso de filmes usado pelo player.
///
/// Segue o mesmo padrão do `EpisodeProgressService` mas adaptado
/// para filmes (identificados por `folderName` em vez de
/// `seasonId + episodeNumber`).
///
/// ## Responsabilidades
///
/// 1. Decidir se o player deve retomar de `positionSeconds` ou começar
///    do zero (`shouldResetForResume`).
/// 2. Gravar progresso a cada 5s durante playback.
/// 3. Garantir último save no `dispose` do player (flush).
class MovieProgressService {
  final PauloFlixMovieProgressRepository _repository;
  final String folderName;
  final String serverUrl;
  final String displayName;
  final String? imageUrl;

  /// URL do arquivo de vídeo salva na primeira gravação de progresso.
  /// Permite que a seção "Continue assistindo" navegue diretamente
  /// ao player sem precisar de scraping adicional.
  final String? initialVideoUrl;

  static const Duration _saveInterval = Duration(seconds: 5);
  int _lastSavedPosition = -1;
  bool _videoUrlSaved = false;
  Timer? _timer;

  MovieProgressService({
    required PauloFlixMovieProgressRepository repository,
    required this.folderName,
    required this.serverUrl,
    required this.displayName,
    this.imageUrl,
    this.initialVideoUrl,
  }) : _repository = repository;

  /// Função pura: decide se o player deve começar do zero (reset) ou
  /// retomar de `positionSeconds`.
  ///
  /// **Reset** quando:
  /// - `isCompleted == true` (usuário quer reassistir)
  /// - `positionSeconds / durationSeconds < 0.1` (fechou sem querer)
  ///
  /// **Retomar** caso contrário.
  static bool shouldResetForResume({
    required bool isCompleted,
    required int positionSeconds,
    required int durationSeconds,
  }) {
    if (isCompleted) return true;
    if (durationSeconds <= 0) return false;
    final ratio = positionSeconds / durationSeconds;
    return ratio < 0.1;
  }

  /// Chamado ANTES de `Media.open`. Se retornar `true`, o caller
  /// deve abrir do zero (sem seek).
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
      await _repository.resetProgress(folderName);
      _lastSavedPosition = -1;
    }
    return shouldReset;
  }

  /// Inicia o timer que chama `_save` a cada 5s.
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

  /// Cancela o timer sem flush.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancela o timer E faz último save.
  Future<void> flush({
    required Duration Function() getCurrentPosition,
    required Duration Function() getDuration,
  }) async {
    _timer?.cancel();
    _timer = null;
    await _save(getCurrentPosition, getDuration);
  }

  /// Salva progresso com valores já capturados (sem closures).
  /// Usado pelo player após `stop()` + captura de posição, antes de
  /// descartar o player.
  Future<void> saveProgress({
    required int positionSeconds,
    int? durationSeconds,
  }) async {
    if (positionSeconds == _lastSavedPosition) return;
    _lastSavedPosition = positionSeconds;
    await _repository.updateProgress(
      folderName: folderName,
      serverUrl: serverUrl,
      displayName: displayName,
      imageUrl: imageUrl,
      videoUrl: !_videoUrlSaved ? initialVideoUrl : null,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
    );
    _videoUrlSaved = true;
  }

  Future<void> _save(
    Duration Function() getCurrentPosition,
    Duration Function() getDuration,
  ) async {
    final pos = getCurrentPosition();
    final dur = getDuration();
    if (pos.inSeconds == _lastSavedPosition) return;
    _lastSavedPosition = pos.inSeconds;
    await _repository.updateProgress(
      folderName: folderName,
      serverUrl: serverUrl,
      displayName: displayName,
      imageUrl: imageUrl,
      // Só salva videoUrl na primeira gravação — preserva a URL do
      // vídeo que o usuário começou a assistir para navegação direta
      // ao player na seção "Continue assistindo".
      videoUrl: !_videoUrlSaved ? initialVideoUrl : null,
      positionSeconds: pos.inSeconds,
      durationSeconds: dur.inSeconds > 0 ? dur.inSeconds : null,
    );
    _videoUrlSaved = true;
  }
}
