import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

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
/// │ [back]   título do episódio        [⏭ próximo] │  ← top bar + next
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

  /// Callback do botão "voltar" (sai do player).
  final VoidCallback onBack;

  /// Callback para próximo episódio. `null` = sem botão.
  final VoidCallback? onNextEpisode;

  /// Callback opcional para o botão "skip" (AniSkip intro/outro).
  /// Se `null`, o botão não aparece.
  final String? skipLabel;
  final VoidCallback? onSkip;

  /// Callback para tentar novamente após erro.
  final VoidCallback? onRetry;

  /// Callback para fechar o player.
  final VoidCallback? onClose;

  /// Auto-hide customizado (sobrescreve o padrão 3s/5s).
  final Duration? autoHideDuration;

  const ModernVideoPlayerControls({
    super.key,
    required this.player,
    required this.title,
    required this.onBack,
    this.onNextEpisode,
    this.skipLabel,
    this.onSkip,
    this.onRetry,
    this.onClose,
    this.autoHideDuration,
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
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // ─── State mirrors (refletem o Player para rebuild) ──────────────
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100.0;

  // ─── UI state (loading/error/playing) ──────────────────────────
  _PlayerUIState _uiState = _PlayerUIState.loading;
  String? _errorMessage;

  // Quanto do vídeo já está em buffer (0..1). Vem de
  // `Player.stream.bufferingPercentage` (0..100 → divide por 100).
  // Usado pela _SeekBar para mostrar a faixa cinza-claro ANTES da
  // cabeça de play — convenção YouTube/VLC.
  double _bufferFraction = 0.0;

  // ─── Subscriptions ──────────────────────────────────────────────
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<double>? _bufferPctSub;
  StreamSubscription<String>? _errorStreamSub;
  StreamSubscription<bool>? _bufferingSub;

  // ─── Seek interaction ────────────────────────────────────────────
  bool _isSeeking = false;
  double? _seekPreviewValue; // 0..1 durante o arraste

  // ─── TV detection (assíncrono) ──────────────────────────────────
  bool _isTVDevice = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    if (_isVisible) _fadeController.value = 1.0;

    _subscribeToPlayer();
    _detectTVDevice();
    _showAndScheduleAutoHide();
  }

  @override
  void didUpdateWidget(covariant ModernVideoPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o player trocou (rebind), re-assina os streams.
    if (oldWidget.player != widget.player) {
      _unsubscribeFromPlayer();
      _subscribeToPlayer();
    }
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _fadeController.dispose();
    _unsubscribeFromPlayer();
    super.dispose();
  }

  // ─── Player subscriptions ───────────────────────────────────────

  void _subscribeToPlayer() {
    final p = widget.player;
    // playing
    _playingSub = p.stream.playing.listen((v) {
      if (mounted) {
        setState(() {
          _isPlaying = v;
          if (v && _uiState == _PlayerUIState.loading) {
            _uiState = _PlayerUIState.playing;
          }
        });
      }
    });
    // error
    // ignore: cancel_subscriptions
    _errorStreamSub = p.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        debugPrint('[ModernVideoPlayerControls] Player error: $error');
        setState(() {
          _uiState = _PlayerUIState.error;
          _errorMessage = error;
        });
      }
    });
    // buffering
    _bufferingSub = p.stream.buffering.listen((buffering) {
      if (mounted && _uiState != _PlayerUIState.error) {
        // Só mostra loading se o player ainda não começou a tocar
        // (útil para o loading inicial).
        if (buffering && !_isPlaying && _position == Duration.zero) {
          setState(() => _uiState = _PlayerUIState.loading);
        } else if (!buffering && _uiState == _PlayerUIState.loading) {
          setState(() => _uiState = _PlayerUIState.playing);
        }
      }
    });
    // position
    _positionSub = p.stream.position.listen((v) {
      if (mounted && !_isSeeking) setState(() => _position = v);
    });
    // duration
    _durationSub = p.stream.duration.listen((v) {
      if (mounted) setState(() => _duration = v);
    });
    // volume
    _volumeSub = p.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    });
    // completed → reseta posição
    _completedSub = p.stream.completed.listen((v) {
      if (mounted && v) {
        setState(() => _isPlaying = false);
      }
    });
    // buffer percentage (0..100) → normalizado 0..1
    _bufferPctSub = p.stream.bufferingPercentage.listen((pct) {
      log('bufferingPercentage: $pct%');
      if (mounted) {
        setState(() => _bufferFraction = (pct / 100.0).clamp(0.0, 1.0));
      }
    });
    // Estado inicial.
    _isPlaying = p.state.playing;
    _position = p.state.position;
    _duration = p.state.duration;
    _volume = p.state.volume;
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
    final isTV = await TVDetector.isTV;
    if (!mounted) return;
    setState(() => _isTVDevice = isTV);
  }

  // ─── Auto-hide ───────────────────────────────────────────────────

  Duration get _autoHide {
    if (widget.autoHideDuration != null) return widget.autoHideDuration!;
    return _isTVDevice ? _kTVAutoHide : _kMobileAutoHide;
  }

  void _showAndScheduleAutoHide() {
    if (!mounted) return;
    _autoHideTimer?.cancel();
    if (!_isVisible) {
      setState(() => _isVisible = true);
    }
    _fadeController.forward();
    _autoHideTimer = Timer(_autoHide, _hide);
  }

  void _hide() {
    if (!mounted) return;
    // Em mobile, alguns segundos extras durante seek/hover ajudam UX.
    setState(() => _isVisible = false);
    _fadeController.reverse();
  }

  // ─── Action handlers ────────────────────────────────────────────

  void _togglePlay() {
    widget.player.playOrPause();
    // Mostra controles ao acionar (e re-agenda o auto-hide).
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

  void _changeVolume(double delta) {
    final newVol = (_volume + delta).clamp(0.0, 100.0);
    widget.player.setVolume(newVol);
    _showAndScheduleAutoHide();
  }

  void _goToNext() {
    widget.onNextEpisode?.call();
    _showAndScheduleAutoHide();
  }

  void _retry() {
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

  // ─── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Determina qual overlay mostrar
    final showLoading = _uiState == _PlayerUIState.loading;
    final showError = _uiState == _PlayerUIState.error;
    final showControls = !showLoading && !showError;

    return MouseRegion(
      onHover: (_) => _showAndScheduleAutoHide(),
      child: Focus(
        onKeyEvent: (node, event) {
          log('ModernVideoPlayerControls: onKeyEvent: $event');
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          _showAndScheduleAutoHide();
          return KeyEventResult.ignored;
        },
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            // ─── Globais (todas as plataformas) ──────────────────────
            const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
                _togglePlay,
            // Setas left/right → seek (fallback: consumido por
            // FocusableWidget se um botão estiver focado)
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _seekBy(const Duration(seconds: -5)),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _seekBy(const Duration(seconds: 5)),
            // N → próximo episódio
            if (widget.onNextEpisode != null)
              const SingleActivator(LogicalKeyboardKey.keyN): _goToNext,
            // Desktop-only (TV usa D-pad para navegação de foco)
            if (!_isTVDevice) ...{
              const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
              const SingleActivator(LogicalKeyboardKey.keyK): _togglePlay,
              const SingleActivator(LogicalKeyboardKey.select): _togglePlay,
              const SingleActivator(LogicalKeyboardKey.enter): _togglePlay,
              const SingleActivator(LogicalKeyboardKey.keyJ): () =>
                  _seekBy(const Duration(seconds: -10)),
              const SingleActivator(LogicalKeyboardKey.keyL): () =>
                  _seekBy(const Duration(seconds: 10)),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _changeVolume(5),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _changeVolume(-5),
            },
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: showControls ? _togglePlay : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camada 1: controles normais (sempre presente, fade)
                if (showControls)
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return IgnorePointer(
                        ignoring: !_isVisible,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildLayout(),
                  ),
                // Camada 2: loading overlay
                if (showLoading) _buildLoadingOverlay(),
                // Camada 3: error overlay
                if (showError) _buildErrorOverlay(),
              ],
            ),
          ),
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
            if (widget.title != null) _buildTopBar(),
            const Spacer(),
            _buildCenterControls(),
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
              child: Text(
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
            ),
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
          _PlayPauseButton(
            isPlaying: _isPlaying,
            onPressed: _togglePlay,
            autoFocus: _isTVDevice,
          ),
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
            _SeekBar(
              position: _isSeeking ? _previewPosition() : _position,
              duration: _duration,
              bufferFraction: _bufferFraction,
              onSeek: _seekTo,
              onSeekStart: () {
                setState(() => _isSeeking = true);
                _showAndScheduleAutoHide();
              },
              onSeekEnd: () {
                setState(() => _isSeeking = false);
                _showAndScheduleAutoHide();
              },
            ),
            const SizedBox(height: 6),
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
    return SizedBox.expand(
      child: Container(
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
      ),
    );
  }

  // ─── Error overlay ─────────────────────────────────────────────

  Widget _buildErrorOverlay() {
    final message = _errorMessage;
    return SizedBox.expand(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(24),
        child: Center(
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
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════

/// Botão de controle genérico. Envolve o `IconButton` em `FocusableWidget`
/// para que o D-pad alcance o alvo em TV (P4 da skill `flutter-tv-readiness`).
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
      borderRadius: 24,
      focusPadding: const EdgeInsets.all(8),
      focusScale: 1.1,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: 32,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.white,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão central de play/pause — maior que os outros (estilo VLC).
/// Envolto em [FocusableWidget] para que o D-pad alcance em TV (P4).
class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final bool autoFocus;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onPressed,
      autoFocus: autoFocus,
      borderRadius: 40,
      focusPadding: const EdgeInsets.all(4),
      focusScale: 1.08,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 48,
          color: Colors.white,
        ),
      ),
      // child: Container(
      //   width: 72,
      //   height: 72,
      //   decoration: BoxDecoration(
      //     color: AppColors.primary.withValues(alpha: 0.85),
      //     shape: BoxShape.circle,
      //     boxShadow: const [
      //       BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 1),
      //     ],
      //   ),
      //   child: Icon(
      //     isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      //     size: 48,
      //     color: Colors.white,
      //   ),
      // ),
    );
  }
}

