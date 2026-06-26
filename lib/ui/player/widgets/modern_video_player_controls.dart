import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/themes/app_colors.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/focusable_widget.dart';

/// Overlay de controle customizado para o media_kit, estilo YouTube/VLC.
///
/// Composição (top → bottom):
/// ```
/// ┌────────────────────────────────────────────┐
/// │ [back]   [título do episódio]               │  ← top bar
/// ├────────────────────────────────────────────┤
/// │                                            │
/// │   [⏮]   [⏪ 10s]   [⏯ play]   [10s ⏩]   [⏭]│  ← center controls
/// │                                            │
/// ├────────────────────────────────────────────┤
/// │ [01:23]  [─────●──────────────]  [24:00]   │  ← bottom bar (seek)
/// └────────────────────────────────────────────┘
/// ```
///
/// Comportamento:
/// - Auto-hide: 3s em mobile, 5s em TV (Netflix/YouTube TV padrão).
/// - Re-mostra em qualquer tap/movimento de mouse/key dentro da área.
/// - Tap em área vazia (não em botão) = toggle play/pause.
/// - Foco D-pad completo: cada botão tem [FocusableWidget].
/// - TV (D-pad): setas funcionam como seek/volume via [CallbackShortcuts].
///
/// Por que sem Provider: o estado do overlay (isVisible, isPlaying,
/// position, duration) é puramente local ao widget. Não há razão para
/// expor para fora — outro widget que precisasse ouvir (mini-player,
/// watchlist) usa os streams nativos do `Player` diretamente.
class ModernVideoPlayerControls extends StatefulWidget {
  /// Instância do `Player` do media_kit. Obrigatório.
  final Player player;

  /// Título exibido na top bar. `null` = oculta a top bar.
  final String? title;

  /// Callback do botão "voltar" (sai do player).
  final VoidCallback onBack;

  /// Tem episódio anterior (mostra botão ⏮).
  final bool hasPreviousEpisode;

  /// Tem episódio seguinte (mostra botão ⏭).
  final bool hasNextEpisode;

  /// Callback para episódio anterior.
  final VoidCallback? onPreviousEpisode;

  /// Callback para próximo episódio.
  final VoidCallback? onNextEpisode;

  /// Callback opcional para o botão "skip" (AniSkip intro/outro).
  /// Se `null`, o botão não aparece.
  final String? skipLabel;
  final VoidCallback? onSkip;

  /// Auto-hide customizado (sobrescreve o padrão 3s/5s).
  final Duration? autoHideDuration;

  /// AutoFocus no primeiro botão focado. Padrão: `false` para não roubar
  /// o foco do D-pad antes do usuário agir.
  final bool autoFocusFirst;

