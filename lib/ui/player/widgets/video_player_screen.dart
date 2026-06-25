import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/services/anime_service.dart';
import '../../../data/services/auth/authenticated_http_client.dart';
import '../../../data/services/auth/jwt_token_manager.dart';
import '../../../data/services/episode_progress_service.dart';
import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/paulo_flix_episode_record.dart';
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/episode_utils.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/skip_button.dart';
import '../video_player_aniskip_mixin.dart';
import 'video_player_episode_buttons.dart';

class ModernVideoPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;
  final bool isMovie;
  final List<Episode>? episodeList;
  final int? episodeIndex;

  /// FK para `paulo_flix_seasons.id` (Fase 2 do plano de progresso).
  /// Quando `null`, o player NÃO cria o `EpisodeProgressService`
  /// (fluxos não-PauloFlix: filmes, AnimeFire).
  final int? seasonId;

  /// Número do episódio. `null` para fluxos não-PauloFlix.
  final String? episodeNumber;

  const ModernVideoPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
    this.anime,
    this.isMovie = false,
    this.episodeList,
    this.episodeIndex,
    this.seasonId,
    this.episodeNumber,
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
  Map<String, String>? _currentVideoHeaders;

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

  // Progresso PauloFlix (Fase 2). `null` para fluxos não-PauloFlix
  // (filmes, AnimeFire).
  EpisodeProgressService? _progressService;

  /// Repository injetado via `PlayerRouteData` (PauloFlix). Usado pelo
  /// service para gravar progresso e pelo player para ler o estado
  /// salvo.
  PauloFlixEpisodeProgressRepository? _progressRepo;

  int? _savedPositionSeconds;
  int? _savedDurationSeconds;
  bool _savedIsCompleted = false;

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
    // Fase 2: lê o repo PauloFlix do Provider (Fase 4 do plano vai
    // registrar no `MultiProvider` em `app.dart`). Para fluxos
    // não-PauloFlix (sem `seasonId`/`episodeNumber`), fica `null` →
    // sem persistência de progresso.
    _progressRepo = widget.seasonId != null && widget.episodeNumber != null
        ? context.read<PauloFlixEpisodeProgressRepository?>()
        : null;
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
    if (event.logicalKey == LogicalKeyboardKey.escape) {
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
      return;
    }

    // Detectar se é TV
    _isTVDevice = await TVDetector.isTV;
    if (!mounted) return;

    if (_isTVDevice == true) {
      // TV: fullscreen + landscape only
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// Configura listener para detectar mudanças no sistema UI (fullscreen exit)
  // void _setupFullscreenListener() {
  //   SystemChrome.setSystemUIChangeCallback((systemOverlaysAreVisible) async {
  //     // systemOverlaysAreVisible = true quando saiu do fullscreen
  //     if (systemOverlaysAreVisible && _isFullscreen) {
  //       setState(() {
  //         _isFullscreen = false;
  //       });

  //       if (_isTVDevice == true) {
  //         // Na TV: fechar o player quando sair do fullscreen
  //         debugPrint('[VideoPlayer] TV: Fechando player ao sair do fullscreen');
  //         if (mounted && Navigator.canPop(context)) {
  //           Navigator.pop(context);
  //         }
  //       }
  //       // No smartphone: apenas sai do fullscreen sem fechar (comportamento padrão)
  //     }
  //   });
  // }

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
    // Fase 2: flush do progresso do episódio atual ANTES de trocar
    // (garante último save no banco).
    // Fire-and-forget: o `flush` é rápido (1 save), não bloqueia a UI.
    // Se falhar, perdemos só este último save — aceitável.
    unawaited(
      _flushProgressService(
        getPos: _getCurrentPosition,
        getDur: _getCurrentDuration,
      ),
    );
    cleanupAniSkip();
    skipButtonActiveSegment = null;
    skipButtonDismissed = false;
    lastAutoHideTime = null;
    skipTimes = null;
    showSkipButton = false;
    skipButtonLabel = '';
    _initializeVideoPlayer();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Fase 2: Progresso de episódio (PauloFlix)
  // ═══════════════════════════════════════════════════════════════════════

  /// Lê o progresso salvo do banco e popula `_savedPositionSeconds`,
  /// `_savedDurationSeconds`, `_savedIsCompleted`. Cria o
  /// `EpisodeProgressService` se PauloFlix.
  ///
  /// Chamado no início de `_initializeVideoPlayer` (antes do setState
  /// de loading).
  Future<void> _loadSavedProgress() async {
    final repo = _progressRepo;
    final seasonId = widget.seasonId;
    final episodeNumberStr = widget.episodeNumber;
    if (repo == null || seasonId == null || episodeNumberStr == null) {
      // Não-PauloFlix ou sem IDs: sem persistência.
      _progressService = null;
      _savedPositionSeconds = null;
      _savedDurationSeconds = null;
      _savedIsCompleted = false;
      return;
    }

    final episodeNumber = int.tryParse(episodeNumberStr);
    if (episodeNumber == null) {
      _progressService = null;
      return;
    }

    // Cria o service (idempotente em caso de re-init).
    _progressService = EpisodeProgressService(
      repo: repo,
      seasonId: seasonId,
      episodeNumber: episodeNumber,
    );

    // Lê o progresso salvo do banco.
    try {
      final episodes = await repo.getEpisodesForSeason(seasonId);
      // Se o episode ainda não foi sincronizado para o banco
      // (primeira abertura antes do sync), `firstWhere` retorna o
      // record vazio (positionSeconds=0, isCompleted=false).
      final saved = episodes.firstWhere(
        (e) => e.episodeNumber == episodeNumber,
        orElse: () => PauloFlixEpisodeRecord(
          seasonId: seasonId,
          episodeNumber: episodeNumber,
          title: '',
          videoUrl: '',
          lastSynced: DateTime.now(),
        ),
      );
      _savedPositionSeconds = saved.positionSeconds;
      _savedDurationSeconds = saved.durationSeconds;
      _savedIsCompleted = saved.isCompleted;
      debugPrint(
        '[VideoPlayer] Saved progress: '
        'pos=${saved.positionSeconds}s '
        'dur=${saved.durationSeconds}s '
        'completed=${saved.isCompleted}',
      );
    } catch (e) {
      debugPrint('[VideoPlayer] Failed to load saved progress: $e');
      _savedPositionSeconds = null;
      _savedDurationSeconds = null;
      _savedIsCompleted = false;
    }
  }

  /// Aplica a heurística de reset vs retomar (Decisão 6) ANTES do
  /// `Media.open`. Retorna `true` se o player deve abrir do zero.
  Future<bool> _maybeResetBeforeOpen() async {
    final service = _progressService;
    if (service == null) return false; // não-PauloFlix: comportamento padrão
    final pos = _savedPositionSeconds ?? 0;
    final dur = _savedDurationSeconds ?? 0;
    return service.prepareResumeOrReset(
      isCompleted: _savedIsCompleted,
      positionSeconds: pos,
      durationSeconds: dur,
    );
  }

  /// Inicia o timer de 5s para gravar progresso. Chamado APÓS
  /// `Media.open` bem-sucedido.
  void _startProgressService() {
    final service = _progressService;
    if (service == null) return;
    service.start(
      getCurrentPosition: _getCurrentPosition,
      getDuration: _getCurrentDuration,
    );
    debugPrint('[VideoPlayer] Progress service started (timer 5s)');
  }

  /// Flush do progresso (último save + cancela timer). Chamado em
  /// `_replaceEpisode` e em `dispose`.
  Future<void> _flushProgressService({
    required Duration Function() getPos,
    required Duration Function() getDur,
  }) async {
    final service = _progressService;
    if (service == null) return;
    await service.flush(getCurrentPosition: getPos, getDuration: getDur);
  }

  /// Closures para o player. `_player` pode ser null durante cleanup.
  Duration _getCurrentPosition() => _player?.state.position ?? Duration.zero;

  Duration _getCurrentDuration() => _player?.state.duration ?? Duration.zero;

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
      skipTimes = null;
      showSkipButton = false;
      skipButtonLabel = '';
    });

    // Fase 2: lê progresso salvo do banco (PauloFlix) ANTES do setState
    // para já ter a decisão de reset/seek pronta quando o Media abrir.
    await _loadSavedProgress();

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
          HttpHeaders.refererHeader: '${ApiConstants.animeFireBaseUrl}/',
        };

        if (actualVideo.hasHeaders) {
          playbackHeaders.addAll(actualVideo.headers);
        }

        controllerHeaders = Map<String, String>.from(playbackHeaders);
      }

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
        // UA Android real — o app roda exclusivamente em Android (celular/TV).
        // UA "Windows" não agrega valor e pode confundir middlewares que
        // olham o SO do cliente.
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'identity;q=1, *;q=0',
        // 'Connection: keep-alive' removido: libmpv já usa HTTP/1.1 nativo
        // e ignora esse header. Em alguns servers (Caddy com config agressiva)
        // pode causar warning ou re-negociação desnecessária.
        'Referer': referer,
        'Sec-Fetch-Dest': 'video',
        'Sec-Fetch-Mode': 'no-cors',
        'Sec-Fetch-Site': 'cross-site',
      };

      // Merge: controller headers take priority over defaults
      final mergedHeaders = {...defaultHeaders, ...controllerHeaders};

      // ═══════════════════════════════════════════════════════════════════════
      // Migração Tailscale → HTTPS+token: se a URL for do PauloFlix, injeta
      // o JWT Authorization no `httpHeaders` do Media.open() (libmpv envia
      // esses headers em CADA range request subsequente).
      // O JwtTokenManager está disponível via Provider (configurado no
      // app.dart). Lê via context.read<>() — safe em initState porque o
      // Provider está registrado no MultiProvider do PauloFlixApp.
      // ═══════════════════════════════════════════════════════════════════════
      if (kPauloFlixHostPattern.hasMatch(uri.host)) {
        try {
          final token = await context.read<JwtTokenManager>().getValidToken();
          mergedHeaders['Authorization'] = 'Bearer $token';
          debugPrint(
            '[VideoPlayer] ✓ JWT injetado no header do player (PauloFlix)',
          );
        } catch (e) {
          debugPrint('[VideoPlayer] ⚠ Falha ao injetar JWT (placeholder?): $e');
          // Sem auth, range requests vão dar 401. Mas o player ainda
          // funciona (vai mostrar erro de playback, não crash).
        }
      }

      debugPrint('[VideoPlayer] Headers: $mergedHeaders');

      // Fase 2: aplica heurística de reset vs retomar (PauloFlix) ANTES
      // do Media.open. Se reset: zera progresso no banco + abre do zero.
      // Se retomar: abre do zero e depois faz seek pós-open.
      // `prepareResumeOrReset` é no-op se `_progressService == null`
      // (fluxos não-PauloFlix).
      final shouldReset = await _maybeResetBeforeOpen();

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

      // Fase 2: se não resetou, faz seek para a posição salva.
      // libmpv exige seek APÓS Media.open — antes é no-op.
      if (!shouldReset &&
          _savedPositionSeconds != null &&
          _savedPositionSeconds! > 0) {
        await _player!.seek(Duration(seconds: _savedPositionSeconds!));
        debugPrint(
          '[VideoPlayer] Resuming at ${_savedPositionSeconds}s '
          '(of ${_savedDurationSeconds ?? "?"}s)',
        );
      }

      // Fase 2: inicia o timer de 5s para gravar progresso.
      _startProgressService();

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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
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

    // Fase 2: flush do progresso PauloFlix (último save + cancela timer).
    // Fire-and-forget — `dispose` não aceita async; o flush roda em
    // background. Se falhar, perdemos só este último save (aceitável).
    unawaited(
      _flushProgressService(
        getPos: _getCurrentPosition,
        getDur: _getCurrentDuration,
      ),
    );

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

  Widget _buildFullscreenContent() {
    final isTV = _isTVDevice == true;
    final hasEpisodes = !widget.isMovie && widget.episodeList != null;

    log(
      '[VideoPlayer] Building fullscreen content (isTV: $isTV, hasEpisodes: $hasEpisodes)',
    );

    // Atalhos de teclado customizados para TV (D-pad)
    // O MaterialDesktopVideoControls NÃO trata select/enter por padrão.
    final tvKeyboardShortcuts = <ShortcutActivator, VoidCallback>{
      // Select/Enter → play/pause (botão do meio do D-pad)
      const SingleActivator(LogicalKeyboardKey.select): () {
        _player?.playOrPause();
        _showOverlayControlsAndResetTimer();
      },
      const SingleActivator(LogicalKeyboardKey.enter): () {
        _player?.playOrPause();
        _showOverlayControlsAndResetTimer();
      },
      // Space → play/pause (já existe no padrão, mas reforçamos)
      const SingleActivator(LogicalKeyboardKey.space): () {
        _player?.playOrPause();
        _showOverlayControlsAndResetTimer();
      },
      // Setas → mostrar controles
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
        _showOverlayControlsAndResetTimer();
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
        _showOverlayControlsAndResetTimer();
      },
      const SingleActivator(LogicalKeyboardKey.arrowUp): () {
        _showOverlayControlsAndResetTimer();
      },
      const SingleActivator(LogicalKeyboardKey.arrowDown): () {
        _showOverlayControlsAndResetTimer();
      },
      // N/P → próximo/anterior episódio
      if (hasEpisodes && _hasNextEpisode)
        const SingleActivator(LogicalKeyboardKey.keyN): _goToNextEpisode,
      if (hasEpisodes && _hasPreviousEpisode)
        const SingleActivator(LogicalKeyboardKey.keyP): _goToPreviousEpisode,
      // Media keys
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () {
        _player?.playOrPause();
        _showOverlayControlsAndResetTimer();
      },
    };

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _showOverlayControlsAndResetTimer,
      child: MouseRegion(
        onHover: (_) => _showOverlayControlsAndResetTimer(),
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Vídeo com MaterialDesktopVideoControls (TV)
              _videoController != null
                  ? (isTV
                        ? MaterialDesktopVideoControlsTheme(
                            normal: MaterialDesktopVideoControlsThemeData(
                              visibleOnMount: true,
                              playAndPauseOnTap: true,
                              keyboardShortcuts: tvKeyboardShortcuts,
                              bottomButtonBar: [
                                if (hasEpisodes && _hasPreviousEpisode)
                                  EpisodeSkipPreviousButton(
                                    onPressed: _goToPreviousEpisode,
                                  ),
                                const MaterialDesktopPlayOrPauseButton(),
                                if (hasEpisodes && _hasNextEpisode)
                                  EpisodeSkipNextButton(
                                    onPressed: _goToNextEpisode,
                                  ),
                                const MaterialDesktopVolumeButton(),
                                const MaterialDesktopPositionIndicator(),
                                const Spacer(),
                                const MaterialDesktopFullscreenButton(),
                              ],
                            ),
                            fullscreen: MaterialDesktopVideoControlsThemeData(
                              visibleOnMount: true,
                              playAndPauseOnTap: true,
                              keyboardShortcuts: tvKeyboardShortcuts,
                              bottomButtonBar: [
                                if (hasEpisodes && _hasPreviousEpisode)
                                  EpisodeSkipPreviousButton(
                                    onPressed: _goToPreviousEpisode,
                                  ),
                                const MaterialDesktopPlayOrPauseButton(),
                                if (hasEpisodes && _hasNextEpisode)
                                  EpisodeSkipNextButton(
                                    onPressed: _goToNextEpisode,
                                  ),
                                const MaterialDesktopVolumeButton(),
                                const MaterialDesktopPositionIndicator(),
                                const Spacer(),
                                const MaterialDesktopFullscreenButton(),
                              ],
                            ),
                            child: Video(
                              controller: _videoController!,
                              fit: BoxFit.contain,
                              controls: MaterialDesktopVideoControls,
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
                right: isTV ? 80 : 60,
                child: AnimatedOpacity(
                  opacity: _showOverlayControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    child: Material(
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          FocusableWidget(
                            onSelect: () {
                              Navigator.pop(context);
                            },
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
              // Skip Button Overlay (AniSkip)
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
    final inner = Container(
      color: Colors.black,
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
    return SizedBox.expand(child: inner);
  }

  Widget _buildErrorState() {
    final inner = Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: _buildErrorWidget(
          _errorMessage ?? AppLocalizations.of(context).error,
        ),
      ),
    );
    return SizedBox.expand(child: inner);
  }
}
