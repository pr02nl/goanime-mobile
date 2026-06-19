import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/services/anime_service.dart';
import '../domain/models/anime.dart';
import '../domain/models/episode.dart';
import '../google_video_proxy.dart';
import '../l10n/app_localizations.dart';
import '../mixins/video_player_aniskip_mixin.dart';
import '../ui/core/themes/app_colors.dart';
import '../utils/episode_utils.dart';
import '../utils/tv_detector.dart';
import '../widgets/focusable_widget.dart';
import '../widgets/skip_button.dart';
import 'blogger_webview_screen.dart';

class ModernVideoPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;
  final bool isMovie;
  final List<Episode>? episodeList;
  final int? episodeIndex;

  const ModernVideoPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
    this.anime,
    this.isMovie = false,
    this.episodeList,
    this.episodeIndex,
  });

  @override
  State<ModernVideoPlayerScreen> createState() =>
      _ModernVideoPlayerScreenState();
}

class _ModernVideoPlayerScreenState extends State<ModernVideoPlayerScreen>
    with VideoPlayerAniSkipMixin {
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

  // Fullscreen related variables
  bool _isFullscreen = false;
  bool? _isTVDevice;

  // Overlay controls auto-hide
  bool _showOverlayControls = true;
  Timer? _overlayControlsTimer;
  static const Duration _overlayControlsAutoHideDuration = Duration(seconds: 3);

  // Stream subscriptions — guardadas para cancelar em _cleanupControls e
  // evitar listeneres órfãos que disparam setState após troca de episódio.
  StreamSubscription? _errorSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;
  StreamSubscription<Tracks>? _tracksSub;

  // Handler global de hardware keyboard. Usamos HardwareKeyboard em vez de
  // Focus/CallbackShortcuts para interceptar teclas SEM competir pelo foco
  // de teclado da árvore (Focus). Isso é crítico porque o Focus interno do
  // MaterialDesktopVideoControls precisa estar focado para os atalhos
  // space/setas/J/K/F funcionarem via CallbackShortcuts nativo do package.
  bool _hardwareKeyboardHandlerInstalled = false;

  /// Tracks de legenda embutidas no MKV (lidas via `Player.state.tracks.subtitle`
  /// assim que o `Media.open` finaliza).
  List<SubtitleTrack> _embeddedSubtitleTracks = const [];

  int? _currentEpisodeIndex;
  late Episode _currentEpisode;

  bool get _hasNextEpisode {
    if (widget.episodeList == null || _currentEpisodeIndex == null) {
      return false;
    }
    return _currentEpisodeIndex! < widget.episodeList!.length - 1;
  }

  bool get _hasPreviousEpisode {
    if (widget.episodeList == null || _currentEpisodeIndex == null) {
      return false;
    }
    return _currentEpisodeIndex! > 0;
  }

  /// Label de exibição do conteúdo atual.
  /// Para filmes: retorna o título do filme.
  /// Para animes com episode.title: retorna o título do episódio.
  /// Caso contrário: retorna "Episode N".
  String get _displayLabel {
    if (widget.isMovie) return widget.animeTitle;
    final epNum = extractEpisodeNumber(_currentEpisode.number);
    if (_currentEpisode.title != null && _currentEpisode.title!.isNotEmpty) {
      return '${AppLocalizations.of(context).episode(epNum)} - ${_currentEpisode.title}';
    }
    return AppLocalizations.of(context).episode(epNum);
  }

  // --- VideoPlayerAniSkipMixin abstract member implementations ---

  @override
  bool isActiveEpisode(String? key) {
    if (key == null) return false;
    return mounted && activeEpisodeKey == key;
  }

  @override
  Player? get player => _player;

  @override
  BuildContext get localizationContext => context;

  // --- End mixin implementations ---

  String _buildEpisodeKey(ModernVideoPlayerScreen target) {
    final anime = target.anime;
    return buildEpisodeKey(
      animeTitle: target.animeTitle,
      episodeNumber: _currentEpisode.number.toString(),
      episodeUrl: _currentEpisode.url,
      animeAnilistId: anime?.anilistId?.toString(),
      animeMalId: anime?.malId?.toString(),
      animeUrl: anime?.url,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentEpisodeIndex = widget.episodeIndex;
    _currentEpisode = widget.episode;
    // Entra em fullscreen imediatamente (síncrono) antes de qualquer await
    _enterFullscreen();
    _initializeVideoPlayer();
    _detectDeviceAndEnterFullscreen();
    _installHardwareKeyboardHandler();
  }

  /// Handler global de teclado. Usamos HardwareKeyboard em vez de Focus/
  /// CallbackShortcuts porque ele intercepta o evento ANTES da árvore de
  /// Focus, sem competir pelo foco do MaterialDesktopVideoControls.
  ///
  /// Função: capturar Esc (sai do fullscreen limpando nosso estado) e
  /// ressuscitar o overlay em qualquer outra tecla.
  ///
  /// NÃO interceptamos Space/setas/J/K/F aqui — eles devem ser
  /// processados pelo MaterialDesktopVideoControls (CallbackShortcuts
  /// nativo do package), que precisa estar com foco.
  void _installHardwareKeyboardHandler() {
    if (_hardwareKeyboardHandlerInstalled) return;
    _hardwareKeyboardHandlerInstalled = true;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Esc: sai do fullscreen limpando estado local. O
    // MaterialDesktopVideoControls já trata Esc internamente (chama
    // exitFullscreen do package), mas NÃO atualiza nosso `_isFullscreen`
    // nem limpa SystemUiMode no desktop. Fazemos aqui.
    if (event.logicalKey == LogicalKeyboardKey.escape && _isFullscreen) {
      _exitFullscreen();
      return true; // consome o evento
    }

    // Qualquer outra tecla: re-mostra overlay.
    _showOverlayControlsAndResetTimer();
    return false; // deixa propagar (espaco/setas/J/K/F vão para controls)
  }

  void _uninstallHardwareKeyboardHandler() {
    if (!_hardwareKeyboardHandlerInstalled) return;
    _hardwareKeyboardHandlerInstalled = false;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
  }

  /// Detecta o tipo de dispositivo e configura comportamentos específicos (TV, etc.)
  void _detectDeviceAndEnterFullscreen() async {
    if (!mounted) return;

    if (!Platform.isAndroid) {
      _setupFullscreenListener();
      return;
    }

    // Detectar se é TV
    final isTV = await TVDetector.isTV;
    if (!mounted) return;
    _isTVDevice = isTV;

    if (isTV) {
      // TV: fullscreen + landscape only
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    // Garantir fullscreen (pode ter sido perdido durante o await)
    _enterFullscreen();

    // Configurar listener para detectar saída do fullscreen
    _setupFullscreenListener();
  }

  /// Entra em modo fullscreen (immersive)
  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startOverlayControlsHideTimer();
  }

  /// Sai do modo fullscreen
  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Configura listener para detectar mudanças no sistema UI (fullscreen exit)
  void _setupFullscreenListener() {
    SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
      // systemOverlaysAreVisible = true quando saiu do fullscreen
      if (systemOverlaysAreVisible && _isFullscreen) {
        setState(() {
          _isFullscreen = false;
        });

        if (_isTVDevice == true) {
          // Na TV: fechar o player quando sair do fullscreen
          debugPrint('[VideoPlayer] TV: Fechando player ao sair do fullscreen');
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
        // No smartphone: apenas sai do fullscreen sem fechar (comportamento padrão)
      }
    });
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
      cleanupAniSkip();
      skipButtonActiveSegment = null;
      skipButtonDismissed = false;
      lastAutoHideTime = null;
      skipTimes = null;
      showSkipButton = false;
      skipButtonLabel = '';

      _initializeVideoPlayer();
    }
  }

  void _goToNextEpisode() {
    if (!_hasNextEpisode) return;
    final nextIndex = _currentEpisodeIndex! + 1;
    final nextEpisode = widget.episodeList![nextIndex];
    debugPrint('[VideoPlayer] ⏭ Next episode: index $nextIndex');
    _currentEpisodeIndex = nextIndex;
    _replaceEpisode(nextEpisode);
  }

  void _goToPreviousEpisode() {
    if (!_hasPreviousEpisode) return;
    final prevIndex = _currentEpisodeIndex! - 1;
    final prevEpisode = widget.episodeList![prevIndex];
    debugPrint('[VideoPlayer] ⏮ Previous episode: index $prevIndex');
    _currentEpisodeIndex = prevIndex;
    _replaceEpisode(prevEpisode);
  }

  /// Troca o episódio atual no widget e dispara reinitialização.
  void _replaceEpisode(Episode newEpisode) {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentEpisode = newEpisode;
    });
    cleanupAniSkip();
    skipButtonActiveSegment = null;
    skipButtonDismissed = false;
    lastAutoHideTime = null;
    skipTimes = null;
    showSkipButton = false;
    skipButtonLabel = '';
    _initializeVideoPlayer();
  }

  /// Espera o `Player.stream.tracks` emitir um snapshot com pelo menos
  /// uma faixa de legenda (embutida) ou atingir o timeout. Substitui o
  /// `Future.delayed(500ms)` mágico, que falhava em streams lentos.
  ///
  /// Se o vídeo não tiver legendas embutidas, o snapshot chegará com
  /// `subtitle` vazio — o método retorna OK nesse caso após o timeout.
  Future<void> _waitForEmbeddedSubtitleTracks(String episodeKey) async {
    final player = _player;
    if (player == null) return;

    // Captura a subscription para cancelar em troca de episódio.
    _tracksSub?.cancel();
    final completer = Completer<void>();

    Timer? timeoutTimer;
    StreamSubscription<Tracks>? sub;

    void finish() {
      timeoutTimer?.cancel();
      sub?.cancel();
      if (!completer.isCompleted) completer.complete();
    }

    timeoutTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('[VideoPlayer] Tracks stream timeout (5s)');
      finish();
    });

    try {
      sub = player.stream.tracks.listen((t) {
        debugPrint(
          '[VideoPlayer] Embedded subtitle tracks: ${t.subtitle.length}',
        );
        for (final st in t.subtitle) {
          debugPrint(
            '[VideoPlayer]   embed: id=${st.id}, '
            'title=${st.title}, lang=${st.language}',
          );
        }
        if (mounted) {
          setState(() {
            _embeddedSubtitleTracks = t.subtitle;
          });
        }
        // Aceita o PRIMEIRO snapshot com tracks populadas OU vazias —
        // significa que o media_kit terminou o parse.
        if (!completer.isCompleted) finish();
      });
      _tracksSub = sub;
      await completer.future;
    } catch (e) {
      debugPrint('[VideoPlayer] Error waiting for embedded tracks: $e');
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (!mounted) return;

    final episodeKey = _buildEpisodeKey(widget);
    debugPrint('[VideoPlayer] 🎬 Initializing player for episode: $episodeKey');

    activeEpisodeKey = episodeKey;
    positionTimer?.cancel();
    skipButtonAutoHideTimer?.cancel();
    skipButtonActiveSegment = null;
    skipButtonDismissed = false;
    skipTimesRetryCount = 0;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showWebViewOption = false;
      _bloggerVideoUrl = null;
      skipTimes = null;
      showSkipButton = false;
      skipButtonLabel = '';
    });

    try {
      await _cleanupControllers();
      if (!isActiveEpisode(episodeKey)) {
        debugPrint('[VideoPlayer] Initialization aborted (episode changed).');
        return;
      }

      String resolvedVideoUrl;
      Map<String, String> controllerHeaders = {};

      // Verificar se é PauloFlix (URL direta do arquivo MKV)
      if (widget.anime?.source == AnimeSource.pauloFlix) {
        debugPrint('[VideoPlayer] PauloFlix: Using direct URL');
        resolvedVideoUrl = _currentEpisode.url;
      } else {
        // AnimeFire: extrair URL do vídeo
        debugPrint('[VideoPlayer] Getting AnimeFire episode URL');
        final videoSrc = await AnimeService.extractVideoURL(
          _currentEpisode.url,
        );

        if (!isActiveEpisode(episodeKey)) {
          debugPrint(
            '[VideoPlayer] AnimeFire fetch ignored (episode changed).',
          );
          return;
        }

        if (videoSrc.isEmpty) {
          throw Exception('Video URL not found on page');
        }

        _bloggerVideoUrl = videoSrc;

        final actualVideo = await AnimeService.extractActualVideoURL(videoSrc);
        if (actualVideo.url.isEmpty) {
          throw Exception('Video URL could not be extracted from API');
        }

        if (!isActiveEpisode(episodeKey)) {
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

          if (!isActiveEpisode(episodeKey)) {
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

      // Resolve TV detection before creating VideoController
      // to apply correct hardware acceleration setting.
      // IMPORTANTE: Nao desabilitar HW accel na TV — causa tela preta.
      if (_isTVDevice == null && Platform.isAndroid) {
        _isTVDevice = await TVDetector.isTV;
      }
      final isTV = _isTVDevice == true;

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
          androidAttachSurfaceAfterVideoParameters: true,
        ),
      );
      debugPrint('[VideoPlayer] HW acceleration: true (isTV: $isTV)');

      // Força rebuild para inserir o Video widget na árvore AGORA,
      // permitindo que AndroidVideoController crie a Surface Android
      // antes de player.open() ser chamado.
      if (mounted) setState(() {});

      // Aguarda a Surface Android estar pronta antes de abrir a mídia
      await _player!.platform?.waitForVideoControllerInitializationIfAttached
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => debugPrint('[VideoPlayer] Surface init timeout'),
          );

      // Listen to player streams for error handling.
      // IMPORTANTE: cancelar subscription anterior ANTES de reassinar —
      // caso contrário, troca rápida de episódio acumula listeners
      // zumbis que disparam setState em widgets desmontados.
      _errorSub?.cancel();
      _errorSub = _player?.stream.error.listen((error) {
        debugPrint('[VideoPlayer] Error stream received: $error');
        if (error.toString().isNotEmpty && mounted) {
          setState(() {
            _errorMessage = 'Player error: $error';
            _isLoading = false;
          });
        }
      });

      // Log playback state changes for debugging
      _playingSub?.cancel();
      _playingSub = _player?.stream.playing.listen((playing) {
        debugPrint('[VideoPlayer] Playing state: $playing');
      });

      _completedSub?.cancel();
      _completedSub = _player?.stream.completed.listen((completed) {
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
        await _player!.open(media, play: false);
        debugPrint(
          '[VideoPlayer] Media opened (paused, waiting for video ready)',
        );
      } catch (e) {
        debugPrint('[VideoPlayer] Failed with headers, trying without...');
        // Fallback: try without headers
        final media = Media(resolvedVideoUrl);
        await _player!.open(media, play: false);
        debugPrint('[VideoPlayer] Media opened (no headers fallback, paused)');
      }

      // Espera o media_kit parsear o contêiner e popular as tracks
      // embutidas. O `state.tracks` é populado de forma assíncrona após
      // `Media.open`, então ouvimos o `stream.tracks` em vez de assumir um
      // delay fixo (que falha em streams lentos / contêineres grandes).
      await _waitForEmbeddedSubtitleTracks(episodeKey);
      if (!isActiveEpisode(episodeKey)) {
        debugPrint('[VideoPlayer] Tracks wait ignored (episode changed).');
        return;
      }

      // Carrega legenda (.srt) externa, se fornecida via Episode.subtitleUrl.
      // Equivale a `ffmpeg -i video.mp4 -i legend.srt -c copy out.mkv`, mas
      // sem precisar re-encodar: o media_kit expõe a legenda como track.
      final externalSubtitles = _currentEpisode.subtitleTracks
          .where((s) => s.url != null)
          .toList();
      if (externalSubtitles.isNotEmpty) {
        // Auto-seleciona a PRIMEIRA legenda externa (PT-BR preferida pelo ranking).
        try {
          final s = externalSubtitles.first;
          final subtitle = SubtitleTrack.uri(
            s.url!,
            title: s.displayName,
            language: s.language,
          );
          await _player!.setSubtitleTrack(subtitle);
          debugPrint('[VideoPlayer] Subtitle loaded: ${s.displayName}');
        } catch (e) {
          debugPrint('[VideoPlayer] Failed to load subtitle: $e');
          // Não derruba a reprodução — vídeo continua sem legenda.
        }
      } else if (_embeddedSubtitleTracks.isNotEmpty) {
        // Sem legenda externa, ativa "Auto" no media_kit para usar o
        // detectado nas embutidas.
        try {
          await _player!.setSubtitleTrack(SubtitleTrack.auto());
          debugPrint('[VideoPlayer] Subtitle auto (from embedded tracks)');
        } catch (e) {
          debugPrint('[VideoPlayer] Failed auto subtitle: $e');
        }
      }

      // Wait for video dimensions to be available before starting playback.
      // This prevents audio playing before the video surface is ready.
      // We listen to the tracks stream which fires when the video track
      // is parsed (contains video dimensions).
      await _player?.stream.tracks
          .firstWhere((tracks) => tracks.video.isNotEmpty)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('[VideoPlayer] Timeout waiting for video tracks');
              return const Tracks();
            },
          );

      if (!isActiveEpisode(episodeKey)) {
        debugPrint('[VideoPlayer] Controller init ignored (episode changed).');
        return;
      }

      // Video is ready — start playback now
      await _player?.play();
      debugPrint('[VideoPlayer] Playback started');

      if (!mounted) return;

      if (mounted) {
        if (!isActiveEpisode(episodeKey)) {
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
      await loadSkipTimes(
        episodeLengthSeconds: videoDurationSeconds,
        malId: widget.anime?.malId,
        anilistId: widget.anime?.anilistId,
        episodeNumber: _currentEpisode.number.toString(),
      );
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
          title: '${widget.animeTitle} - ${_currentEpisode.number}',
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
    positionTimer?.cancel();
    skipButtonAutoHideTimer?.cancel();

    // Cancela stream subscriptions para que listeners não disparem
    // setState em State desmontada após troca rápida de episódio.
    await _errorSub?.cancel();
    await _playingSub?.cancel();
    await _completedSub?.cancel();
    await _tracksSub?.cancel();
    _errorSub = null;
    _playingSub = null;
    _completedSub = null;
    _tracksSub = null;

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
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _initializeVideoPlayer,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
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
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: Text(AppLocalizations.of(context).close),
                style: ElevatedButton.styleFrom(
                  // backgroundColor: Colors.orange,
                  // foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _overlayControlsTimer?.cancel();
    _uninstallHardwareKeyboardHandler();
    SystemChrome.setSystemUIChangeCallback(null);

    // Cleanup síncrono: para o player antes do State ser desmontado
    _player?.stop();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _tracksSub?.cancel();

    // Cleanup assíncrono em background (não pode await no dispose)
    _deferredCleanup();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose(); // Mixin cancela positionTimer, skipButtonAutoHideTimer
  }

  Future<void> _deferredCleanup() async {
    await _player?.dispose();
    _player = null;
    _videoController = null;
    if (_googleVideoProxy != null) {
      await _googleVideoProxy!.stop();
      _googleVideoProxy = null;
    }
  }

  /// Mostra os controles de overlay e reinicia o timer de auto-hide
  void _showOverlayControlsAndResetTimer() {
    if (!mounted) return;
    setState(() {
      _showOverlayControls = true;
    });
    _startOverlayControlsHideTimer();
  }

  /// Inicia o timer que esconde os controles de overlay
  void _startOverlayControlsHideTimer() {
    _overlayControlsTimer?.cancel();
    _overlayControlsTimer = Timer(_overlayControlsAutoHideDuration, () {
      if (mounted) {
        setState(() {
          _showOverlayControls = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        extendBodyBehindAppBar: true,
        // O Video widget DEVE estar sempre na árvore para que o
        // AndroidVideoController crie a Surface antes de player.open().
        // Estados de loading/erro são sobrepostos via Stack.
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Video sempre presente para garantir Surface inicializada
            _buildFullscreenContent(),
            // Loading overlay
            if (_isLoading) _buildLoadingState(),
            // Error overlay
            if (!_isLoading && _errorMessage != null) _buildErrorState(),
          ],
        ),
      );
    }

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
                  _displayLabel,
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

  Widget _buildFullscreenContent() {
    final isTV = _isTVDevice == true;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _showOverlayControlsAndResetTimer,
      child: MouseRegion(
        onHover: (_) => _showOverlayControlsAndResetTimer(),
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _videoController != null
                  ? (isTV
                        ? MaterialDesktopVideoControlsTheme(
                            normal: const MaterialDesktopVideoControlsThemeData(
                              visibleOnMount: true,
                              playAndPauseOnTap: true,
                            ),
                            fullscreen:
                                const MaterialDesktopVideoControlsThemeData(
                                  visibleOnMount: true,
                                  playAndPauseOnTap: true,
                                ),
                            child: Focus(
                              autofocus: true,
                              onKeyEvent: (node, event) {
                                if (event is! KeyDownEvent) {
                                  return KeyEventResult.ignored;
                                }
                                final key = event.logicalKey;
                                if (key == LogicalKeyboardKey.mediaTrackNext ||
                                    key == LogicalKeyboardKey.keyN) {
                                  _goToNextEpisode();
                                  return KeyEventResult.handled;
                                }
                                if (key ==
                                        LogicalKeyboardKey.mediaTrackPrevious ||
                                    key == LogicalKeyboardKey.keyP) {
                                  _goToPreviousEpisode();
                                  return KeyEventResult.handled;
                                }
                                _showOverlayControlsAndResetTimer();
                                return KeyEventResult.ignored;
                              },
                              child: Video(
                                controller: _videoController!,
                                fit: BoxFit.contain,
                                controls: MaterialDesktopVideoControls,
                              ),
                            ),
                          )
                        : Video(
                            controller: _videoController!,
                            fit: BoxFit.contain,
                            controls: AdaptiveVideoControls,
                          ))
                  : Container(color: Colors.black),
              // Botão flutuante voltar + título
              Positioned(
                top: isTV ? 16 : 8,
                left: isTV ? 16 : 8,
                child: AnimatedOpacity(
                  opacity: _showOverlayControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    child: Material(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          FocusableWidget(
                            onSelect: _exitFullscreen,
                            borderRadius: 24,
                            focusPadding: EdgeInsets.zero,
                            focusScale: 1.05,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '  $_displayLabel',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Botões próximo/anterior episódio (canto inferior direito)
              if (!widget.isMovie && widget.episodeList != null)
                Positioned(
                  bottom: isTV ? 40 : 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _showOverlayControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasPreviousEpisode)
                            FocusableWidget(
                              onSelect: _goToPreviousEpisode,
                              borderRadius: 24,
                              focusPadding: EdgeInsets.zero,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.skip_previous_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          if (_hasNextEpisode)
                            FocusableWidget(
                              onSelect: _goToNextEpisode,
                              borderRadius: 24,
                              focusPadding: EdgeInsets.zero,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.skip_next_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Skip Button Overlay
              Positioned(
                bottom: isTV ? 40 : 80,
                right: isTV ? 40 : 24,
                child: SafeArea(
                  child: IgnorePointer(
                    ignoring: !showSkipButton,
                    child: SkipButton(
                      onSkip: skipIntroOutro,
                      label: skipButtonLabel,
                      show: showSkipButton,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final isFullscreen = _isFullscreen;
    final inner = Container(
      height: isFullscreen ? null : MediaQuery.of(context).size.height - 200,
      color: isFullscreen ? Colors.black : null,
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
    return isFullscreen ? SizedBox.expand(child: inner) : inner;
  }

  Widget _buildErrorState() {
    final isFullscreen = _isFullscreen;
    final inner = Container(
      height: isFullscreen ? null : MediaQuery.of(context).size.height - 200,
      color: isFullscreen ? Colors.black : null,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: _buildErrorWidget(
          _errorMessage ?? AppLocalizations.of(context).error,
        ),
      ),
    );
    return isFullscreen ? SizedBox.expand(child: inner) : inner;
  }

  Widget _buildLoadedContent() {
    if (_isTVDevice == true) {
      return _buildTVPlayerLayout();
    }

    return Column(children: [_buildVideoPlayerCard(), _buildInfoPanel()]);
  }

  Widget _buildTVPlayerLayout() {
    return Stack(
      children: [
        SizedBox.expand(
          child: _videoController != null
              ? MaterialDesktopVideoControlsTheme(
                  normal: const MaterialDesktopVideoControlsThemeData(
                    visibleOnMount: true,
                    playAndPauseOnTap: true,
                  ),
                  fullscreen: const MaterialDesktopVideoControlsThemeData(
                    visibleOnMount: true,
                    playAndPauseOnTap: true,
                  ),
                  child: Video(
                    controller: _videoController!,
                    fit: BoxFit.cover,
                    controls: MaterialDesktopVideoControls,
                  ),
                )
              : Container(color: Colors.black),
        ),
        Positioned(
          bottom: 40,
          right: 40,
          child: IgnorePointer(
            ignoring: !showSkipButton,
            child: SkipButton(
              onSkip: skipIntroOutro,
              label: skipButtonLabel,
              show: showSkipButton,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayerCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Stack(
        children: [
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
                    ? Video(controller: _videoController!, fit: BoxFit.contain)
                    : Container(color: Colors.black),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !showSkipButton,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24, right: 16),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: SkipButton(
                      onSkip: skipIntroOutro,
                      label: skipButtonLabel,
                      show: showSkipButton,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
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
          _buildTitleSection(),
          const SizedBox(height: 20),
          _buildTagsRow(),
          if (_currentVideoUrl != null) ...[
            const SizedBox(height: 20),
            _buildServerInfoSection(),
          ],
          const SizedBox(height: 20),
          _buildActionButtons(),
          if (!widget.isMovie && widget.episodeList != null) ...[
            const SizedBox(height: 12),
            _buildEpisodeNavigationButtons(),
          ],
          if (_showWebViewOption && _bloggerVideoUrl != null) ...[
            const SizedBox(height: 12),
            _buildAlternativePlayerButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
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
          _displayLabel,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsRow() {
    return Wrap(
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
        if (_hasAnySubtitleTrack()) _buildSubtitleSelectorTag(context),
      ],
    );
  }

  Widget _buildServerInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.getPrimaryGradient(),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sensors, color: Colors.white, size: 20),
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
    );
  }

  Widget _buildActionButtons() {
    return Row(
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
            onPressed: _currentVideoUrl == null ? null : _copyStreamLink,
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
    );
  }

  Widget _buildAlternativePlayerButton() {
    return SizedBox(
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
    );
  }

  Widget _buildEpisodeNavigationButtons() {
    return Row(
      children: [
        if (_hasPreviousEpisode)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _goToPreviousEpisode,
              icon: const Icon(Icons.skip_previous_rounded),
              label: Text(AppLocalizations.of(context).previousEpisode),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        else
          const SizedBox(),
        if (_hasPreviousEpisode && _hasNextEpisode) const SizedBox(width: 12),
        if (_hasNextEpisode)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _goToNextEpisode,
              icon: const Icon(Icons.skip_next_rounded),
              label: Text(AppLocalizations.of(context).nextEpisode),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        else
          const SizedBox(),
      ],
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

  // ---------------- Subtitle selector ----------------

  /// Retorna `true` se o player tem pelo menos uma legenda disponível —
  /// seja embutida no MKV ou externa (.srt) do PauloFlix.
  bool _hasAnySubtitleTrack() {
    return _embeddedSubtitleTracks.isNotEmpty ||
        _currentEpisode.subtitleTracks.any((s) => s.url != null);
  }

  /// Tag clicável que abre o [_showSubtitleSheet].
  ///
  /// Indica visualmente qual legenda está ativa.
  Widget _buildSubtitleSelectorTag(BuildContext context) {
    final active = _effectiveActiveSubtitleLabel();
    // FocusableWidget: tag de seleção de legenda acessível via d-pad em TV.
    // Em mobile/tablet cai no fallback GestureDetector puro.
    return FocusableWidget(
      onSelect: () => _showSubtitleSheet(context),
      borderRadius: 6,
      focusPadding: EdgeInsets.zero,
      focusScale: 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.closed_caption_rounded,
              color: Color(0xFFEF4444),
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              active ?? AppLocalizations.of(context).subtitles,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: Color(0xFFEF4444),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Devolve o rótulo da faixa ativa, ou null se está em "Auto"/desconhecido.
  String? _effectiveActiveSubtitleLabel() {
    final current = _player?.state.track.subtitle;
    if (current == null) return null;
    if (current.id == 'no') return AppLocalizations.of(context).noSubtitle;
    if (current.id == 'auto') return AppLocalizations.of(context).auto;
    for (final ext in _currentEpisode.subtitleTracks) {
      if (ext.url != null && current.id == ext.url) return ext.displayName;
    }
    for (final embed in _embeddedSubtitleTracks) {
      if (current.id == embed.id) {
        return embed.title ??
            embed.language ??
            AppLocalizations.of(context).subtitleEmbedded;
      }
    }
    return current.title ?? current.language;
  }

  Future<void> _showSubtitleSheet(BuildContext context) async {
    final external = _currentEpisode.subtitleTracks
        .where((s) => s.url != null)
        .toList();
    final embedded = _embeddedSubtitleTracks;
    if (external.isEmpty && embedded.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.closed_caption_rounded,
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.subtitles,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                _buildSubtitleSheetOption(
                  icon: Icons.auto_awesome_rounded,
                  label: l10n.autoRecommended,
                  subtitle: l10n.autoDescription,
                  isActive: _isCurrentSubtitleAuto(),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _selectSubtitle(
                      SubtitleTrack.auto(),
                      label: l10n.auto,
                    );
                  },
                ),
                _buildSubtitleSheetOption(
                  icon: Icons.subtitles_off_rounded,
                  label: l10n.subtitlesOff,
                  subtitle: l10n.subtitlesOffDescription,
                  isActive: _isCurrentSubtitleNone(),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _selectSubtitle(
                      SubtitleTrack.no(),
                      label: l10n.subtitlesOff,
                    );
                  },
                ),
                if (embedded.isNotEmpty) ...[
                  _buildSectionHeader(l10n.embeddedSubtitles),
                  for (final t in embedded)
                    _buildSubtitleSheetOption(
                      icon: Icons.movie_outlined,
                      label: t.title ?? t.language ?? 'Track ${t.id}',
                      subtitle: t.language ?? l10n.unknownLanguage,
                      isActive: _isCurrentSubtitleTrack(t),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _selectSubtitle(
                          t,
                          label: t.title ?? t.language ?? l10n.subtitleEmbedded,
                        );
                      },
                    ),
                ],
                if (external.isNotEmpty) ...[
                  _buildSectionHeader(l10n.externalSubtitles),
                  for (final s in external)
                    _buildSubtitleSheetOption(
                      icon: Icons.subtitles_rounded,
                      label: s.displayName,
                      subtitle: '${s.language} • .srt',
                      isActive: _isCurrentExternalSubtitle(s),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _selectSubtitle(
                          SubtitleTrack.uri(
                            s.url!,
                            title: s.displayName,
                            language: s.language,
                          ),
                          label: s.displayName,
                        );
                      },
                    ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitleSheetOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    // FocusableWidget: opção do sheet de legendas acessível via d-pad em TV.
    // Cada opção da sheet recebe seu próprio nó de foco para navegação.
    // Em mobile/tablet cai no fallback GestureDetector puro.
    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 8,
      focusPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      focusScale: 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFEF4444) : Colors.white60,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  bool _isCurrentSubtitleAuto() {
    final cur = _player?.state.track.subtitle;
    if (cur == null) return true;
    return cur.id == 'auto';
  }

  bool _isCurrentSubtitleNone() {
    final cur = _player?.state.track.subtitle;
    return cur?.id == 'no';
  }

  bool _isCurrentSubtitleTrack(SubtitleTrack t) {
    final cur = _player?.state.track.subtitle;
    return cur != null && cur.id == t.id;
  }

  bool _isCurrentExternalSubtitle(EpisodeSubtitleTrack ext) {
    final cur = _player?.state.track.subtitle;
    if (cur == null || ext.url == null) return false;
    return cur.id == ext.url;
  }

  Future<void> _selectSubtitle(SubtitleTrack track, {String? label}) async {
    try {
      await _player?.setSubtitleTrack(track);
      debugPrint('[VideoPlayer] Subtitle changed to: ${label ?? track.id}');
    } catch (e) {
      debugPrint('[VideoPlayer] Failed to change subtitle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).subtitleError('$e')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }
}
