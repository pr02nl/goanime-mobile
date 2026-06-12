import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../google_video_proxy.dart';
import '../l10n/app_localizations.dart';
import '../models/anime.dart';
import '../models/aniskip_models.dart';
import '../models/episode.dart';
import '../services/allanime_service.dart';
import '../services/anime_service.dart';
import '../services/aniskip_service.dart';
import '../theme/app_colors.dart';
import '../widgets/skip_button.dart';
import '../utils/tv_detector.dart';
import 'blogger_webview_screen.dart';

// Function to extract only episode number from full text
String _extractEpisodeNumber(String episodeText) {
  // Try to extract number from text (e.g.: "Dandadan - Episódio 5" -> "5")
  final patterns = [
    RegExp(r'Episódio\s*(\d+)', caseSensitive: false),
    RegExp(r'Episode\s*(\d+)', caseSensitive: false),
    RegExp(r'Ep\.?\s*(\d+)', caseSensitive: false),
    RegExp(r'-\s*(\d+)$'),
    RegExp(r'\d+'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(episodeText);
    if (match != null) {
      return match.group(1) ?? match.group(0) ?? episodeText;
    }
  }

  return episodeText;
}

class ModernVideoPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;

  const ModernVideoPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
    this.anime,
  });

  @override
  State<ModernVideoPlayerScreen> createState() =>
      _ModernVideoPlayerScreenState();
}

class _ModernVideoPlayerScreenState extends State<ModernVideoPlayerScreen> {
  Player? _player;
  VideoController? _videoController;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentVideoUrl;
  Map<String, String>? _currentVideoHeaders;
  bool _showWebViewOption = false;
  String? _bloggerVideoUrl;
  GoogleVideoProxy? _googleVideoProxy;
  bool _isGoogleStream = false;

  // AniSkip related variables
  SkipTimes? _skipTimes;
  bool _showSkipButton = false;
  String _skipButtonLabel = '';
  Timer? _positionTimer;
  Timer? _skipButtonAutoHideTimer;
  int _skipTimesRetryCount = 0;
  static const int _maxSkipTimesRetries = 3;
  static const double _skipLeadSeconds = 3.0;
  static const double _skipHoldSeconds = 2.0;
  static const Duration _skipAutoHideDuration = Duration(seconds: 15);
  String? _skipButtonActiveSegment;
  bool _skipButtonDismissed = false;
  DateTime? _lastAutoHideTime;
  String? _activeEpisodeKey;

  String _buildEpisodeKey(ModernVideoPlayerScreen target) {
    final anime = target.anime;
    final buffer = StringBuffer()
      ..write(target.animeTitle)
      ..write('::')
      ..write(target.episode.number)
      ..write('::')
      ..write(target.episode.url);

    if (anime != null) {
      final identifiers = <String?>[
        anime.anilistId?.toString(),
        anime.malId?.toString(),
        anime.allAnimeId,
        anime.url,
      ];

      final extraIdentifier = identifiers.firstWhere(
        (value) => value != null && value.isNotEmpty,
        orElse: () => null,
      );

      if (extraIdentifier != null) {
        buffer
          ..write('::')
          ..write(extraIdentifier);
      }
    }

    return buffer.toString();
  }

