import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../../data/services/auth/authenticated_http_client.dart';
import '../../../data/services/auth/jwt_token_manager.dart';
import '../../../data/services/episode_progress_service.dart';
import '../../../data/services/movie_progress_service.dart';
import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/paulo_flix_episode_record.dart';
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import '../../../domain/repositories/paulo_flix_movie_progress_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/logger/app_logger.dart';
import '../../core/utils/episode_utils.dart';
import '../../core/utils/tv_detector.dart';
import '../video_player_introdb_mixin.dart';
import 'modern_video_player_controls.dart';

class ModernVideoPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;
  final bool isMovie;
  final int? episodeIndex;

  /// FK para `paulo_flix_content.id` (Fase 5 do plano de progresso —
  /// usado pelo auto-play para buscar a próxima season).
  /// `null` para fluxos não-PauloFlix (filmes, AnimeFire).
  final int? contentId;

  /// FK para `paulo_flix_seasons.id` (Fase 2 do plano de progresso).
  /// Quando `null`, o player NÃO cria o `EpisodeProgressService`
  /// (fluxos não-PauloFlix: filmes, AnimeFire).
  final int? seasonId;

  /// Número do episódio. `null` para fluxos não-PauloFlix.
  final String? episodeNumber;

  /// `folderName` do filme para salvar progresso (PauloFlix Movies).
  /// `null` para fluxos que não são filmes.
  final String? movieFolderName;

  /// TMDB ID para consulta de segmentos (intro/outro) via TheIntroDB.
  /// `null` para fluxos sem metadados TMDB (AnimeFire, etc.).
  final int? tmdbId;

  /// Número da temporada (1, 2, 3...) para consulta TheIntroDB em TV.
  /// `null` para filmes ou quando não disponível.
  final int? seasonNumber;

  /// PlatformPlayer opcional injetado para testes.
  /// Quando `null`, cria o Player padrão (produção).
  /// Quando fornecido, usa este PlatformPlayer mockado, evitando
  /// dependência de libs nativas em ambiente de teste.
  final PlatformPlayer? platformPlayer;

  const ModernVideoPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
    this.anime,
    this.isMovie = false,
    this.episodeIndex,
    this.contentId,
    this.seasonId,
    this.episodeNumber,
    this.movieFolderName,
    this.tmdbId,
    this.seasonNumber,
    this.platformPlayer,
  });

  @override
  State<ModernVideoPlayerScreen> createState() =>
      _ModernVideoPlayerScreenState();
}