/// Seek bar customizada com 3 faixas (estilo YouTube/VLC):
/// 1. Track inativo (cinza claro alpha 0.25) — fundo
/// 2. Track de buffer (cinza claro alpha 0.5) — quanto já carregou
/// 3. Track ativo (AppColors.primary) — posição atual de play
///
/// O [Slider] do Flutter não suporta buffer indicator nativamente,
/// então implementamos com [Stack] + 3 [FractionallySizedBox].
/// O [Slider] continua sendo usado para o thumb + D-pad handling.
class _SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final double bufferFraction;
  final ValueChanged<double> onSeek;
  final VoidCallback onSeekStart;
  final VoidCallback onSeekEnd;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.bufferFraction,
    required this.onSeek,
    required this.onSeekStart,
    required this.onSeekEnd,
  });

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds.toDouble();
    final value = max > 0
        ? (position.inMilliseconds / max).clamp(0.0, 1.0)
        : 0.0;
    // Garante que a barra de buffer nunca fica MENOR que a posição
    // atual (pode acontecer se a posição avançar mais rápido que o
    // report de buffer no início do vídeo).
    final effectiveBuffer = bufferFraction.clamp(0.0, 1.0);
    final displayBuffer = effectiveBuffer < value ? value : effectiveBuffer;

    return SizedBox(
      height: 32, // altura suficiente para o thumb (8px) + padding
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Camada 1: track inativo (fundo)
          // Ocupa toda a largura.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Camada 2: track de buffer (cinza médio)
          // Largura proporcional ao bufferFraction.
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: displayBuffer,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          // Camada 3: track ativo (primary) + Slider com thumb.
          // FractionallySizedBox abaixo do Slider para a parte
          // colorida da track ativa; o Slider por cima provê
          // hit-test, drag handle D-pad e thumb visual.
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          // Camada 4: Slider invisível só pra hit-test + D-pad + thumb.
          // O `Slider` padrão do Material já tem thumb circular
          // e suporte a D-pad (setas quando focado).
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 0, // track pintada pelos layers acima
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.25),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              // Garante que o Slider recebe foco D-pad (comportamento default).
            ),
            child: Slider(
              value: value,
              onChanged: onSeek,
              onChangeStart: (_) => onSeekStart(),
              onChangeEnd: (_) => onSeekEnd(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão "Pular intro" / "Pular abertura" (AniSkip).
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
