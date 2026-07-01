import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/logger/app_logger.dart';
import '../../data/models/introdb_models.dart';
import '../../data/services/introdb_service.dart';
import '../../l10n/app_localizations.dart';

/// Mixin que encapsula a lógica de detecção de intro/outro via
/// [TheIntroDB](https://theintrodb.org).
///
/// Substitui o antigo `VideoPlayerAniSkipMixin` que dependia de
/// `malId`/`anilistId` — agora usamos apenas `tmdbId` (disponível
/// nos JSON index do PauloFlix).
///
/// ## Responsabilidades
///
/// 1. Carregar segmentos de intro/outro da API TheIntroDB.
/// 2. Monitorar a posição do player via timer periódico (500ms).
/// 3. Exibir/ocultar o botão "Pular Intro" / "Pular Encerramento".
/// 4. Executar o seek ao clicar no botão.
/// 5. Auto-hide do botão após 15s sem interação.
mixin VideoPlayerIntroDbMixin<T extends StatefulWidget> on State<T> {
  /// Lista de segmentos carregados da API.
  IntroDbResponse? _introDbSegments;

  /// Se `true`, o botão de skip está visível.
  bool showSkipButton = false;

  /// Label atual do botão (ex.: "Pular Intro").
  String skipButtonLabel = '';

  /// Timer de 500ms para verificar posição.
  Timer? positionTimer;

  /// Timer de auto-hide do botão de skip.
  Timer? skipButtonAutoHideTimer;

  /// Chave do segmento ativo no momento (`intro`, `credits` ou `null`).
  String? skipButtonActiveSegment;

  /// Se o usuário já dispensou o botão de skip manualmente.
  bool skipButtonDismissed = false;

  /// Timestamp do último auto-hide.
  DateTime? lastAutoHideTime;

  /// Chave de identificação do episódio ativo (evita race conditions
  /// em trocas rápidas de episódio).
  String? activeEpisodeKey;

  static const double skipLeadSeconds = 3.0;
  static const double skipHoldSeconds = 2.0;
  static const Duration skipAutoHideDuration = Duration(seconds: 15);

  /// Verifica se o episódio identificado por [key] ainda é o ativo.
  bool isActiveEpisode(String? key);

  /// Getter para a instância do Player.
  Player? get player;

  /// Contexto para localização.
  BuildContext get localizationContext;

  // ─── Carregamento de segmentos ─────────────────────────────────

  /// Carrega os segmentos de intro/outro da API TheIntroDB.
  ///
  /// [tmdbId] é o ID do TMDB (filme ou série).
  /// [seasonNumber] e [episodeNumber] são opcionais — quando ambos
  /// fornecidos, a consulta é para um episódio específico de série.
  /// Quando omitidos, a consulta é para um filme.
  Future<void> loadSkipSegments({
    required int? tmdbId,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    const log = AppLogger('IntroDb');

    final requestKey = activeEpisodeKey;
    if (!isActiveEpisode(requestKey)) {
      log.debug('Skipping load - episode changed.');
      return;
    }

    if (tmdbId == null) {
      log.debug('No tmdbId available');
      return;
    }

    log.debug(
      'Fetching segments for tmdbId=$tmdbId '
      'season=$seasonNumber episode=$episodeNumber',
    );

    try {
      final result = await IntroDbService.getMedia(
        tmdbId: tmdbId,
        season: seasonNumber,
        episode: episodeNumber,
      );

      if (mounted && isActiveEpisode(requestKey)) {
        skipButtonAutoHideTimer?.cancel();
        setState(() {
          _introDbSegments = result;
          skipButtonActiveSegment = null;
          skipButtonDismissed = false;
          lastAutoHideTime = null;
          showSkipButton = false;
          skipButtonLabel = '';
        });

        if (isActiveEpisode(requestKey)) {
          if (result != null && result.hasAnySegment) {
            log.debug('Segments loaded successfully!');
            startPositionTimer();
          } else {
            log.debug('No segments found for this media');
          }
        }
      }
    } catch (e, st) {
      log.error('Error loading segments', e, st);
    }
  }

  // ─── Timer de posição ──────────────────────────────────────────

  /// Inicia o timer periódico de 500ms para verificar a posição do
  /// player e atualizar a visibilidade do botão de skip.
  void startPositionTimer() {
    positionTimer?.cancel();
    final timerKey = activeEpisodeKey;

    positionTimer = Timer.periodic(const Duration(milliseconds: 500), (
      Timer timer,
    ) {
      if (!isActiveEpisode(timerKey)) {
        timer.cancel();
        return;
      }
      _checkSkipButtonVisibility();
    });
  }

  // ─── Verificação de visibilidade ───────────────────────────────

  /// Verifica se a posição atual do player está dentro de uma janela
  /// de skip (intro ou créditos) e atualiza o botão.
  void _checkSkipButtonVisibility() {
    final currentPlayer = player;
    if (currentPlayer == null ||
        currentPlayer.state.duration == Duration.zero) {
      return;
    }

    final position = currentPlayer.state.position;

    if (!currentPlayer.state.playing) {
      if (showSkipButton) {
        setState(() {
          showSkipButton = false;
          skipButtonLabel = '';
        });
      }
      return;
    }

    final currentSeconds = position.inMilliseconds / 1000.0;
    String? activeSegment;
    String label = '';

    // Verifica se está na janela de intro (primeiro segmento).
    final intro = _introDbSegments?.intro;
    if (intro != null && intro.isNotEmpty) {
      final s = intro.first;
      if (_isWithinWindow(s.startSec, s.endSec, currentSeconds)) {
        activeSegment = 'intro';
        label = AppLocalizations.of(localizationContext).skipIntro;
      }
    }

    // Verifica se está na janela de créditos (primeiro segmento).
    if (activeSegment == null) {
      final credits = _introDbSegments?.credits;
      if (credits != null && credits.isNotEmpty) {
        final s = credits.first;
        if (_isWithinWindow(s.startSec, s.endSec, currentSeconds)) {
          activeSegment = 'credits';
          label = AppLocalizations.of(localizationContext).skipOutro;
        }
      }
    }

    if (skipButtonDismissed && activeSegment == null) {
      skipButtonDismissed = false;
      skipButtonActiveSegment = null;
    }

    if (skipButtonActiveSegment != activeSegment) {
      skipButtonAutoHideTimer?.cancel();
      skipButtonActiveSegment = activeSegment;
      if (activeSegment != null) {
        skipButtonDismissed = false;
        lastAutoHideTime = null;
      }
    }

    if (activeSegment == null) {
      if (showSkipButton || skipButtonLabel.isNotEmpty) {
        setState(() {
          showSkipButton = false;
          skipButtonLabel = '';
        });
      }
      return;
    }

    if (skipButtonDismissed) {
      if (showSkipButton) {
        setState(() {
          showSkipButton = false;
          skipButtonLabel = '';
        });
      }
      return;
    }

    if (lastAutoHideTime != null) {
      final timeSinceAutoHide = DateTime.now().difference(lastAutoHideTime!);
      if (timeSinceAutoHide.inSeconds < 30) {
        if (showSkipButton) {
          setState(() {
            showSkipButton = false;
            skipButtonLabel = '';
          });
        }
        return;
      } else {
        lastAutoHideTime = null;
      }
    }

    if (!showSkipButton || label != skipButtonLabel) {
      setState(() {
        showSkipButton = true;
        skipButtonLabel = label;
      });
      _scheduleSkipButtonAutoHide(activeSegment);
    }
  }

  // ─── Ação de skip ──────────────────────────────────────────────

  /// Executa o seek para o final do segmento ativo (intro ou créditos).
  void skipIntroOutro() {
    final position = player?.state.position;
    if (position == null) return;

    final currentSeconds = position.inMilliseconds / 1000.0;
    Duration? skipToPosition;

    // Tenta intro
    final intro = _introDbSegments?.intro;
    if (intro != null && intro.isNotEmpty) {
      final s = intro.first;
      if (_isWithinWindow(s.startSec, s.endSec, currentSeconds)) {
        skipToPosition = Duration(milliseconds: (s.endSec * 1000).round());
      }
    }

    // Tenta créditos
    if (skipToPosition == null) {
      final credits = _introDbSegments?.credits;
      if (credits != null && credits.isNotEmpty) {
        final s = credits.first;
        if (_isWithinWindow(s.startSec, s.endSec, currentSeconds)) {
          skipToPosition = Duration(milliseconds: (s.endSec * 1000).round());
        }
      }
    }

    if (skipToPosition == null) return;

    player?.seek(skipToPosition);
    skipButtonAutoHideTimer?.cancel();
    skipButtonDismissed = true;
    setState(() {
      showSkipButton = false;
    });
  }

  // ─── Helpers ───────────────────────────────────────────────────

  /// Verifica se [currentSeconds] está dentro da janela de skip
  /// definida por [startSec] e [endSec], com margem de tolerância.
  bool _isWithinWindow(double startSec, double endSec, double currentSeconds) {
    final startBoundary = (startSec - skipLeadSeconds).clamp(
      0.0,
      double.infinity,
    );
    final endBoundary = endSec + skipHoldSeconds;
    return currentSeconds >= startBoundary && currentSeconds <= endBoundary;
  }

  void _scheduleSkipButtonAutoHide(String segmentKey) {
    skipButtonAutoHideTimer?.cancel();
    final episodeKey = activeEpisodeKey;
    skipButtonAutoHideTimer = Timer(skipAutoHideDuration, () {
      if (!isActiveEpisode(episodeKey) ||
          skipButtonActiveSegment != segmentKey ||
          !mounted) {
        return;
      }
      lastAutoHideTime = DateTime.now();
      setState(() {
        showSkipButton = false;
        skipButtonLabel = '';
      });
    });
  }

  // ─── Cleanup ───────────────────────────────────────────────────

  /// Limpa timers ao trocar de episódio.
  void cleanupIntroDb() {
    positionTimer?.cancel();
    skipButtonAutoHideTimer?.cancel();
  }

  @override
  void dispose() {
    cleanupIntroDb();
    super.dispose();
  }
}
