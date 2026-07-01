import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import '../../../domain/models/episode.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/focusable_widget.dart';

/// Estados internos do player UI.
enum _PlayerUIState { loading, playing, error }

/// Overlay de controle customizado para o media_kit.
///
/// Composição (top → bottom):
/// ```
/// ┌─────────────────────────────────────────────────┐
/// │ [back]   título do episódio     [⚙️] [⏭ próximo]│  ← top bar + next
/// ├─────────────────────────────────────────────────┤
/// │                                                 │
/// │               [▶⏸  play/pause]                   │  ← center (só play)
/// │                                                 │
/// ├─────────────────────────────────────────────────┤
/// │ [01:23]  ─────●───────────────  [24:00]   [Vol] │  ← bottom bar + seek
/// └─────────────────────────────────────────────────┘
/// ```
///
/// Comportamento:
/// - Auto-hide: 3s mobile, 5s TV.
/// - Tap = toggle play/pause.
/// - Foco D-pad completo: cada botão tem [FocusableWidget].
/// - Loading/error: gerenciado internamente via streams do Player.
/// - Desktop (não-TV): space/enter/select fazem play/pause;
///   setas up/down volume, J/L seek 10s.
/// - TV/D-pad: left/right seek (se nada focado); select/enter
///   ativa botão focado; setas navegam foco.
class ModernVideoPlayerControls extends StatefulWidget {
  /// Instância do `Player` do media_kit. Obrigatório.
  final Player player;

  /// Título exibido na top bar. `null` = oculta a top bar.
  final String? title;
  final String? animeTitle;

  /// Callback do botão "voltar" (sai do player).
  final VoidCallback onBack;

  /// Callback para próximo episódio. `null` = sem botão.
  final VoidCallback? onNextEpisode;

  /// Callback opcional para o botão "skip" (TheIntroDB intro/outro).
  /// Se `null`, o botão não aparece.
  final String? skipLabel;
  final VoidCallback? onSkip;

  /// Callback para tentar novamente após erro.
  final VoidCallback? onRetry;

  /// Callback disparado quando um erro de streaming não-ignorável é
  /// detectado. Usado pelo screen state para parar os timers de
  /// progresso (MovieProgressService / EpisodeProgressService)
  /// antes que `player.state.position` zere e sobrescreva o
  /// progresso salvo.
  final VoidCallback? onPlayerError;

  /// Callback para fechar o player.
  final VoidCallback? onClose;

  /// Auto-hide customizado (sobrescreve o padrão 3s/5s).
  final Duration? autoHideDuration;

  /// Legendas externas (.srt) do episódio atual. Passado pela screen
  /// para que o seletor de tracks possa listá-las como opções.
  final List<EpisodeSubtitleTrack>? externalSubtitleTracks;

  const ModernVideoPlayerControls({
    super.key,
    required this.player,
    required this.title,
    required this.animeTitle,
    required this.onBack,
    this.onNextEpisode,
    this.skipLabel,
    this.onSkip,
    this.onRetry,
    this.onPlayerError,
    this.onClose,
    this.autoHideDuration,
    this.externalSubtitleTracks,
  });

  @override
  State<ModernVideoPlayerControls> createState() =>
      _ModernVideoPlayerControlsState();
}

