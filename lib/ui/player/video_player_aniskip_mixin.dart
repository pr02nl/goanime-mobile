import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/models/aniskip_models.dart';
import '../../data/services/aniskip_service.dart';
import '../../l10n/app_localizations.dart';
import '../core/utils/episode_utils.dart';

/// Mixin que encapsula a logica de AniSkip (pular intro/outro)
mixin VideoPlayerAniSkipMixin<T extends StatefulWidget> on State<T> {
  SkipTimes? skipTimes;
  bool showSkipButton = false;
  String skipButtonLabel = '';
  Timer? positionTimer;
  Timer? skipButtonAutoHideTimer;
  int skipTimesRetryCount = 0;
  String? skipButtonActiveSegment;
  bool skipButtonDismissed = false;
  DateTime? lastAutoHideTime;
  String? activeEpisodeKey;

  static const int maxSkipTimesRetries = 3;
  static const double skipLeadSeconds = 3.0;
  static const double skipHoldSeconds = 2.0;
  static const Duration skipAutoHideDuration = Duration(seconds: 15);

  bool isActiveEpisode(String? key);
  Player? get player;
  BuildContext get localizationContext;

  Future<void> loadSkipTimes({
    int? episodeLengthSeconds,
    required int? malId,
    required int? anilistId,
    required String episodeNumber,
  }) async {
    final requestKey = activeEpisodeKey;
    if (!isActiveEpisode(requestKey)) {
      debugPrint('[AniSkip] Skipping load - episode changed.');
      return;
    }

    debugPrint('[AniSkip] Checking anime data...');
    debugPrint('[AniSkip] AniList ID: $anilistId');
    debugPrint('[AniSkip] MAL ID: $malId');

    if (malId == null && anilistId == null) {
      debugPrint('[AniSkip] No MAL ID or AniList ID available');
      return;
    }

    final episodeNumberStr = extractEpisodeNumber(episodeNumber);
    final episodeNumberParsed = int.tryParse(episodeNumberStr);

    if (episodeNumberParsed == null) {
      debugPrint('[AniSkip] Could not parse episode number: $episodeNumberStr');
      return;
    }

    final resolvedEpisodeLength =
        episodeLengthSeconds ?? player?.state.duration.inSeconds;

    if (resolvedEpisodeLength == null || resolvedEpisodeLength <= 0) {
      debugPrint('[AniSkip] Episode length unavailable');
      if (skipTimesRetryCount < maxSkipTimesRetries) {
        skipTimesRetryCount++;
        Future.delayed(const Duration(seconds: 1), () {
          if (!isActiveEpisode(requestKey) || !mounted) return;
          loadSkipTimes(
            episodeLengthSeconds: player?.state.duration.inSeconds,
            malId: malId,
            anilistId: anilistId,
            episodeNumber: episodeNumber,
          );
        });
      }
      return;
    }

    skipTimesRetryCount = 0;
    debugPrint(
      '[AniSkip] Fetching skip times for Episode: $episodeNumberParsed',
    );

    try {
      final skipTimesResult = await AniSkipService.getSkipTimesMultiStrategy(
        malId: malId,
        anilistId: anilistId,
        episodeNumber: episodeNumberParsed,
        episodeLengthSeconds: resolvedEpisodeLength,
      );

      if (mounted && isActiveEpisode(requestKey)) {
        skipButtonAutoHideTimer?.cancel();
        setState(() {
          skipTimes = skipTimesResult;
          skipButtonActiveSegment = null;
          skipButtonDismissed = false;
          lastAutoHideTime = null;
          showSkipButton = false;
          skipButtonLabel = '';
        });

        if (isActiveEpisode(requestKey)) {
          if (skipTimesResult.hasSkipTimes) {
            debugPrint('[AniSkip] Skip times loaded successfully!');
            startPositionTimer();
            checkSkipButtonVisibility();
          } else {
            debugPrint('[AniSkip] No skip times found for this episode');
            startPositionTimer();
          }
        }
      }
    } catch (e) {
      debugPrint('[AniSkip] Error loading skip times: $e');
    }
  }

  void startPositionTimer() {
    positionTimer?.cancel();
    final timerKey = activeEpisodeKey;

    Null Function(Timer timer) positionTimerTick(String? timerKey) {
      return (Timer timer) {
        if (!isActiveEpisode(timerKey)) {
          timer.cancel();
          return;
        }
        checkSkipButtonVisibility();
      };
    }

    positionTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      positionTimerTick(timerKey),
    );
  }

  void checkSkipButtonVisibility() {
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

    final inOpWindow =
        skipTimes?.op != null &&
        isWithinSkipWindow(skipTimes?.op, currentSeconds);
    final inEdWindow =
        skipTimes?.ed != null &&
        isWithinSkipWindow(skipTimes?.ed, currentSeconds);

    if (inOpWindow) {
      activeSegment = 'op';
      label = AppLocalizations.of(localizationContext).skipIntro;
    } else if (inEdWindow) {
      activeSegment = 'ed';
      label = AppLocalizations.of(localizationContext).skipOutro;
    }

    if (skipButtonDismissed && !inOpWindow && !inEdWindow) {
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
      scheduleSkipButtonAutoHide(activeSegment);
    }
  }

  void skipIntroOutro() {
    final position = player?.state.position;
    if (position == null || skipTimes == null) return;

    final currentSeconds = position.inMilliseconds / 1000.0;
    Duration? skipToPosition;
    String skipType = '';

    if (isWithinSkipWindow(skipTimes!.op, currentSeconds)) {
      final targetSeconds = skipTimes!.op!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'intro';
    } else if (isWithinSkipWindow(skipTimes!.ed, currentSeconds)) {
      final targetSeconds = skipTimes!.ed!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'outro';
    } else {
      return;
    }

    player?.seek(skipToPosition);
    skipButtonAutoHideTimer?.cancel();
    skipButtonDismissed = true;
    setState(() {
      showSkipButton = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skipType == 'intro' ? 'Intro pulada!' : 'Encerramento pulado!',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        ),
      );
    }
  }

  bool isWithinSkipWindow(Skip? skip, double currentSeconds) {
    if (skip == null) return false;
    final startBoundary = (skip.start - skipLeadSeconds).clamp(
      0,
      double.infinity,
    );
    final endBoundary = skip.end + skipHoldSeconds;
    return currentSeconds >= startBoundary && currentSeconds <= endBoundary;
  }

  void scheduleSkipButtonAutoHide(String segmentKey) {
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

  void cleanupAniSkip() {
    positionTimer?.cancel();
    skipButtonAutoHideTimer?.cancel();
  }

  @override
  void dispose() {
    cleanupAniSkip();
    super.dispose();
  }
}