class _ModernVideoPlayerScreenState extends State<ModernVideoPlayerScreen>
    with VideoPlayerIntroDbMixin {
  final _log = const AppLogger('VideoPlayer');

  late final _player = Player(
    platformPlayer: widget.platformPlayer,
    configuration: const PlayerConfiguration(logLevel: MPVLogLevel.info),
  );
  late final _videoController = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(
      enableHardwareAcceleration: true,
      androidAttachSurfaceAfterVideoParameters: true,
    ),
  );
  List<VideoTrack>? videos;
  List<AudioTrack>? audios;
  List<SubtitleTrack>? subtitles;
  AudioTrack? audiosBr;
  Map<String, String>? _currentVideoHeaders;

  // bool? _isTVDevice;

  // Future de detecção de TV disparado em initState. `_initializeVideoPlayer`
  // aguarda este future ANTES de criar o Player, eliminando a race onde a
  // orientação era aplicada depois do `Media.open` ou a checagem de HW
  // accel via `_isTVDevice` ficava `null` entre a chamada duplicada
  // (`_detectDeviceAndEnterFullscreen` + chamada em `_initializeVideoPlayer`).
  Future<bool>? _tvDetectionFuture;

  // Stream subscriptions — guardadas para cancelar em _cleanupControls e
  // evitar listeneres órfãos que disparam setState após troca de episódio.
  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;
  StreamSubscription<Tracks>? _tracksSub;

  /// Subscription do listener de tracks para debug/logging (linha ~310 em
  /// `_initializeVideoPlayer`). Mantida separada de `_tracksSub` porque
  /// `_waitForEmbeddedSubtitleTracks` sobrescreve `_tracksSub` com uma
  /// subscription local (completer + timeout).
  StreamSubscription<Tracks>? _debugTracksSub;

  /// `true` após a primeira configuração das subscrições persistentes
  /// (`_debugTracksSub`, `_playingSub`, `_completedSub`).
  /// Evita recriar essas subs a cada `_replaceEpisode()`.
  bool _streamSubsReady = false;

  /// Flag de disposed. Toda operação assíncrona pendente deve verificar
  /// esta flag ANTES de acessar `_player` ou chamar `setState`.
  bool _disposed = false;

  /// Flag de erro ativo. Impede que `player.stream.completed` dispare
  /// `_findAndPlayNextEpisode()` durante um erro de streaming, evitando
  /// que o app comece a tocar o próximo episódio enquanto o usuário vê
  /// o overlay de erro.
  /// Setada como `true` em `_stopProgressServices()`, resetada como `false`
  /// no início de `_initializeVideoPlayer()`.
  bool _hasPlayerError = false;

  /// Flag para evitar dupla chamada de `_saveFinalProgress`.
  /// `_exitPlayer()` inicia o save antes do pop; `dispose()` também
  /// tenta salvar (idempotente). Esta flag pula o segundo save.
  bool _progressSavedOnExit = false;

  // ═══════════════════════════════════════════════════════════════════
  // Auto-play próximo episódio
  // ═══════════════════════════════════════════════════════════════════

  /// Season atual (mutável para suportar transição entre temporadas
  /// no auto-play). Inicializado a partir de `widget.seasonId`.
  int? _currentSeasonId;

  /// Número do episódio atual (mutável para suportar auto-play).
  /// Inicializado a partir de `widget.episodeNumber`.
  int _currentEpisodeNum = 1;

  // Progresso PauloFlix (Fase 2). `null` para fluxos não-PauloFlix
  // (AnimeFire).
  EpisodeProgressService? _progressService;

  /// Repository injetado via `PlayerRouteData` (PauloFlix). Usado pelo
  /// service para gravar progresso e pelo player para ler o estado
  /// salvo.
  PauloFlixEpisodeProgressRepository? _progressRepo;

  // Progresso de filmes PauloFlix Movies (P1). `null` para fluxos
  // que não são filmes PauloFlix (animes, AnimeFire).
  MovieProgressService? _movieProgressService;

  /// Repository de progresso de filmes. Lido do Provider quando
  /// `widget.isMovie && widget.movieFolderName != null`.
  PauloFlixMovieProgressRepository? _movieProgressRepo;

  JwtTokenManager? _jwtTokenManager;

  int? _savedPositionSeconds;
  int? _savedDurationSeconds;
  bool _savedIsCompleted = false;

  /// `true` quando há um próximo episódio disponível no banco.
  /// Controla a visibilidade do botão "Próximo episódio" nos controles.
  /// Inicializado como `false` e re-verificado a cada troca de episódio.
  bool _hasNextEpisode = false;

  // Handler global de hardware keyboard. Usamos HardwareKeyboard em vez de
  // Focus/CallbackShortcuts para interceptar teclas SEM competir pelo foco
  // de teclado da árvore (Focus). Isso é crítico porque o Focus interno do
  // MaterialDesktopVideoControls precisa estar focado para os atalhos
  // space/setas/J/K/F funcionarem via CallbackShortcuts nativo do package.
  bool _hardwareKeyboardHandlerInstalled = false;

  /// Tracks de legenda embutidas no MKV (lidas via `Player.state.tracks.subtitle`
  /// assim que o `Media.open` finaliza).
  List<SubtitleTrack> _embeddedSubtitleTracks = const [];

  late Episode _currentEpisode;

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

  // --- VideoPlayerIntroDbMixin abstract member implementations ---

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

  /// Constrói uma chave única para o episódio atual.
  String _buildEpisodeKey() {
    return '${widget.animeTitle}|${_currentEpisode.number}|${_currentEpisode.url}|${widget.tmdbId}';
  }

  @override
  void initState() {
    super.initState();
    _currentEpisode = widget.episode;
    _currentSeasonId = widget.seasonId;
    _currentEpisodeNum = int.tryParse(widget.episodeNumber ?? '') ?? 1;
    // Fase 2: lê o repo PauloFlix do Provider (Fase 4 do plano vai
    // registrar no `MultiProvider` em `app.dart`). Para fluxos
    // não-PauloFlix (sem `seasonId`/`episodeNumber`), fica `null` →
    // sem persistência de progresso.
    _progressRepo = widget.seasonId != null && widget.episodeNumber != null
        ? context.read<PauloFlixEpisodeProgressRepository?>()
        : null;
    _movieProgressRepo = widget.isMovie && widget.movieFolderName != null
        ? context.read<PauloFlixMovieProgressRepository?>()
        : null;
    _jwtTokenManager = context.read<JwtTokenManager?>();
    _detectDeviceAndEnterFullscreen();
    _installHardwareKeyboardHandler();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideoPlayer();
      _refreshNextEpisodeAvailability();
    });
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

    // Esc: volta para a tela anterior (mesmo comportamento do botão back
    // do app). Não fecha o app em TV — convenção Netflix/YouTube TV:
    // back do controle volta para a home do app, não pro launcher.
    // Se não houver rota pai, _exitPlayer decide o fallback.
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _exitPlayer();
      return true; // consumido: não propaga para MaterialDesktopVideoControls
    }

    // Qualquer outra tecla: re-mostra overlay.
    return false; // deixa propagar (espaco/setas/J/K/F vão para controls)
  }

  void _uninstallHardwareKeyboardHandler() {
    if (!_hardwareKeyboardHandlerInstalled) return;
    _hardwareKeyboardHandlerInstalled = false;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
  }

  /// Detecta o tipo de dispositivo e configura comportamentos específicos (TV, etc.)
  ///
  /// Dispara o future `_tvDetectionFuture` para que `_initializeVideoPlayer`
  /// possa aguardar o resultado antes de criar o Player. Isso elimina a race
  /// onde a checagem `_isTVDevice == true` chegava tarde e o HW accel era
  /// configurado com base em `null`.
  void _detectDeviceAndEnterFullscreen() {
    if (!mounted) return;
    if (!Platform.isAndroid) {
      // _isTVDevice = false;
      _tvDetectionFuture = Future.value(false);
      return;
    }
    _tvDetectionFuture = _resolveIsTV();
  }

  Future<bool> _resolveIsTV() async {
    final isTV = await TVDetector.isTV;
    if (!mounted) return false;
    // _isTVDevice = isTV;
    if (isTV) {
      // TV: fullscreen + landscape only. Aplicar AGORA (não em
      // _initializeVideoPlayer) garante que a orientação já está
      // travada antes de o Media.open rodar.
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    return isTV;
  }

  /// Troca o episódio atual e reabre a mídia sem recriar as subs
  /// persistentes (_debugTracksSub, _playingSub, _completedSub).
  /// A primeira chamada vai para `_initializeVideoPlayer` que
  /// configura as subs uma vez; as chamadas seguintes pulam o setup.
  void _replaceEpisode(Episode newEpisode) {
    if (!mounted) return;
    setState(() {
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
    unawaited(
      _flushMovieProgressService(
        getPos: _getCurrentPosition,
        getDur: _getCurrentDuration,
      ),
    );
    cleanupIntroDb();
    skipButtonActiveSegment = null;
    skipButtonDismissed = false;
    maybeReshowSkipButton();
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
    if (_disposed) return;
    final repo = _progressRepo;
    final seasonId = _currentSeasonId;
    final episodeNumber = _currentEpisodeNum;
    if (repo == null || seasonId == null) {
      // Não-PauloFlix ou sem IDs: sem persistência.
      _progressService = null;
      _savedPositionSeconds = null;
      _savedDurationSeconds = null;
      _savedIsCompleted = false;
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
      _log.debug(
        'Saved progress: '
        'pos=${saved.positionSeconds}s '
        'dur=${saved.durationSeconds}s '
        'completed=${saved.isCompleted}',
      );
    } catch (e, st) {
      _log.error('Failed to load saved progress', e, st);
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
    _log.debug('Progress service started (timer 5s)');
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

  // ═══════════════════════════════════════════════════════════════════════
  // P1: Progresso de filmes (PauloFlix Movies)
  // ═══════════════════════════════════════════════════════════════════════

  /// Lê o progresso salvo do banco para o filme atual.
  Future<void> _loadMovieSavedProgress() async {
    if (_disposed) return;
    final repo = _movieProgressRepo;
    final folderName = widget.movieFolderName;
    if (repo == null || folderName == null) {
      _movieProgressService = null;
      _savedPositionSeconds = null;
      _savedDurationSeconds = null;
      _savedIsCompleted = false;
      return;
    }

    final serverUrl = widget.anime?.url ?? '';
    final displayName = widget.animeTitle;
    final imageUrl = widget.anime?.fallbackImageUrl;

    _movieProgressService = MovieProgressService(
      repository: repo,
      folderName: folderName,
      serverUrl: serverUrl,
      displayName: displayName,
      imageUrl: imageUrl,
      initialVideoUrl: _currentEpisode.url,
    );

    try {
      final saved = await repo.getProgress(folderName);
      if (saved != null) {
        _savedPositionSeconds = saved.positionSeconds;
        _savedDurationSeconds = saved.durationSeconds;
        _savedIsCompleted = saved.isCompleted;
        _log.debug(
          'Movie saved progress: '
          'pos=${saved.positionSeconds}s '
          'dur=${saved.durationSeconds}s '
          'completed=${saved.isCompleted}',
        );
      } else {
        _savedPositionSeconds = null;
        _savedDurationSeconds = null;
        _savedIsCompleted = false;
      }
    } catch (e, st) {
      _log.error('Failed to load movie progress', e, st);
      _savedPositionSeconds = null;
      _savedDurationSeconds = null;
      _savedIsCompleted = false;
    }
  }

  /// Aplica heurística de reset vs retomar para filmes.
  Future<bool> _maybeResetMovieBeforeOpen() async {
    final service = _movieProgressService;
    if (service == null) return false;
    final pos = _savedPositionSeconds ?? 0;
    final dur = _savedDurationSeconds ?? 0;
    return service.prepareResumeOrReset(
      isCompleted: _savedIsCompleted,
      positionSeconds: pos,
      durationSeconds: dur,
    );
  }

  /// Inicia o timer de 5s para gravar progresso do filme.
  void _startMovieProgressService() {
    final service = _movieProgressService;
    if (service == null) return;
    service.start(
      getCurrentPosition: _getCurrentPosition,
      getDuration: _getCurrentDuration,
    );
    _log.debug('Movie progress service started (timer 5s)');
  }

  /// Flush do progresso do filme (último save + cancela timer).
  Future<void> _flushMovieProgressService({
    required Duration Function() getPos,
    required Duration Function() getDur,
  }) async {
    final service = _movieProgressService;
    if (service == null) return;
    await service.flush(getCurrentPosition: getPos, getDuration: getDur);
  }

  /// Para todos os timers ativos (progresso episódios/filmes + AniSkip)
  /// e bloqueia auto-play acidental via `_completedSub`.
  ///
  /// Chamado quando um erro de streaming é detectado, ANTES que
  /// `player.state.position` zere e sobrescreva o progresso salvo
  /// no banco com posição 0.
  void _stopProgressServices() {
    _hasPlayerError = true;
    // Salva o progresso atual ANTES de parar os timers, para que a
    // última posição seja persistida mesmo em caso de erro de rede.
    // Usa saveProgress com valores capturados (não closures) para
    // evitar dependência do estado do player após o stop.
    //
    // Só salva se a posição for > 0, para evitar que uma posição
    // corrompida (0) sobrescreva o último progresso válido salvo
    // pelo timer periódico.
    final pos = _getCurrentPosition();
    final dur = _getCurrentDuration();
    if (pos.inSeconds > 0) {
      unawaited(_progressService?.saveProgress(
        positionSeconds: pos.inSeconds,
        durationSeconds: dur.inSeconds > 0 ? dur.inSeconds : null,
      ));
      unawaited(_movieProgressService?.saveProgress(
        positionSeconds: pos.inSeconds,
        durationSeconds: dur.inSeconds > 0 ? dur.inSeconds : null,
      ));
    }
    _progressService?.stop();
    _movieProgressService?.stop();
    cleanupIntroDb();
    _log.debug('⏹ All timers stopped (player error)');
  }

  /// Configura as stream subscriptions persistentes uma ÚNICA vez.
  /// Chamado na primeira execução de `_initializeVideoPlayer`.
  /// Em trocas de episódio (`_replaceEpisode`), o guard `_streamSubsReady`
  /// impede que sejam recriadas.
  void _ensurePersistentSubscriptions() {
    if (_streamSubsReady) return;
    _streamSubsReady = true;

    _log.debug('Setting up persistent stream subscriptions');

    // Tracks de áudio/vídeo/legenda (debug + áudio PT-BR).
    _debugTracksSub = _player.stream.tracks.listen((event) {
      videos = event.video;
      audios = event.audio;
      subtitles = event.subtitle;
      final currentAudios = audios;
      if (currentAudios == null || currentAudios.isEmpty) return;
      for (final st in audios!) {
        if (st.language != null && st.language!.toLowerCase() == 'por') {
          audiosBr = st;
          return;
        }
        _log.debug('audios language: ${st.language}');
      }
    });

    // Debug: estado de playing.
    _playingSub = _player.stream.playing.listen((playing) {
      _log.debug('Playing state: $playing');
    });

    // Completed: auto-play próximo episódio.
    // O guard `_hasPlayerError` impede que o completed disparado pelo
    // `end-file(reason=error)` do mpv inicie o próximo episódio enquanto
    // o usuário vê o overlay de erro.
    _completedSub = _player.stream.completed.listen((completed) {
      _log.debug('Completed: $completed');
      if (!mounted || !completed || _hasPlayerError) return;
      _findAndPlayNextEpisode();
    });
  }

  /// Limpa apenas subs específicas do episódio atual (embedded tracks).
  /// Não mexe nas subs persistentes (`_playingSub`, `_completedSub`,
  /// `_debugTracksSub`) — evita recriá-las a cada troca de episódio.
  Future<void> _cleanupEpisodeSubs() async {
    await _tracksSub?.cancel();
    _tracksSub = null;
    _currentVideoHeaders = null;
  }

  /// Closures para o player. `_player` pode ser null durante cleanup.
  Duration _getCurrentPosition() => _player.state.position;

  Duration _getCurrentDuration() => _player.state.duration;

  /// Espera o `Player.stream.tracks` emitir um snapshot com pelo menos
  /// uma faixa de legenda (embutida) ou atingir o timeout. Substitui o
  /// `Future.delayed(500ms)` mágico, que falhava em streams lentos.
  ///
  /// Se o vídeo não tiver legendas embutidas, o snapshot chegará com
  /// `subtitle` vazio — o método retorna OK nesse caso após o timeout.
  Future<void> _waitForEmbeddedSubtitleTracks(String episodeKey) async {
    final player = _player;

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

    timeoutTimer = Timer(const Duration(seconds: 2), () {
      _log.debug('Tracks stream timeout (2s)');
      finish();
    });

    try {
      sub = player.stream.tracks.listen((t) {
        _log.debug(
          'Embedded subtitle tracks: ${t.subtitle.length}',
        );
        for (final st in t.subtitle) {
          _log.debug(
            '  embed: id=${st.id}, '
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
    } catch (e, st) {
      _log.error('Error waiting for embedded tracks', e, st);
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_disposed || !mounted) return;

    final episodeKey = _buildEpisodeKey();
    _log.debug('🎬 Initializing player for episode: $episodeKey');    // ═══════════════════════════════════════════════════════════════════
    // Paraleliza tarefas independentes no início da inicialização:
    // 1. DB read (progresso salvo do episódio/filme)  — 5-50ms
    // 2. TV detection (já iniciada em initState)       — 10-100ms
    // 3. JWT token fetch (usado antes do Media.open)   — 0-500ms
    //
    // Antes: DB → TV → (surface init → JWT)  (sequencial)
    // Depois: [DB + TV + JWT] em paralelo     (max dos 3)
    // ═══════════════════════════════════════════════════════════════════
    final dbFuture = widget.isMovie && widget.movieFolderName != null
        ? _loadMovieSavedProgress()
        : _loadSavedProgress();
    final tvFuture = _tvDetectionFuture ?? Future.value(false);
    // Inicia o fetch do JWT imediatamente — o token será aguardado
    // logo antes do Media.open (dentro do try block).
    final jwtFuture = _jwtTokenManager?.getValidToken();

    await Future.wait([dbFuture, tvFuture]);
    // jwtFuture continua em voo e será aguardado quando necessário.

    // Configura subs persistentes uma ÚNICA vez (não recria a cada
    // _replaceEpisode).
    _ensurePersistentSubscriptions();

    try {
      // Limpa apenas subs específicas do episódio anterior (embedded
      // tracks). Não mexe em _debugTracksSub, _playingSub, _completedSub.
      await _cleanupEpisodeSubs();

      String resolvedVideoUrl;

      // Verificar se é PauloFlix (URL direta do arquivo MKV)
      _log.debug('PauloFlix: Using direct URL');
      resolvedVideoUrl = _currentEpisode.url;

      _log.debug('Using playback headers: $_currentVideoHeaders');

      // Aguarda a Surface Android estar pronta antes de abrir a mídia
      await _player.platform?.waitForVideoControllerInitializationIfAttached
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => _log.debug('Surface init timeout'),
          );

      // Subs persistentes (_playingSub, _completedSub) já foram
      // configuradas por _ensurePersistentSubscriptions() — não recriar.

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
      final mergedHeaders = {...defaultHeaders};

      // ═══════════════════════════════════════════════════════════════════════
      // Reseta flag de erro APENAS quando o novo Media.open está prestes a
      // acontecer. Se fosse resetado no início de _initializeVideoPlayer(),
      // um evento completed antigo (ainda na fila de eventos) poderia passar.
      _hasPlayerError = false;

      // ═══════════════════════════════════════════════════════════════════════
      // Migração Tailscale → HTTPS+token: se a URL for do PauloFlix, injeta
      // o JWT Authorization no `httpHeaders` do Media.open() (libmpv envia
      // esses headers em CADA range request subsequente).
      // O JWT já foi iniciado em paralelo com DB + TV detection no início
      // de _initializeVideoPlayer, então `await jwtFuture` geralmente
      // retorna instantaneamente (o fetch já completou).
      // ═══════════════════════════════════════════════════════════════════════
      if (kPauloFlixHostPattern.hasMatch(uri.host)) {
        try {
          final token = await jwtFuture ?? '';
          mergedHeaders['Authorization'] = 'Bearer $token';
          _log.debug(
            '✓ JWT injetado no header do player (PauloFlix)',
          );
        } catch (e, st) {
          _log.warning('⚠ Falha ao injetar JWT (placeholder?)', e, st);
          // Sem auth, range requests vão dar 401. Mas o player ainda
          // funciona (vai mostrar erro de playback, não crash).
        }
      }

      _log.debug('Headers: $mergedHeaders');

      // Fase 2: aplica heurística de reset vs retomar (PauloFlix) ANTES
      // do Media.open. Se reset: zera progresso no banco + abre do zero.
      // Se retomar: abre do zero e depois faz seek pós-open.
      // `prepareResumeOrReset` é no-op se `_progressService == null`
      // (fluxos não-PauloFlix).
      final shouldReset = widget.isMovie
          ? await _maybeResetMovieBeforeOpen()
          : await _maybeResetBeforeOpen();
      try {
        final media = Media(resolvedVideoUrl, httpHeaders: mergedHeaders);
        await _player.open(media, play: false);
        _log.debug(
          'Media opened (paused, waiting for video ready)',
        );
      } catch (e, st) {
        _log.warning('Failed with headers, trying without...', e, st);
        // Fallback: try without headers
        final media = Media(resolvedVideoUrl);
        await _player.open(media, play: false);
        _log.debug('Media opened (no headers fallback, paused)');
      }

      // Espera o media_kit parsear o contêiner e popular as tracks
      // embutidas. O `state.tracks` é populado de forma assíncrona após
      // `Media.open`, então ouvimos o `stream.tracks` em vez de assumir um
      // delay fixo (que falha em streams lentos / contêineres grandes).
      await _waitForEmbeddedSubtitleTracks(episodeKey);
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
          await _player.setSubtitleTrack(subtitle);
          _log.debug('Subtitle loaded: ${s.displayName}');
        } catch (e, st) {
          _log.warning('Failed to load subtitle', e, st);
          // Não derruba a reprodução — vídeo continua sem legenda.
        }
      } else if (_embeddedSubtitleTracks.isNotEmpty) {
        // Sem legenda externa, ativa "Auto" no media_kit para usar o
        // detectado nas embutidas.
        try {
          await _player.setSubtitleTrack(SubtitleTrack.auto());
          _log.debug('Subtitle auto (from embedded tracks)');
        } catch (e, st) {
          _log.warning('Failed auto subtitle', e, st);
        }
      }

      // Wait for video dimensions to be available before starting playback.
      // This prevents audio playing before the video surface is ready.
      // We listen to the tracks stream which fires when the video track
      // is parsed (contains video dimensions).
      await _player.stream.tracks
          .firstWhere((tracks) => tracks.video.isNotEmpty)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              _log.debug('Timeout waiting for video tracks');
              return const Tracks();
            },
          );

      // Fase 2: seek para a posição salva APÓS o vídeo estar carregado.
      // Buscar antes do tracks.firstWhere resolver faz o seek ser perdido
      // porque o libmpv ainda não conhece a duração do arquivo — o seek
      // é aplicado contra um arquivo de duração zero e depois sobrescrito
      // quando o demuxer termina de carregar o metadado.
      if (!shouldReset &&
          _savedPositionSeconds != null &&
          _savedPositionSeconds! > 0) {
        _log.debug(
          'Resuming at ${_savedPositionSeconds}s '
          '(of ${_savedDurationSeconds ?? "?"}s) '
          '— seeking after video tracks ready',
        );
        await _player.seek(Duration(seconds: _savedPositionSeconds!));
      }

      // Fase 2: inicia o timer de 5s para gravar progresso.
      // Iniciar APÓS o seek garante que a posição salva no primeiro tick
      // reflete a posição correta (não o pulo do seek que zera e depois
      // vai para a posição salva).
      if (widget.isMovie) {
        _startMovieProgressService();
      } else {
        _startProgressService();
      }

      // Video is ready — start playback now
      await _player.play();
      _log.debug('Playback started');

      if (audiosBr != null) {
        _log.debug('Found Portuguese audio track: ${audiosBr!.id}');
        await _player.setAudioTrack(audiosBr!);
      }

      if (!mounted) return;

      final videoDurationSeconds = _player.state.duration.inSeconds;
      _log.debug('Duration (s): $videoDurationSeconds');

      // Seta chave do episódio ativo para o mixin IntroDB.
      activeEpisodeKey = _buildEpisodeKey();

      // Carrega segmentos de intro/outro via TheIntroDB.
      // Fire-and-forget: a chamada HTTP não precisa bloquear o
      // início da reprodução — os segmentos só são usados quando
      // o player atinge a intro/outro (minutos depois).
      unawaited(loadSkipSegments(
        tmdbId: widget.tmdbId,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.isMovie ? null : _currentEpisodeNum,
      ));
    } catch (e, st) {
      _log.error('Error initializing video', e, st);
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _uninstallHardwareKeyboardHandler();
    SystemChrome.setSystemUIChangeCallback(null);

    // ═══════════════════════════════════════════════════════════════════
    // Fase 2: para os timers de progresso ANTES de dispose do player.
    // ═══════════════════════════════════════════════════════════════════
    // `stop()` cancela o timer periodic SYNCHRONOUSLY — evita que o
    // timer dispare após `_player.dispose()` e tente ler `_player.state`.
    _progressService?.stop();
    _movieProgressService?.stop();

    // Captura a posição/duration ANTES de stop/dispose do player.
    final lastPosition = _player.state.position;
    final lastDuration = _player.state.duration;

    // Só salva se não tiver sido salvo em _exitPlayer. Evita o duplo
    // save idempotente (já que _exitPlayer iniciou o save antes do pop).
    if (!_progressSavedOnExit) {
      unawaited(_saveFinalProgress(lastPosition, lastDuration));
    }

    // Cleanup síncrono: para o player antes do State ser desmontado
    _player.stop();

    _playingSub?.cancel();
    _completedSub?.cancel();
    _tracksSub?.cancel();
    _debugTracksSub?.cancel();

    _player.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  /// Salva o progresso final ANTES do player ser completamente descartado.
  /// Usa valores capturados (não closures) para evitar acesso a
  /// `_player.state` após `_player.dispose()`.
  Future<void> _saveFinalProgress(Duration position, Duration duration) async {
    // NOTA: não verificar _disposed aqui — este método é chamado APENAS
    // de dispose(), que já setou _disposed=true. A verificação impediria
    // o último save de progresso.
    await _progressService?.saveProgress(
      positionSeconds: position.inSeconds,
      durationSeconds: duration.inSeconds > 0 ? duration.inSeconds : null,
    );
    await _movieProgressService?.saveProgress(
      positionSeconds: position.inSeconds,
      durationSeconds: duration.inSeconds > 0 ? duration.inSeconds : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Auto-play próximo episódio
  // ═══════════════════════════════════════════════════════════════════

  /// Busca no banco o próximo episódio disponível e inicia a reprodução
  /// automática. Suporta transição entre temporadas: se o episódio atual
  /// é o último da season, busca a primeira season seguinte.
  ///
  /// Usa o método eficiente [PauloFlixEpisodeProgressRepository.getNextEpisode]
  /// que faz 1-3 queries indexadas (sem carregar TODOS os episódios).
  ///
  /// Só funciona para conteúdo PauloFlix (requer `_currentSeasonId` e
  /// `_progressRepo`). Para filmes ou outras fontes (AnimeFire), é no-op.
  Future<void> _findAndPlayNextEpisode() async {
    if (_disposed || !mounted) return;
    if (_currentSeasonId == null || _progressRepo == null) return;

    try {
      final nextRecord = await _progressRepo!.getNextEpisode(
        seasonId: _currentSeasonId!,
        episodeNumber: _currentEpisodeNum,
      );

      if (nextRecord != null) {
        _playNextEpisode(nextRecord, nextRecord.seasonId);
      } else {
        if (mounted) setState(() => _hasNextEpisode = false);
        const AppLogger('VideoPlayer').debug(
          'No next episode available '
          '(season $_currentSeasonId, ep $_currentEpisodeNum)',
        );
      }
    } catch (e, st) {
      const AppLogger('VideoPlayer').error(
        'Error finding next episode',
        e,
        st,
      );
    }
  }

  /// Handler do botão "Próximo episódio" nos controles.
  /// Dispara a mesma lógica do auto-play, mas fire-and-forget
  /// (não bloqueia a UI).
  void _onNextEpisodePressed() {
    if (_disposed || !mounted) return;
    const AppLogger('VideoPlayer').debug('▶ Next episode button pressed');
    unawaited(_findAndPlayNextEpisode());
  }

  /// Converte um [PauloFlixEpisodeRecord] em [Episode] e inicia a
  /// reprodução via [_replaceEpisode]. Atualiza os campos mutáveis
  /// de season/episode para que o progresso seja salvo corretamente.
  void _playNextEpisode(PauloFlixEpisodeRecord record, int seasonId) {
    if (!mounted) return;

    setState(() {
      _currentSeasonId = seasonId;
      _currentEpisodeNum = record.episodeNumber;
    });
    _refreshNextEpisodeAvailability();

    final nextEpisode = Episode(
      number: record.episodeNumber.toString(),
      url: record.videoUrl,
      title: record.title,
      thumbnailUrl: record.thumbnailUrl,
    );

    _replaceEpisode(nextEpisode);
  }

  /// Verifica no banco se há um próximo episódio disponível e atualiza
  /// `_hasNextEpisode`. Usa o mesmo `getNextEpisode` do auto-play, mas
  /// sem side effects (não toca nada).
  ///
  /// Para fluxos não-PauloFlix (filmes, AnimeFire), sempre marca `false`.
  Future<void> _refreshNextEpisodeAvailability() async {
    if (_disposed) return;
    if (_currentSeasonId == null || _progressRepo == null) {
      if (mounted) setState(() => _hasNextEpisode = false);
      return;
    }
    try {
      final next = await _progressRepo!.getNextEpisode(
        seasonId: _currentSeasonId!,
        episodeNumber: _currentEpisodeNum,
      );
      if (mounted) setState(() => _hasNextEpisode = next != null);
    } catch (e, st) {
      _log.warning('Error checking next episode availability', e, st);
      if (mounted) setState(() => _hasNextEpisode = false);
    }
  }

  /// Sai do player voltando para a tela anterior (home/detail/lista de
  /// episódios). Comportamento de mercado Netflix/YouTube TV: o back do
  /// controle remoto **não fecha o app** — volta para a home do app, onde
  /// o usuário pode escolher outro anime ou "sair" via Home do launcher.
  ///
  /// Diferentemente da versão anterior que fazia `Navigator.pop` antes do
  /// save completar (`unawaited` + pop imediato), agora aguarda o save
  /// terminar ANTES de fazer o pop. Isso elimina a race condition onde o
  /// `GoRouterRouteRefreshMixin` (ou stream reativo) lia o progresso
  /// antigo do DB porque o save ainda não havia terminado.
  ///
  /// O `_exitPlayer` é `void` (assinatura `VoidCallback` exigida pelos
  /// controles), então delegamos a operação async para `_saveAndPop`.
  ///
  /// Se o player foi aberto como rota raiz (sem pai no Navigator), cai
  /// para `SystemNavigator.pop()` na TV (fecha app). Em mobile isso é
  /// improvável porque o player sempre é empilhado sobre uma rota.
  void _exitPlayer() {
    _progressSavedOnExit = true;
    final lastPosition = _player.state.position;
    final lastDuration = _player.state.duration;
    if (lastPosition.inSeconds > 0) {
      unawaited(_saveAndPop(lastPosition, lastDuration));
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  /// Salva o progresso final e, em seguida, faz o pop da rota.
  ///
  /// Separado de `_exitPlayer` por que este é `void` (assinatura
  /// `VoidCallback`), enquanto `_saveAndPop` pode ser `async` e
  /// aguardar o save antes de navegar.
  Future<void> _saveAndPop(Duration position, Duration duration) async {
    await _saveFinalProgress(position, duration);
    // `_progressSavedOnExit` já foi setado em `_exitPlayer`, então
    // `dispose()` não tentará salvar novamente.
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Video(
            controller: _videoController,
            controls: (state) {
              final externalSubs = _currentEpisode.subtitleTracks
                  .where((s) => s.url != null)
                  .toList();
              return ModernVideoPlayerControls(
                player: state.widget.controller.player,
                title: _displayLabel,
                animeTitle: widget.isMovie ? null : widget.animeTitle,
                onBack: _exitPlayer,
                onNextEpisode: _hasNextEpisode ? _onNextEpisodePressed : null,
                skipLabel: showSkipButton ? skipButtonLabel : null,
                onSkip: showSkipButton ? skipIntroOutro : null,
                onControlsVisible: () {
                  if (mounted) maybeReshowSkipButton();
                },
                onRetry: _initializeVideoPlayer,
                onPlayerError: _stopProgressServices,
                onClose: _exitPlayer,
                externalSubtitleTracks: externalSubs.isNotEmpty
                    ? externalSubs
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