class _ModernVideoPlayerControlsState extends State<ModernVideoPlayerControls>
    with SingleTickerProviderStateMixin {
  static const Duration _kMobileAutoHide = Duration(seconds: 3);
  static const Duration _kTVAutoHide = Duration(seconds: 5);

  // ─── Visibility ──────────────────────────────────────────────────
  bool _isVisible = true;
  Timer? _autoHideTimer;

  // ─── State mirrors (refletem o Player para rebuild) ──────────────
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // ─── UI state (loading/error/playing) ──────────────────────────
  _PlayerUIState _uiState = _PlayerUIState.loading;
  String? _errorMessage;

  Duration _buffer = Duration.zero;

  // ─── Subscriptions ──────────────────────────────────────────────
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Duration>? _bufferPctSub;
  StreamSubscription<String>? _errorStreamSub;
  StreamSubscription<bool>? _bufferingSub;

  // ─── Seek interaction ────────────────────────────────────────────
  bool _isSeeking = false;
  double? _seekPreviewValue;

  // ─── Mid-playback buffer recovery ──────────────────────────────
  /// `true` quando o buffer acabou durante o playback e estamos
  /// aguardando o buffer encher novamente. Enquanto `true`:
  /// - O player fica pausado (evita freezing a cada 1s)
  /// - O overlay de loading aparece
  /// - O toggle play/pause é bloqueado
  /// - O buffer é monitorado via `_bufferPctSub`
  /// - Um timer de grace period de 20s é iniciado; se expirar sem
  ///   recuperação, o erro é mostrado.
  bool _waitingForBuffer = false;

  /// Timer de grace period para recuperação de buffer.
  /// Iniciado quando o buffer acaba durante playback. Se o buffer
  /// não recuperar dentro de 20s, o overlay de erro é exibido.
  /// Cancelado se o buffer recuperar antes do timeout.
  Timer? _bufferRecoveryTimer;

  /// Duração do grace period para recuperação de buffer.
  /// Tempo suficiente para a maioria dos hiccups de rede (roteador
  /// reiniciar, queda de sinal WiFi, etc.), sem ser frustrante para
  /// o usuário.
  static const Duration _kBufferRecoveryTimeout = Duration(seconds: 20);

  // ─── TV detection (assíncrono) ──────────────────────────────────
  bool _isTVDevice = false;

  bool _hardwareKeyboardHandlerInstalled = false;

  final FocusNode focusNode = FocusNode(
    debugLabel: 'ModernVideoPlayerControls',
  );

  @override
  void initState() {
    super.initState();
    _subscribeToPlayer();
    _detectTVDevice();
    _showAndScheduleAutoHide();
    _installHardwareKeyboardHandler();
  }

  @override
  void didUpdateWidget(covariant ModernVideoPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _unsubscribeFromPlayer();
      _subscribeToPlayer();
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _bufferRecoveryTimer?.cancel();
    _unsubscribeFromPlayer();
    _uninstallHardwareKeyboardHandler();
    super.dispose();
  }

  void _installHardwareKeyboardHandler() {
    if (_hardwareKeyboardHandlerInstalled) return;
    _hardwareKeyboardHandlerInstalled = true;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  void _uninstallHardwareKeyboardHandler() {
    if (!_hardwareKeyboardHandlerInstalled) return;
    _hardwareKeyboardHandlerInstalled = false;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        if (!_isVisible) {
          _togglePlay();
        } else {
          _showAndScheduleAutoHide();
        }
        break;
      case LogicalKeyboardKey.arrowLeft:
        if (!_isVisible) {
          _seekBy(const Duration(seconds: -5));
        } else {
          _showAndScheduleAutoHide();
        }
        break;
      case LogicalKeyboardKey.arrowRight:
        if (!_isVisible) {
          _seekBy(const Duration(seconds: 5));
        } else {
          _showAndScheduleAutoHide();
        }
        break;
      case LogicalKeyboardKey.goBack:
        _hide();
        break;
      default:
        _showAndScheduleAutoHide();
        break;
    }

    return false;
  }

  // ─── Player subscriptions ───────────────────────────────────────

  void _subscribeToPlayer() {
    final p = widget.player;
    _playingSub = p.stream.playing.listen((v) {
      if (mounted) {
        setState(() {
          _isPlaying = v;
          // Só transiciona loading→playing se NÃO estivermos
          // aguardando buffer. O _checkBufferAndResume é quem
          // decide quando retomar após mid-playback buffer drain.
          if (v && _uiState == _PlayerUIState.loading && !_waitingForBuffer) {
            _uiState = _PlayerUIState.playing;
          }
        });
      }
    });
    _errorStreamSub = p.stream.error.listen((error) {
      // ── Erros de rede transientes (ignorar silenciosamente) ──
      // ffurl_read: erro de leitura FFmpeg (transiente).
      if (error.contains('tcp: ffurl_read returned') ||
          // Connection reset: servidor dropou conexão (transiente).
          error.contains('tcp: Connection reset by peer') ||
          // Error -138: MPV_ERROR_LOADING_FAILED — genérico FFmpeg.
          error.contains('Error number -138 occurred') ||
          // Operation timed out: timeout de socket (transiente).
          error.contains('tcp: Operation timed out') ||
          // No route to host: roteamento temporário (transiente).
          error.contains('No route to host') ||
          // Broken pipe: servidor fechou conexão (transiente).
          error.contains('Broken pipe') ||
          // HTTP 5xx: erro temporário de servidor.
          error.contains('HTTP error 5') ||
          // Connection timed out: sem resposta (pode ser transiente).
          error.contains('Connection timed out')) {
        debugPrint(
          '[ModernVideoPlayerControls] Ignoring transient network error: $error',
        );
        return;
      }

      if (mounted && error.isNotEmpty) {
        debugPrint('[ModernVideoPlayerControls] Player error: $error');

        if (_waitingForBuffer) {
          // Já estamos em modo de recuperação de buffer. O timer de
          // grace period (_bufferRecoveryTimer) vai decidir quando
          // mostrar o erro. Não sobrescrever o loading com error
          // overlay — a rede pode voltar.
          debugPrint(
            '[ModernVideoPlayerControls] ⏳ Deferring error — '
            'buffer recovery in progress',
          );
          return;
        }

        // Não está em recuperação: mostra erro imediatamente.
        _waitingForBuffer = false;
        widget.onPlayerError?.call();
        setState(() {
          _uiState = _PlayerUIState.error;
          _errorMessage = error;
        });
      }
    });
    _bufferingSub = p.stream.buffering.listen((buffering) {
      if (mounted && _uiState != _PlayerUIState.error) {
        if (buffering && _isPlaying) {
          // Mid-playback buffer drain: pausa o player, mostra
          // loading e inicia timer de grace period.
          // Se o buffer recuperar antes do timeout, retoma
          // automaticamente. Se não, mostra erro.
          debugPrint('[PlayerControls] ⏸ Buffer drained during playback');
          _waitingForBuffer = true;
          _startBufferRecoveryTimer();
          widget.player.pause();
          setState(() {
            _uiState = _PlayerUIState.loading;
            _isPlaying = false;
          });
        } else if (!buffering && _waitingForBuffer) {
          // Buffering ended while waiting — check if buffer is sufficient
          _checkBufferAndResume();
        } else if (buffering && !_isPlaying && _position == Duration.zero) {
          // Initial loading (position=0)
          setState(() => _uiState = _PlayerUIState.loading);
        } else if (!buffering && _uiState == _PlayerUIState.loading && !_waitingForBuffer) {
          // Initial loading finished
          setState(() => _uiState = _PlayerUIState.playing);
        }
      }
    });
    _positionSub = p.stream.position.listen((v) {
      if (mounted && !_isSeeking) setState(() => _position = v);
    });
    _durationSub = p.stream.duration.listen((v) {
      if (mounted) setState(() => _duration = v);
    });
    _completedSub = p.stream.completed.listen((v) {
      if (mounted && v) {
        _waitingForBuffer = false;
        setState(() => _isPlaying = false);
      }
    });
    _bufferPctSub = p.stream.buffer.listen((buffer) {
      if (mounted) {
        _buffer = buffer;
        if (_waitingForBuffer) {
          // Durante buffer recovery a seek bar não fica visível
          // (só o loading overlay). Pulamos o setState para evitar
          // rebuilds desnecessários (~10-20/s).
          _checkBufferAndResume();
        } else {
          setState(() {});
        }
      }
    });
    _isPlaying = p.state.playing;
    _position = p.state.position;
    _duration = p.state.duration;
  }

  void _unsubscribeFromPlayer() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _volumeSub?.cancel();
    _completedSub?.cancel();
    _bufferPctSub?.cancel();
    _errorStreamSub?.cancel();
    _bufferingSub?.cancel();
  }

  Future<void> _detectTVDevice() async {
    _isTVDevice = await TVDetector.isTV;
    if (!mounted) return;
    setState(() {});
  }

  Duration get _autoHide {
    if (widget.autoHideDuration != null) return widget.autoHideDuration!;
    return _isTVDevice ? _kTVAutoHide : _kMobileAutoHide;
  }

  void _showAndScheduleAutoHide() {
    if (!mounted) return;
    _autoHideTimer?.cancel();
    if (!_isVisible) {
      setState(() => _isVisible = true);
      focusNode.requestFocus();
    }
    _autoHideTimer = Timer(_autoHide, _hide);
  }

  void _hide() {
    if (!mounted) return;
    setState(() => _isVisible = false);
  }

  // ─── Mid-playback buffer recovery ──────────────────────────────

  /// Inicia o timer de grace period para recuperação de buffer.
  /// Se o timeout expirar sem que o buffer se recupere, mostra
  /// o overlay de erro.
  void _startBufferRecoveryTimer() {
    _bufferRecoveryTimer?.cancel();
    _bufferRecoveryTimer = Timer(_kBufferRecoveryTimeout, () {
      if (!mounted) return;
      debugPrint(
        '[PlayerControls] ⏰ Buffer recovery timeout '
        '(${_kBufferRecoveryTimeout.inSeconds}s) — showing error',
      );
      _waitingForBuffer = false;
      _bufferRecoveryTimer = null;
      widget.onPlayerError?.call();
      setState(() {
        _uiState = _PlayerUIState.error;
        _errorMessage = 'Sem conexão com o servidor';
      });
    });
  }

  /// Cancela o timer de grace period (buffer recuperou ou foi
  /// cancelado manualmente via retry/dispose).
  void _cancelBufferRecoveryTimer() {
    _bufferRecoveryTimer?.cancel();
    _bufferRecoveryTimer = null;
  }

  /// Verifica se o buffer está suficiente e, em caso positivo,
  /// cancela o timer de grace period, retoma o playback e esconde
  /// o loading.
  void _checkBufferAndResume() {
    if (!_waitingForBuffer) return;
    if (!isBufferSufficient(_buffer, _duration, _position)) return;

    debugPrint(
      '[PlayerControls] ▶ Buffer sufficient '
      '(${_buffer.inSeconds}s), resuming playback',
    );
    _cancelBufferRecoveryTimer();
    _waitingForBuffer = false;
    widget.player.play();
    setState(() {
      _uiState = _PlayerUIState.playing;
      _isPlaying = true;
    });
    _showAndScheduleAutoHide();
  }

  void _togglePlay() {
    if (_waitingForBuffer) return; // bloqueado durante recuperação de buffer
    widget.player.playOrPause();
    _showAndScheduleAutoHide();
  }

  void _seekBy(Duration delta) {
    final newPos = _position + delta;
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _duration ? _duration : newPos);
    widget.player.seek(clamped);
    _showAndScheduleAutoHide();
  }

  void _seekTo(double normalized) {
    if (_duration == Duration.zero) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * normalized).round(),
    );
    widget.player.seek(target);
  }

  void _goToNext() {
    widget.onNextEpisode?.call();
    _showAndScheduleAutoHide();
  }

  void _retry() {
    _waitingForBuffer = false;
    _cancelBufferRecoveryTimer();
    setState(() {
      _uiState = _PlayerUIState.loading;
      _errorMessage = null;
    });
    widget.onRetry?.call();
    _showAndScheduleAutoHide();
  }

  void _close() {
    widget.onClose?.call();
  }

  // ─── Track selector ────────────────────────────────────────────

  /// Verifica se há tracks disponíveis para o settings icon aparecer.
  bool get _hasTracksToSelect {
    final tracks = widget.player.state.tracks;
    return tracks.video.length > 1 ||
        tracks.audio.length > 1 ||
        tracks.subtitle.isNotEmpty ||
        (widget.externalSubtitleTracks?.isNotEmpty == true);
  }

  Widget _buildSettingsButton() {
    if (!_hasTracksToSelect) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: _ControlButton(
        icon: Icons.settings_rounded,
        tooltip: 'Configurações de áudio/vídeo',
        onPressed: _showTrackSelector,
        iconSize: 24,
      ),
    );
  }

  void _showTrackSelector() {
    _autoHideTimer?.cancel();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final tracks = widget.player.state.tracks;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Configurações de Faixas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (tracks.video.length > 1)
                          _TrackSection(
                            icon: Icons.videocam_rounded,
                            title: 'Vídeo',
                            tracks: tracks.video
                                .map(
                                  (t) => _TrackItemData(
                                    id: t.id,
                                    label: t.title ?? _formatVideoRes(t),
                                    subtitle: _formatVideoSubtitle(t),
                                    isActive:
                                        t.id ==
                                        widget.player.state.track.video.id,
                                  ),
                                )
                                .toList(),
                            onSelect: (index) {
                              if (index < tracks.video.length) {
                                widget.player.setVideoTrack(
                                  tracks.video[index],
                                );
                                Navigator.pop(sheetContext);
                              }
                            },
                          ),
                        if (tracks.audio.length > 1)
                          _TrackSection(
                            icon: Icons.audiotrack_rounded,
                            title: 'Áudio',
                            tracks: tracks.audio
                                .map(
                                  (t) => _TrackItemData(
                                    id: t.id,
                                    label:
                                        t.title ??
                                        t.language ??
                                        'Track ${tracks.audio.indexOf(t) + 1}',
                                    subtitle: t.codec != null
                                        ? (t.language != null
                                              ? '${t.codec} • ${t.language}'
                                              : t.codec!)
                                        : t.language,
                                    isActive:
                                        t.id ==
                                        widget.player.state.track.audio.id,
                                    badge:
                                        t.language != null &&
                                            (t.language!.toLowerCase() ==
                                                    'por' ||
                                                t.language!.toLowerCase() ==
                                                    'pt-br')
                                        ? 'PT-BR'
                                        : null,
                                  ),
                                )
                                .toList(),
                            onSelect: (index) {
                              if (index < tracks.audio.length) {
                                widget.player.setAudioTrack(
                                  tracks.audio[index],
                                );
                                Navigator.pop(sheetContext);
                              }
                            },
                          ),
                        _buildSubtitleSection(sheetContext),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) _showAndScheduleAutoHide();
    });
  }

  Widget _buildSubtitleSection(BuildContext sheetContext) {
    final l10n = AppLocalizations.of(context);
    final track = widget.player.state.track;
    final currentSubId = track.subtitle.id;

    final options = <_TrackItemData>[];

    // Auto
    options.add(
      _TrackItemData(
        id: 'auto',
        label: l10n.auto,
        subtitle: l10n.autoDescription,
        isActive: currentSubId == 'auto',
        iconData: Icons.auto_awesome_rounded,
      ),
    );

    // Desligado
    options.add(
      _TrackItemData(
        id: 'no',
        label: l10n.subtitlesOff,
        subtitle: l10n.subtitlesOffDescription,
        isActive: currentSubId == 'no',
        iconData: Icons.subtitles_off_rounded,
      ),
    );

    // Embutidas no MKV (lidas do player.state.tracks)
    final embeddedFromPlayer = widget.player.state.tracks.subtitle;
    for (final st in embeddedFromPlayer) {
      options.add(
        _TrackItemData(
          id: st.id,
          label: st.title ?? st.language ?? 'Track ${st.id}',
          subtitle: st.language ?? l10n.unknownLanguage,
          isActive: currentSubId == st.id,
          iconData: Icons.movie_outlined,
        ),
      );
    }

    // Externas (.srt) passadas pela screen
    final externalSubs = widget.externalSubtitleTracks;
    if (externalSubs != null) {
      for (final ext in externalSubs) {
        options.add(
          _TrackItemData(
            id: ext.url ?? ext.displayName,
            label: ext.displayName,
            subtitle: '${ext.language} • .srt',
            isActive: currentSubId == ext.url,
            iconData: Icons.subtitles_rounded,
          ),
        );
      }
    }

    return _TrackSection(
      icon: Icons.closed_caption_rounded,
      title: 'Legenda',
      tracks: options,
      onSelect: (index) async {
        if (index >= options.length) return;
        final opt = options[index];
        try {
          switch (opt.id) {
            case 'auto':
              await widget.player.setSubtitleTrack(SubtitleTrack.auto());
            case 'no':
              await widget.player.setSubtitleTrack(SubtitleTrack.no());
            default:
              // Procura nos tracks embutidos do player
              SubtitleTrack? playerTrack;
              for (final st in embeddedFromPlayer) {
                if (st.id == opt.id) {
                  playerTrack = st;
                  break;
                }
              }
              if (playerTrack != null) {
                await widget.player.setSubtitleTrack(playerTrack);
              } else {
                // Se for externa, carrega via URI
                final ext = widget.externalSubtitleTracks?.firstWhere(
                  (e) => e.url == opt.id || e.displayName == opt.id,
                  orElse: () => widget.externalSubtitleTracks!.first,
                );
                if (ext != null && ext.url != null) {
                  await widget.player.setSubtitleTrack(
                    SubtitleTrack.uri(
                      ext.url!,
                      title: ext.displayName,
                      language: ext.language,
                    ),
                  );
                }
              }
          }
        } catch (e) {
          debugPrint('[PlayerControls] Failed to set subtitle track: $e');
        }
        if (sheetContext.mounted) Navigator.pop(sheetContext);
      },
    );
  }

  /// Formata a resolução do VideoTrack: "1920x1080" ou fallback para "Track".
  String _formatVideoRes(VideoTrack t) {
    final w = t.w ?? 0;
    final h = t.h ?? 0;
    if (w > 0 && h > 0) return '${w}x$h';
    return 'Track';
  }

  /// Formata o subtítulo do VideoTrack: "codec • language".
  String _formatVideoSubtitle(VideoTrack t) {
    final parts = <String>[];
    final w = t.w ?? 0;
    final h = t.h ?? 0;
    if (w > 0 && h > 0) {
      parts.add('${w}x$h');
    }
    if (t.codec != null && t.codec!.isNotEmpty) {
      parts.add(t.codec!);
    }
    if (t.language != null && t.language!.isNotEmpty) {
      parts.add(t.language!);
    }
    return parts.isNotEmpty ? parts.join(' • ') : '';
  }

  // ─── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showLoading = _uiState == _PlayerUIState.loading;
    final showError = _uiState == _PlayerUIState.error;
    final showControls = !showLoading && !showError;

    return MouseRegion(
      onHover: (_) => _showAndScheduleAutoHide(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: showControls ? _togglePlay : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!showLoading) _buildLayout(),
            if (showLoading) _buildLoadingOverlay(),
            if (showError) _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLayout() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: FocusTraversalGroup(
        child: Column(
          children: [
            if (_isVisible) _buildTopBar(),
            const Spacer(),
            if (_isVisible) _buildCenterControls(),
            const Spacer(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            _ControlButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Voltar',
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.animeTitle != null) ...[
                    Text(
                      widget.animeTitle!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (widget.title != null) ...[
                    Text(
                      widget.title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _buildSettingsButton(),
            if (widget.onNextEpisode != null) ...[
              const SizedBox(width: 12),
              _ControlButton(
                icon: Icons.skip_next_rounded,
                tooltip: 'Próximo episódio',
                onPressed: _goToNext,
                iconSize: 28,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PlayPauseButton(isPlaying: _isPlaying, onPressed: _togglePlay),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.skipLabel != null && widget.onSkip != null) ...[
              Align(
                alignment: Alignment.centerRight,
                child: _SkipIntroButton(
                  label: widget.skipLabel!,
                  onPressed: widget.onSkip!,
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            if (_isVisible)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                  Expanded(
                    child: _SeekBar(
                      position: _isSeeking ? _previewPosition() : _position,
                      duration: _duration,
                      buffer: _buffer,
                      onSeek: _seekTo,
                      togglePlay: _togglePlay,
                      onSeekStart: () {
                        setState(() => _isSeeking = true);
                        _showAndScheduleAutoHide();
                      },
                      onSeekEnd: () {
                        setState(() => _isSeeking = false);
                        _showAndScheduleAutoHide();
                      },
                      onSeekBy: (seconds) =>
                          _seekBy(Duration(seconds: seconds)),
                    ),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Duration _previewPosition() {
    if (_seekPreviewValue == null || _duration == Duration.zero) {
      return _position;
    }
    return Duration(
      milliseconds: (_duration.inMilliseconds * _seekPreviewValue!).round(),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  // ─── Loading overlay ───────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    final isBuffering = _waitingForBuffer;
    final l10n = AppLocalizations.of(context);
    return Center(
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
            isBuffering
                ? l10n.recoveringConnection
                : l10n.loadingStream,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isBuffering
                ? l10n.reconnectingServer
                : l10n.preparingServer,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Error overlay ─────────────────────────────────────────────

  Widget _buildErrorOverlay() {
    final message = _errorMessage;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: FocusTraversalGroup(
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
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
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
                message ?? AppLocalizations.of(context).error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FocusableWidget(
                    onSelect: _retry,
                    autoFocus: _isTVDevice,
                    borderRadius: 16,
                    child: ElevatedButton.icon(
                      onPressed: _retry,
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
                  ),
                  const SizedBox(width: 12),
                  FocusableWidget(
                    onSelect: _close,
                    borderRadius: 16,
                    child: ElevatedButton.icon(
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                      label: Text(AppLocalizations.of(context).close),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Buffer recovery utilities (público para testes)
// ═══════════════════════════════════════════════════════════════════

/// Verifica se o buffer atual é suficiente para retomar o playback.
///
/// Usa o **restante** do vídeo (`duration - position`) como base:
/// - Alvo: 50% do restante, clamp entre 30s e 120s
/// - Se o restante for menor que o alvo, usa o restante
///   (evita exigir mais buffer do que o possível).
///
/// Esta função é usada internamente por
/// [_ModernVideoPlayerControlsState._checkBufferAndResume] e está
/// exposta como pública para viabilizar testes unitários.
///
/// Exemplos (restante → alvo):
/// - Restante 30s → 30s (50% = 15s < min 30s, clamp sobe para 30s,
///   e 30s == restante → buffer completo do trecho final)
/// - Restante 5min → 30s (50% = 2,5min, clamp mínimo de 30s)
/// - Restante 60min → 120s (50% = 30min, cap máximo de 120s)
bool isBufferSufficient(
  Duration buffered,
  Duration duration,
  Duration position,
) {
  if (buffered <= Duration.zero) return false;
  final remaining = duration - position;
  if (remaining <= Duration.zero) {
    // Vídeo já acabou ou sem duração: queremos ao menos 5s para
    // garantir que o último frame está disponível.
    return buffered >= const Duration(seconds: 5);
  }
  // 50% do restante, clamp entre 30s e 120s
  final halfRemaining = remaining ~/ 2;
  final target = halfRemaining < const Duration(seconds: 30)
      ? const Duration(seconds: 30)
      : halfRemaining;
  final capped = target > const Duration(seconds: 120)
      ? const Duration(seconds: 120)
      : target;
  // Não exigir mais buffer do que o restante disponível
  final effective = capped > remaining ? remaining : capped;
  return buffered >= effective;
}

// ═══════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════

/// Botão de controle genérico.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onPressed,
      borderRadius: 32,
      child: Icon(
        icon,
        size: iconSize,
        color: Colors.white,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
      ),
    );
  }
}

/// Botão central de play/pause.
class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseButton({required this.isPlaying, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      autoFocus: true,
      onSelect: onPressed,
      borderRadius: 32,
      child: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 48,
        color: Colors.white,
      ),
    );
  }
}

/// Seek bar customizada com 3 faixas (estilo YouTube/VLC).
class _SeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final ValueChanged<double> onSeek;
  final VoidCallback togglePlay;
  final VoidCallback onSeekStart;
  final VoidCallback onSeekEnd;
  final ValueChanged<int> onSeekBy;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.buffer,
    required this.onSeek,
    required this.onSeekStart,
    required this.onSeekEnd,
    required this.onSeekBy,
    required this.togglePlay,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  late final FocusNode _focusNode = FocusNode(debugLabel: 'SeekBar');
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    if (!mounted) return;
    setState(() => _isFocused = hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.toDouble();
    final value = max > 0
        ? (widget.position.inMilliseconds / max).clamp(0.0, 1.0)
        : 0.0;
    final effectiveBuffer = (widget.buffer.inMilliseconds / max).clamp(
      0.0,
      1.0,
    );
    final displayBuffer = effectiveBuffer < value ? value : effectiveBuffer;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.space:
          case LogicalKeyboardKey.select:
          case LogicalKeyboardKey.enter:
            widget.togglePlay();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowLeft:
            widget.onSeekBy(-5);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.arrowRight:
            widget.onSeekBy(5);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: ExcludeFocus(
        child: Slider(
          activeColor: _isFocused ? AppColors.primary : Colors.white,
          inactiveColor: Colors.grey.withValues(alpha: 0.25),
          thumbColor: _isFocused ? AppColors.primary : Colors.white,
          secondaryActiveColor: Colors.white.withValues(alpha: 0.5),
          value: value,
          secondaryTrackValue: displayBuffer,
          onChanged: widget.onSeek,
          onChangeStart: (_) => widget.onSeekStart(),
          onChangeEnd: (_) => widget.onSeekEnd(),
          allowedInteraction: SliderInteraction.tapOnly,
        ),
      ),
    );
  }
}

/// Dados de uma opção de track no seletor.
class _TrackItemData {
  final String id;
  final String label;
  final String? subtitle;
  final bool isActive;
  final String? badge;
  final IconData? iconData;

  const _TrackItemData({
    required this.id,
    required this.label,
    this.subtitle,
    this.isActive = false,
    this.badge,
    this.iconData,
  });
}

/// Seção de tracks no bottom sheet (Vídeo / Áudio / Legenda).
class _TrackSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_TrackItemData> tracks;
  final ValueChanged<int> onSelect;

  const _TrackSection({
    required this.icon,
    required this.title,
    required this.tracks,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < tracks.length; i++)
          _TrackOption(data: tracks[i], onTap: () => onSelect(i)),
      ],
    );
  }
}

/// Opção individual de track no seletor.
class _TrackOption extends StatelessWidget {
  final _TrackItemData data;
  final VoidCallback onTap;

  const _TrackOption({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF00BCD4);
    final icon =
        data.iconData ??
        (data.isActive
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded);

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
              color: data.isActive ? activeColor : Colors.white60,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: data.isActive
                                ? Colors.white
                                : Colors.white70,
                            fontSize: 14,
                            fontWeight: data.isActive
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (data.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: activeColor.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            data.badge!,
                            style: const TextStyle(
                              color: activeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (data.subtitle != null && data.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (data.isActive)
              const Icon(
                Icons.check_circle_rounded,
                color: activeColor,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// Botão "Pular intro" / "Pular abertura" (TheIntroDB).
class _SkipIntroButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SkipIntroButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onPressed,
      borderRadius: 20,
      focusScale: 1.05,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fast_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