  bool _isActiveEpisode(String? key) {
    if (key == null) {
      return false;
    }
    return mounted && _activeEpisodeKey == key;
  }

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTVFullscreen();
    });
  }

  void _setupTVFullscreen() async {
    if (!Platform.isAndroid) return;
    // Usar TVDetector para detectar TV
    final isTV = await TVDetector.isTV;
    if (isTV) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void didUpdateWidget(covariant ModernVideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousKey = _buildEpisodeKey(oldWidget);
    final nextKey = _buildEpisodeKey(widget);

    if (previousKey != nextKey) {
      debugPrint(
        '[VideoPlayer] 🔄 Episode context changed: $previousKey → $nextKey',
      );
      debugPrint('[VideoPlayer] Reinitializing player for new episode...');

      // Force a clean reinitialization
      _positionTimer?.cancel();
      _skipButtonAutoHideTimer?.cancel();
      _skipButtonActiveSegment = null;
      _skipButtonDismissed = false;
      _lastAutoHideTime = null;
      _skipTimes = null;
      _showSkipButton = false;
      _skipButtonLabel = '';

      _initializeVideoPlayer();
    }
  }

  /// Load skip times from AniSkip API using multiple strategies
  Future<void> _loadSkipTimes({int? episodeLengthSeconds}) async {
    final requestKey = _activeEpisodeKey;
    if (!_isActiveEpisode(requestKey)) {
      debugPrint('[AniSkip] ⏭️  Skipping load - episode changed.');
      return;
    }

    final malId = widget.anime?.malId;
    final anilistId = widget.anime?.anilistId;

    // Debug: Show anime info
    debugPrint('[AniSkip] 🔍 Checking anime data...');
    debugPrint('[AniSkip] Anime: ${widget.animeTitle}');
    debugPrint('[AniSkip] Source: ${widget.anime?.sourceName}');
    debugPrint(
      '[AniSkip] Has aniListData: ${widget.anime?.aniListData != null}',
    );
    debugPrint('[AniSkip] AniList ID: $anilistId');
    debugPrint('[AniSkip] MAL ID: $malId');

    if (malId == null && anilistId == null) {
      debugPrint(
        '[AniSkip] ⚠️  No MAL ID or AniList ID available - skipping AniSkip',
      );
      debugPrint(
        '[AniSkip] 💡 Tip: This anime needs to have at least one ID in AniList database',
      );
      return;
    }

    final episodeNumberStr = _extractEpisodeNumber(widget.episode.number);
    final episodeNumber = int.tryParse(episodeNumberStr);

    if (episodeNumber == null) {
      debugPrint(
        '[AniSkip] ⚠️  Could not parse episode number: $episodeNumberStr',
      );
      return;
    }

    final resolvedEpisodeLength =
        episodeLengthSeconds ?? _player?.state.duration.inSeconds;

    if (resolvedEpisodeLength == null || resolvedEpisodeLength <= 0) {
      debugPrint(
        '[AniSkip] ⚠️  Episode length unavailable (got: $resolvedEpisodeLength).',
      );
      if (_skipTimesRetryCount < _maxSkipTimesRetries) {
        _skipTimesRetryCount++;
        debugPrint(
          '[AniSkip] 🔁 Retrying to load skip times (#$_skipTimesRetryCount)…',
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (!_isActiveEpisode(requestKey)) {
            return;
          }
          if (mounted) {
            _loadSkipTimes(
              episodeLengthSeconds: _player?.state.duration.inSeconds,
            );
          }
        });
      } else {
        debugPrint(
          '[AniSkip] ❌ Gave up retrying skip times due to missing duration.',
        );
      }
      return;
    }

    _skipTimesRetryCount = 0;

    debugPrint('[AniSkip] 🔍 Fetching skip times for Episode: $episodeNumber');
    debugPrint('[AniSkip] Episode length (s): $resolvedEpisodeLength');
    if (malId != null) {
      debugPrint('[AniSkip] Will try MAL ID: $malId');
    }
    if (anilistId != null) {
      debugPrint('[AniSkip] Will try AniList ID: $anilistId');
    }

    try {
      final skipTimes = await AniSkipService.getSkipTimesMultiStrategy(
        malId: malId,
        anilistId: anilistId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: resolvedEpisodeLength,
      );

      if (mounted && _isActiveEpisode(requestKey)) {
        _skipButtonAutoHideTimer?.cancel();
        setState(() {
          _skipTimes = skipTimes;
          _skipButtonActiveSegment = null;
          _skipButtonDismissed = false;
          _lastAutoHideTime = null;
          _showSkipButton = false;
          _skipButtonLabel = '';
        });

        if (_isActiveEpisode(requestKey)) {
          if (skipTimes.hasSkipTimes) {
            debugPrint('[AniSkip] ✅ Skip times loaded successfully!');
            if (skipTimes.op != null) {
              final opShowStart = (skipTimes.op!.start - _skipLeadSeconds)
                  .clamp(0, double.infinity);
              final opShowEnd = skipTimes.op!.end + _skipHoldSeconds;
              debugPrint(
                '[AniSkip] 📺 Opening: ${skipTimes.op!.start.toStringAsFixed(1)}s - ${skipTimes.op!.end.toStringAsFixed(1)}s',
              );
              debugPrint(
                '[AniSkip] 📺 Button will show: ${opShowStart.toStringAsFixed(1)}s - ${opShowEnd.toStringAsFixed(1)}s (${(opShowEnd - opShowStart).toStringAsFixed(1)}s window)',
              );
            }
            if (skipTimes.ed != null) {
              final edShowStart = (skipTimes.ed!.start - _skipLeadSeconds)
                  .clamp(0, double.infinity);
              final edShowEnd = skipTimes.ed!.end + _skipHoldSeconds;
              debugPrint(
                '[AniSkip] 🎬 Ending: ${skipTimes.ed!.start.toStringAsFixed(1)}s - ${skipTimes.ed!.end.toStringAsFixed(1)}s',
              );
              debugPrint(
                '[AniSkip] 🎬 Button will show: ${edShowStart.toStringAsFixed(1)}s - ${edShowEnd.toStringAsFixed(1)}s (${(edShowEnd - edShowStart).toStringAsFixed(1)}s window)',
              );
            }
            // Always start timer when we have skip times
            _startPositionTimer();

            // Immediately check if we should show the button
            if (_player != null) {
              final currentPos = _player?.state.position;
              if (currentPos != null) {
                debugPrint(
                  '[AniSkip] 🔍 Initial position check at ${currentPos.inSeconds}s',
                );
              }
              _checkSkipButtonVisibility();
            }
          } else {
            debugPrint('[AniSkip] ℹ️  No skip times found for this episode');
            // Still start timer in case skip times are added later
            _startPositionTimer();
          }
        }
      }
    } catch (e) {
      debugPrint('[AniSkip] ❌ Error loading skip times: $e');
    }
  }

  /// Start timer to check video position and show skip button
  void _startPositionTimer() {
    _positionTimer?.cancel();
    final timerKey = _activeEpisodeKey;
    debugPrint('[AniSkip] ▶️  Starting position timer for episode: $timerKey');

    int tickCount = 0;
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      tickCount++;

      if (!_isActiveEpisode(timerKey)) {
        debugPrint(
          '[AniSkip] ⏹️  Timer cancelled: episode changed (after $tickCount ticks)',
        );
        timer.cancel();
        return;
      }

      final player = _player;
      if (player == null) {
        if (tickCount % 10 == 0) {
          debugPrint('[AniSkip] ⚠️  Player is null (tick $tickCount)');
        }
        return;
      }

      final value = player.state;
      if (value.duration == Duration.zero) {
        if (tickCount % 10 == 0) {
          debugPrint('[AniSkip] ⚠️  Player not ready (tick $tickCount)');
        }
        return;
      }

      if (_skipTimes == null || _skipTimes?.hasSkipTimes != true) {
        if (tickCount % 20 == 0) {
          debugPrint('[AniSkip] ⚠️  No skip times available (tick $tickCount)');
        }
        return;
      }

      // Log every 10 seconds to confirm timer is running
      if (tickCount % 20 == 0) {
        final pos = player.state.position.inSeconds;
        debugPrint(
          '[AniSkip] ⏱️  Timer active (tick $tickCount, position: ${pos}s)',
        );
      }

      _checkSkipButtonVisibility();
    });
  }

  /// Check if skip button should be visible based on current position
  void _checkSkipButtonVisibility() {
    final player = _player;
    if (player == null || player.state.duration == Duration.zero) {
      return;
    }

    final position = player.state.position;

    // Don't show button when video is paused (prevents infinite loop in landscape)
    if (!player.state.playing) {
      if (_showSkipButton) {
        setState(() {
          _showSkipButton = false;
          _skipButtonLabel = '';
        });
      }
      return;
    }

    final currentSeconds = position.inMilliseconds / 1000.0;

    // Determine which segment (if any) we're currently in
    String? activeSegment;
    String label = '';

    final inOpWindow =
        _skipTimes?.op != null &&
        _isWithinSkipWindow(_skipTimes?.op, currentSeconds);
    final inEdWindow =
        _skipTimes?.ed != null &&
        _isWithinSkipWindow(_skipTimes?.ed, currentSeconds);

    // Debug: Log window checks periodically
    if (currentSeconds.toInt() % 10 == 0 && currentSeconds.toInt() > 0) {
      debugPrint(
        '[AniSkip] 🔍 Position: ${currentSeconds.toStringAsFixed(1)}s | Op window: $inOpWindow | Ed window: $inEdWindow | Dismissed: $_skipButtonDismissed | Showing: $_showSkipButton',
      );
    }

    if (inOpWindow) {
      activeSegment = 'op';
      label = AppLocalizations.of(context).skipIntro;
    } else if (inEdWindow) {
      activeSegment = 'ed';
      label = AppLocalizations.of(context).skipOutro;
    }

    // Reset dismissal when we exit ALL skip windows
    if (_skipButtonDismissed && !inOpWindow && !inEdWindow) {
      debugPrint(
        '[AniSkip] 🔄 Resetting dismissal flag (exited all skip windows at ${currentSeconds.toStringAsFixed(1)}s)',
      );
      _skipButtonDismissed = false;
      _skipButtonActiveSegment = null;
    }

    // When entering a new segment, reset the dismissal and timer
    if (_skipButtonActiveSegment != activeSegment) {
      _skipButtonAutoHideTimer?.cancel();
      final previousSegment = _skipButtonActiveSegment;
      _skipButtonActiveSegment = activeSegment;

      if (activeSegment != null) {
        debugPrint(
          '[AniSkip] 🎯 Segment transition: $previousSegment → $activeSegment at ${currentSeconds.toStringAsFixed(1)}s (dismissed: $_skipButtonDismissed)',
        );
        // Reset dismissal and auto-hide time when entering a new segment
        _skipButtonDismissed = false;
        _lastAutoHideTime = null;
      }
    }

    // Handle visibility based on current state
    if (activeSegment == null) {
      // Not in any skip window
      if (_showSkipButton || _skipButtonLabel.isNotEmpty) {
        setState(() {
          _showSkipButton = false;
          _skipButtonLabel = '';
        });
      }
      return;
    }

    // In a skip window
    if (_skipButtonDismissed) {
      // Button was manually dismissed or skipped for this segment
      if (_showSkipButton) {
        debugPrint(
          '[AniSkip] 🙈 Hiding button (dismissed) at ${currentSeconds.toStringAsFixed(1)}s',
        );
        setState(() {
          _showSkipButton = false;
          _skipButtonLabel = '';
        });
      }
      return;
    }

    // Check if we're in cooldown period after auto-hide (30 seconds)
    if (_lastAutoHideTime != null) {
      final timeSinceAutoHide = DateTime.now().difference(_lastAutoHideTime!);
      if (timeSinceAutoHide.inSeconds < 30) {
        // Still in cooldown, don't show button yet
        if (_showSkipButton) {
          setState(() {
            _showSkipButton = false;
            _skipButtonLabel = '';
          });
        }
        return;
      } else {
        // Cooldown expired, clear the timestamp
        _lastAutoHideTime = null;
      }
    }

    // Show the button
    if (!_showSkipButton || label != _skipButtonLabel) {
      debugPrint(
        '[AniSkip] ✨ Showing skip button: $label at ${currentSeconds.toStringAsFixed(1)}s (segment: $activeSegment, dismissed: $_skipButtonDismissed)',
      );
      setState(() {
        _showSkipButton = true;
        _skipButtonLabel = label;
      });
      _scheduleSkipButtonAutoHide(activeSegment);
    }
  }

  /// Skip to the end of the current intro/outro
  void _skipIntroOutro() {
    final position = _player?.state.position;
    if (position == null) {
      debugPrint('[AniSkip] ❌ Cannot skip: video position unavailable');
      return;
    }

    if (_skipTimes == null) {
      debugPrint('[AniSkip] ❌ Cannot skip: no skip times loaded');
      return;
    }

    final currentSeconds = position.inMilliseconds / 1000.0;
    Duration? skipToPosition;
    String skipType = '';

    // If in opening, skip to end of opening
    if (_isWithinSkipWindow(_skipTimes!.op, currentSeconds)) {
      final targetSeconds = _skipTimes!.op!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'intro';
      debugPrint(
        '[AniSkip] ⏭️  Skipping intro: ${currentSeconds.toStringAsFixed(1)}s -> ${targetSeconds.toStringAsFixed(1)}s',
      );
    }
    // If in ending, skip to end of ending
    else if (_isWithinSkipWindow(_skipTimes!.ed, currentSeconds)) {
      final targetSeconds = _skipTimes!.ed!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'outro';
      debugPrint(
        '[AniSkip] ⏭️  Skipping outro: ${currentSeconds.toStringAsFixed(1)}s -> ${targetSeconds.toStringAsFixed(1)}s',
      );
    } else {
      debugPrint(
        '[AniSkip] ⚠️  Not in skip range (current: ${currentSeconds.toStringAsFixed(1)}s)',
      );
      return;
    }

    // Perform the skip
    _player?.seek(skipToPosition);

    // Hide button after skip
    _skipButtonAutoHideTimer?.cancel();
    _skipButtonDismissed = true;
    setState(() {
      _showSkipButton = false;
    });

    debugPrint('[AniSkip] ✅ Successfully skipped $skipType!');

    // Show a brief feedback to user
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

  bool _isWithinSkipWindow(Skip? skip, double currentSeconds) {
    if (skip == null) return false;
    final startBoundary = (skip.start - _skipLeadSeconds).clamp(
      0,
      double.infinity,
    );
    final endBoundary = skip.end + _skipHoldSeconds;
    final isInWindow =
        currentSeconds >= startBoundary && currentSeconds <= endBoundary;

    // Debug: Log when entering window
    if (isInWindow &&
        currentSeconds >= startBoundary &&
        currentSeconds < startBoundary + 1) {
      debugPrint(
        '[AniSkip] 🚪 Entering skip window: ${currentSeconds.toStringAsFixed(1)}s (boundary: ${startBoundary.toStringAsFixed(1)}s - ${endBoundary.toStringAsFixed(1)}s)',
      );
    }

    return isInWindow;
  }

  void _scheduleSkipButtonAutoHide(String segmentKey) {
    _skipButtonAutoHideTimer?.cancel();
    final episodeKey = _activeEpisodeKey;
    debugPrint(
      '[AniSkip] ⏲️  Scheduled auto-hide for segment: $segmentKey in ${_skipAutoHideDuration.inSeconds}s',
    );
    _skipButtonAutoHideTimer = Timer(_skipAutoHideDuration, () {
      if (!_isActiveEpisode(episodeKey) ||
          _skipButtonActiveSegment != segmentKey ||
          !mounted) {
        debugPrint(
          '[AniSkip] ⏲️  Auto-hide cancelled (episode/segment changed)',
        );
        return;
      }
      debugPrint(
        '[AniSkip] ⏲️  Auto-hiding button for segment: $segmentKey (will reappear after 30s cooldown)',
      );
      _lastAutoHideTime = DateTime.now();
      setState(() {
        _showSkipButton = false;
        _skipButtonLabel = '';
      });
      // Don't set _skipButtonDismissed = true here!
      // Button can reappear after cooldown period
    });
  }

  Future<void> _initializeVideoPlayer() async {
    if (!mounted) return;

    final episodeKey = _buildEpisodeKey(widget);
    debugPrint('[VideoPlayer] 🎬 Initializing player for episode: $episodeKey');

    _activeEpisodeKey = episodeKey;
    _positionTimer?.cancel();
    _skipButtonAutoHideTimer?.cancel();
    _skipButtonActiveSegment = null;
    _skipButtonDismissed = false;
    _skipTimesRetryCount = 0;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showWebViewOption = false;
      _bloggerVideoUrl = null;
      _skipTimes = null;
      _showSkipButton = false;
      _skipButtonLabel = '';
    });

    try {
      await _cleanupControllers();
      if (!_isActiveEpisode(episodeKey)) {
        debugPrint('[VideoPlayer] Initialization aborted (episode changed).');
        return;
      }

      String videoSrc;

      if (widget.anime?.source == AnimeSource.allAnime) {
        debugPrint('[VideoPlayer] Getting AllAnime episode URL');

        final animeId = widget.anime!.allAnimeId ?? widget.anime!.url;
        final episodeNo = widget.episode.url;

        final allAnimeUrl = await AllAnimeService.getEpisodeURL(
          animeId,
          episodeNo,
        );

        if (!_isActiveEpisode(episodeKey)) {
          debugPrint('[VideoPlayer] AllAnime fetch ignored (episode changed).');
          return;
        }

        if (allAnimeUrl == null || allAnimeUrl.isEmpty) {
          throw Exception('Video URL not found on AllAnime');
        }

        videoSrc = allAnimeUrl;
        debugPrint('[VideoPlayer] AllAnime video URL: $videoSrc');
      } else {
        debugPrint('[VideoPlayer] Getting AnimeFire episode URL');
        videoSrc = await AnimeService.extractVideoURL(widget.episode.url);

        if (!_isActiveEpisode(episodeKey)) {
          debugPrint(
            '[VideoPlayer] AnimeFire fetch ignored (episode changed).',
          );
          return;
        }

        if (videoSrc.isEmpty) {
          throw Exception('Video URL not found on page');
        }
      }

      _bloggerVideoUrl = videoSrc;

      String resolvedVideoUrl;
      Map<String, String> controllerHeaders;

      if (widget.anime?.source == AnimeSource.allAnime) {
        debugPrint('[VideoPlayer] Using AllAnime URL directly for streaming');
        resolvedVideoUrl = videoSrc;
        controllerHeaders = {
          HttpHeaders.userAgentHeader:
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
        };
        _isGoogleStream = false;
      } else {
        final actualVideo = await AnimeService.extractActualVideoURL(videoSrc);
        if (actualVideo.url.isEmpty) {
          throw Exception('Video URL could not be extracted from API');
        }

        if (!_isActiveEpisode(episodeKey)) {
          debugPrint(
            '[VideoPlayer] Actual video extraction ignored (episode changed).',
          );
          return;
        }

        resolvedVideoUrl = actualVideo.url;
        final playbackHeaders = <String, String>{
          HttpHeaders.userAgentHeader:
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
          HttpHeaders.refererHeader: 'https://animefire.plus/',
        };

        if (actualVideo.hasHeaders) {
          playbackHeaders.addAll(actualVideo.headers);
        }

        final forwardedHeaders = Map<String, String>.from(playbackHeaders);
        controllerHeaders = Map<String, String>.from(playbackHeaders);
        _isGoogleStream = actualVideo.isGoogleVideo;

        if (actualVideo.isGoogleVideo) {
          _googleVideoProxy = GoogleVideoProxy(
            targetUri: Uri.parse(actualVideo.url),
            forwardHeaders: forwardedHeaders,
          );
          final proxyUri = await _googleVideoProxy!.start();

          if (!_isActiveEpisode(episodeKey)) {
            debugPrint('[VideoPlayer] Proxy start ignored (episode changed).');
            return;
          }

          resolvedVideoUrl = proxyUri.toString();
          controllerHeaders = {};
          debugPrint('Using local proxy for Google Video: $resolvedVideoUrl');
          debugPrint('Forwarding remote headers: $forwardedHeaders');
        }
      }

      _currentVideoUrl = resolvedVideoUrl;
      _currentVideoHeaders = controllerHeaders;
      debugPrint('Using playback headers: $_currentVideoHeaders');

      _player = Player(
        configuration: const PlayerConfiguration(
          protocolWhitelist: [
            'file',
            'tcp',
            'tls',
            'http',
            'https',
            'crypto',
            'data',
          ],
        ),
      );
      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      // Listen to player streams for error handling
      _player?.stream.error.listen((error) {
        debugPrint('[VideoPlayer] Error stream received: $error');
        if (error.toString().isNotEmpty && mounted) {
          setState(() {
            _errorMessage = 'Player error: $error';
            _isLoading = false;
          });
        }
      });

      // Log playback state changes for debugging
      _player?.stream.playing.listen((playing) {
        debugPrint('[VideoPlayer] Playing state: $playing');
      });

      _player?.stream.completed.listen((completed) {
        debugPrint('[VideoPlayer] Completed: $completed');
      });

      // Open the media with headers
      debugPrint('[VideoPlayer] Opening media URL: $resolvedVideoUrl');

      // Extract referer from URL for CDN compatibility
      final uri = Uri.parse(resolvedVideoUrl);
      final referer = '${uri.scheme}://${uri.host}/';

      // Merge default headers with controller headers for better compatibility
      final defaultHeaders = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.0',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'identity;q=1, *;q=0',
        'Connection': 'keep-alive',
        'Referer': referer,
        'Sec-Fetch-Dest': 'video',
        'Sec-Fetch-Mode': 'no-cors',
        'Sec-Fetch-Site': 'cross-site',
      };

      // Merge: controller headers take priority over defaults
      final mergedHeaders = {...defaultHeaders, ...controllerHeaders};
      debugPrint('[VideoPlayer] Headers: $mergedHeaders');

      try {
        final media = Media(resolvedVideoUrl, httpHeaders: mergedHeaders);
        await _player!.open(media, play: true);
        debugPrint('[VideoPlayer] Media opened successfully');
      } catch (e) {
        debugPrint('[VideoPlayer] Failed with headers, trying without...');
        // Fallback: try without headers
        final media = Media(resolvedVideoUrl);
        await _player!.open(media, play: true);
        debugPrint(
          '[VideoPlayer] Media opened successfully (no headers fallback)',
        );
      }

      // Wait for player to be ready
      await _player?.stream.playing
          .firstWhere((playing) => playing == true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[VideoPlayer] Timeout waiting for playback to start');
              return false;
            },
          );

      if (!_isActiveEpisode(episodeKey)) {
        debugPrint('[VideoPlayer] Controller init ignored (episode changed).');
        return;
      }

      if (!mounted) return;

      if (mounted) {
        if (!_isActiveEpisode(episodeKey)) {
          debugPrint(
            '[VideoPlayer] Skipped final state update (episode changed).',
          );
          return;
        }
        setState(() {
          _isLoading = false;
        });
      }

      final videoDurationSeconds = _player?.state.duration.inSeconds ?? 0;
      debugPrint('[VideoPlayer] Duration (s): $videoDurationSeconds');
      await _loadSkipTimes(episodeLengthSeconds: videoDurationSeconds);
    } catch (e) {
      debugPrint('Error initializing video: $e');
      await _googleVideoProxy?.stop();
      _googleVideoProxy = null;
      _isGoogleStream = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void _openWebViewFallback() {
    final fallbackUrl = _bloggerVideoUrl ?? _currentVideoUrl;
    if (fallbackUrl == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BloggerWebViewScreen(
          initialUrl: fallbackUrl,
          title: '${widget.animeTitle} - Ep ${widget.episode.number}',
        ),
      ),
    );
  }

  double _calculateAspectRatio() {
    if (_player != null) {
      final width = _player?.state.width;
      final height = _player?.state.height;
      if (width != null && height != null && width > 0 && height > 0) {
        return width / height;
      }
    }
    return 16 / 9;
  }

  Future<void> _cleanupControllers() async {
    _positionTimer?.cancel();
    _skipButtonAutoHideTimer?.cancel();
    await _player?.dispose();
    _player = null;
    _videoController = null;
    _currentVideoHeaders = null;
    _currentVideoUrl = null;
    _isGoogleStream = false;

    if (_googleVideoProxy != null) {
      await _googleVideoProxy!.stop();
      _googleVideoProxy = null;
    }
  }

  void _copyStreamLink() {
    if (_currentVideoUrl == null) return;
    Clipboard.setData(ClipboardData(text: _currentVideoUrl!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).linkCopied),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.2),
                  Colors.red.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).playerError,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          if (_showWebViewOption && _bloggerVideoUrl != null) ...[
            ElevatedButton.icon(
              onPressed: _openWebViewFallback,
              icon: const Icon(Icons.open_in_browser),
              label: Text(AppLocalizations.of(context).alternativePlayer),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: _initializeVideoPlayer,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _cleanupControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar moderno
          SliverAppBar(
            expandedHeight: 80,
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.animeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Episode ${_extractEpisodeNumber(widget.episode.number)}',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _buildLoadedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: MediaQuery.of(context).size.height - 200,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.getPrimaryGradient(),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryShadow,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).loadingStream,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).preparingServer,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: MediaQuery.of(context).size.height - 200,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: _buildErrorWidget(
          _errorMessage ?? AppLocalizations.of(context).error,
        ),
      ),
    );
  }

  Widget _buildLoadedContent() {
    // Detectar se é TV
    return FutureBuilder<bool>(
      future: TVDetector.isTV,
      builder: (context, snapshot) {
        final isTV = snapshot.data ?? false;

        if (isTV) {
          // Layout fullscreen para TV
          return Stack(
            children: [
              // Video Player fullscreen
              SizedBox.expand(
                child: _videoController != null
                    ? Video(
                        controller: _videoController!,
                        fit: BoxFit.cover,
                        controls: null,
                      )
                    : Container(color: Colors.black),
              ),
              // Skip Button Overlay
              Positioned(
                bottom: 40,
                right: 40,
                child: IgnorePointer(
                  ignoring: !_showSkipButton,
                  child: SkipButton(
                    onSkip: _skipIntroOutro,
                    label: _skipButtonLabel,
                    show: _showSkipButton,
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            // Video Player with Skip Button
            Container(
              margin: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  // Video Player Container
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: _calculateAspectRatio(),
                        child: _videoController != null
                            ? Video(
                                controller: _videoController!,
                                fit: BoxFit.contain,
                                controls:
                                    null, // Usa controles nativos do media_kit
                              )
                            : Container(color: Colors.black),
                      ),
                    ),
                  ),
                  // Skip Button Overlay (outside ClipRRect)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_showSkipButton,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24, right: 16),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: SkipButton(
                              onSkip: _skipIntroOutro,
                              label: _skipButtonLabel,
                              show: _showSkipButton,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface.withValues(alpha: 0.8),
                    AppColors.surfaceLight.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.animeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Episode ${_extractEpisodeNumber(widget.episode.number)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quality Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(
                        AppLocalizations.of(context).dynamicQuality,
                        const Color(0xFF9C27B0),
                        Icons.high_quality_rounded,
                      ),
                      _buildTag(
                        AppLocalizations.of(context).optimizedPlayer,
                        const Color(0xFF2196F3),
                        Icons.offline_bolt_rounded,
                      ),
                      if (_isGoogleStream)
                        _buildTag(
                          AppLocalizations.of(context).googleVideo,
                          const Color(0xFF4CAF50),
                          Icons.cloud_done_rounded,
                        ),
                    ],
                  ),

                  // Server Info
                  if (_currentVideoUrl != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.getPrimaryGradient(),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.sensors,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).serverInUse,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Uri.parse(_currentVideoUrl!).host,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _copyStreamLink,
                            icon: const Icon(Icons.copy, color: AppColors.primary),
                            tooltip: AppLocalizations.of(context).copyLink,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Buttons
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _initializeVideoPlayer,
                          icon: const Icon(Icons.refresh),
                          label: Text(AppLocalizations.of(context).syncStream),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentVideoUrl == null
                              ? null
                              : _copyStreamLink,
                          icon: const Icon(Icons.link),
                          label: Text(AppLocalizations.of(context).copyLink),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_showWebViewOption && _bloggerVideoUrl != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openWebViewFallback,
                        icon: const Icon(Icons.open_in_browser),
                        label: Text(AppLocalizations.of(context).alternativePlayer),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
          },
    );
  }

  Widget _buildTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