  const ModernVideoPlayerControls({
    super.key,
    required this.player,
    required this.title,
    required this.onBack,
    this.hasPreviousEpisode = false,
    this.hasNextEpisode = false,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.skipLabel,
    this.onSkip,
    this.autoHideDuration,
    this.autoFocusFirst = false,
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

  // ─── Seek interaction ────────────────────────────────────────────
  bool _isSeeking = false;
  double? _seekPreviewValue; // 0..1 durante o arraste

  // ─── TV detection (assíncrono) ──────────────────────────────────
  bool? _isTVDevice;

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
      if (mounted) setState(() => _isPlaying = v);
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
    // completed → reseta posição (evita ficar parado no último frame)
    _completedSub = p.stream.completed.listen((v) {
      if (mounted && v) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
    // buffer percentage (0..100 do media_kit) → normalizado 0..1.
    // Cobre o caso "seek pra frente além do buffer" — usuário vê
    // o quanto já carregou antes de tentar pular.
    _bufferPctSub = p.stream.bufferingPercentage.listen((pct) {
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
  }

  Future<void> _detectTVDevice() async {
    final isTV = await TVDetector.isTV;
    if (!mounted) return;
    setState(() => _isTVDevice = isTV);
  }

  // ─── Auto-hide ───────────────────────────────────────────────────

  Duration get _autoHide {
    if (widget.autoHideDuration != null) return widget.autoHideDuration!;
    return _isTVDevice == true ? _kTVAutoHide : _kMobileAutoHide;
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

  void _goToPrevious() {
    widget.onPreviousEpisode?.call();
    _showAndScheduleAutoHide();
  }

  void _goToNext() {
    widget.onNextEpisode?.call();
    _showAndScheduleAutoHide();
  }

  // ─── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _showAndScheduleAutoHide(),
      // `Focus` com `onKeyEvent` captura QUALQUER tecla que chegue
      // ao subtree dos controles (mesmo as que vão ser tratadas pelo
      // `CallbackShortcuts` abaixo). Re-mostra o overlay + re-agenda
      // o auto-hide. Retornamos `KeyEventResult.ignored` para que
      // a propagação continue normalmente e os atalhos (J/K/L, setas,
      // N/P) funcionem como antes.
      //
      // Por que não `HardwareKeyboard.instance.addHandler` global:
      //   - P9 da skill `flutter-tv-readiness` — handler global
      //     intercepta teclas mesmo com foco em Dialog ou outro widget.
      //   - `Focus` é escopado ao subtree dos controles, sem leak
      //     nem conflito com o `_installHardwareKeyboardHandler`
      //     do `video_player_screen.dart` (que cuida só do ESC).
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          // Qualquer tecla: re-mostra o overlay. Não consome o evento
          // (ignored) — o CallbackShortcuts filho decide se trata.
          _showAndScheduleAutoHide();
          return KeyEventResult.ignored;
        },
        child: CallbackShortcuts(
          bindings: {
            // TV / desktop: atalhos que NÃO interferem com os botões focados.
            // Funcionam quando o foco está no subtree dos controles
            // (mas não em um botão específico — nesses casos, é consumido).
            const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
            const SingleActivator(LogicalKeyboardKey.keyK): _togglePlay,
            const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
                _togglePlay,
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _seekBy(const Duration(seconds: -5)),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _seekBy(const Duration(seconds: 5)),
            const SingleActivator(LogicalKeyboardKey.keyJ): () =>
                _seekBy(const Duration(seconds: -10)),
            const SingleActivator(LogicalKeyboardKey.keyL): () =>
                _seekBy(const Duration(seconds: 10)),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _changeVolume(5),
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _changeVolume(-5),
            // Mapeia N/P para episódio seguinte/anterior (convenção YouTube).
            if (widget.hasNextEpisode)
              const SingleActivator(LogicalKeyboardKey.keyN): _goToNext,
            if (widget.hasPreviousEpisode)
              const SingleActivator(LogicalKeyboardKey.keyP): _goToPrevious,
          },
          child: GestureDetector(
            // Tap em área vazia (não em botão) = toggle play/pause.
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return IgnorePointer(
                  ignoring: !_isVisible,
                  child: Opacity(opacity: _fadeAnimation.value, child: child),
                );
              },
              child: _buildLayout(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Column(
        children: [
          if (widget.title != null) _buildTopBar(),
          const Spacer(),
          _buildCenterControls(),
          const Spacer(),
          _buildBottomBar(),
        ],
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
              autoFocus: widget.autoFocusFirst,
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
            // Slot futuro: settings, subtitle picker, etc.
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    // Importante: TODOS os botões aqui são interativos e precisam de
    // FocusableWidget para que o D-pad alcance em TV (P4 da skill
    // `flutter-tv-readiness`). Sem isso, replay-10/forward-10/play
    // ficam invisíveis ao controle remoto.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (widget.hasPreviousEpisode)
            _ControlButton(
              icon: Icons.skip_previous_rounded,
              tooltip: 'Episódio anterior',
              onPressed: _goToPrevious,
              iconSize: 36,
            ),
          _Replay10Button(
            onPressed: () => _seekBy(const Duration(seconds: -10)),
          ),
          _PlayPauseButton(isPlaying: _isPlaying, onPressed: _togglePlay),
          _Forward10Button(
            onPressed: () => _seekBy(const Duration(seconds: 10)),
          ),
          if (widget.hasNextEpisode)
            _ControlButton(
              icon: Icons.skip_next_rounded,
              tooltip: 'Próximo episódio',
              onPressed: _goToNext,
              iconSize: 36,
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
                _VolumeButton(currentVolume: _volume, onChange: _changeVolume),
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
  final bool autoFocus;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 24,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onPressed,
      autoFocus: autoFocus,
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

/// Botão "voltar 10s" com FocusableWidget (P4 da skill TV-readiness).
class _Replay10Button extends StatelessWidget {
  final VoidCallback onPressed;

  const _Replay10Button({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onPressed,
      borderRadius: 24,
      focusPadding: const EdgeInsets.all(8),
      focusScale: 1.1,
      child: Tooltip(
        message: 'Voltar 10 segundos',
        child: InkResponse(
          onTap: onPressed,
          radius: 32,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.replay_10_rounded,
              size: 36,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão "avançar 10s" com FocusableWidget (P4 da skill TV-readiness).
class _Forward10Button extends StatelessWidget {
  final VoidCallback onPressed;

  const _Forward10Button({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onPressed,
      borderRadius: 24,
      focusPadding: const EdgeInsets.all(8),
      focusScale: 1.1,
      child: Tooltip(
        message: 'Avançar 10 segundos',
        child: InkResponse(
          onTap: onPressed,
          radius: 32,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.forward_10_rounded,
              size: 36,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
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

  const _PlayPauseButton({required this.isPlaying, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onPressed,
      borderRadius: 40,
      focusPadding: const EdgeInsets.all(4),
      focusScale: 1.08,
      child: InkResponse(
        onTap: onPressed,
        radius: 48,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 1),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
      ),
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

/// Botão de volume com indicador (mostra valor atual).
class _VolumeButton extends StatelessWidget {
  final double currentVolume;
  final ValueChanged<double> onChange;

  const _VolumeButton({required this.currentVolume, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final icon = currentVolume == 0
        ? Icons.volume_off_rounded
        : currentVolume < 50
        ? Icons.volume_down_rounded
        : Icons.volume_up_rounded;

    return FocusableWidget(
      onSelect: () => onChange(0), // foco → toggle mute
      borderRadius: 16,
      focusScale: 1.05,
      child: InkResponse(
        onTap: () => onChange(currentVolume > 0 ? -currentVolume : 10),
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              SizedBox(
                width: 50,
                child: Text(
                  currentVolume == 0 ? 'Mudo' : '${currentVolume.round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
