/// Teste de widget que simula buffering e verifica que os controles
/// (seek bar, play/pause, skip) continuam visíveis durante o carregamento.
///
/// Usa um [PlatformPlayer] mockado para evitar dependência de libs nativas.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/player/widgets/modern_video_player_controls.dart';
import 'package:media_kit/media_kit.dart';

// ═══════════════════════════════════════════════════════════════════
// Mock PlatformPlayer — permite simular eventos de player sem libs nativas
//
// IMPORTANTE: NÃO redeclarar os StreamControllers! A classe base
// PlatformPlayer já declara todos eles como final, e o PlayerStream
// é construído a partir deles no construtor da base. Redeclarar
// causaria shadowing, fazendo os eventos do teste irem para um
// controller diferente do que o PlayerStream escuta.
// ═══════════════════════════════════════════════════════════════════

class _MockPlatformPlayer extends PlatformPlayer {
  _MockPlatformPlayer() : super(configuration: const PlayerConfiguration());

  /// Nota: os StreamControllers (playingController, bufferingController,
  /// etc.) são herdados da classe base PlatformPlayer — NÃO redeclará-los
  /// aqui. Os métodos abaixo acessam os herdados diretamente.

  // ─── Estado simulado ──────────────────────────────────────────
  bool _playing = false;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    _playing = play;
    playingController.add(_playing);
    state = state.copyWith(playing: _playing);
  }

  @override
  Future<void> play() async {
    _playing = true;
    playingController.add(true);
    state = state.copyWith(playing: true);
  }

  @override
  Future<void> pause() async {
    _playing = false;
    playingController.add(false);
    state = state.copyWith(playing: false);
  }

  @override
  Future<void> playOrPause() async {
    if (_playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> stop() async {
    _playing = false;
    positionController.add(Duration.zero);
    playingController.add(false);
    state = state.copyWith(playing: false, position: Duration.zero);
  }

  @override
  Future<void> seek(Duration duration) async {
    positionController.add(duration);
    state = state.copyWith(position: duration);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setShuffle(bool shuffle) async {}

  @override
  Future<void> setPlaylistMode(PlaylistMode playlistMode) async {}

  @override
  Future<void> add(Media media, {int? index}) async {}

  @override
  Future<void> remove(int index) async {}

  @override
  Future<void> move(int from, int to) async {}

  @override
  Future<void> next({bool autoplay = true}) async {
    _playing = autoplay;
    playingController.add(autoplay);
    state = state.copyWith(playing: autoplay);
  }

  @override
  Future<void> previous({bool autoplay = true}) async {}

  @override
  Future<void> jump(int index, {bool autoplay = true}) async {}

  @override
  Future<void> setVideoTrack(VideoTrack track) async {}

  @override
  Future<void> setAudioTrack(AudioTrack track) async {}

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {}

  @override
  Future<void> setAudioDevice(AudioDevice audioDevice) async {}

  @override
  Future<Uint8List?> screenshot({
    String? format,
    bool includeLibassSubtitles = true,
  }) async => null;

  @override
  Future<int> get handle async => 0;

  // ─── Helpers para testes ─────────────────────────────────────

  /// Dispara um evento de buffering=true (herdado da classe base).
  void startBuffering() => bufferingController.add(true);

  /// Dispara um evento de buffering=false.
  void stopBuffering() => bufferingController.add(false);

  /// Dispara alteração de posição.
  void updatePosition(Duration position) {
    positionController.add(position);
    state = state.copyWith(position: position);
  }

  /// Dispara alteração de duração.
  void updateDuration(Duration duration) {
    durationController.add(duration);
    state = state.copyWith(duration: duration);
  }

  /// Dispara atualização do buffer.
  void updateBuffer(Duration buffer) => bufferController.add(buffer);

  /// Dispara evento de erro.
  void emitError(String error) => errorController.add(error);

  /// Fecha todos os controllers (herdados).
  @override
  Future<void> dispose() async {
    // Os controllers são da classe base, não chamar super.dispose()
    // pois a classe base não tem dispose público.
    // Fechamos manualmente os controllers que usamos nos testes.
    await playingController.close();
    await positionController.close();
    await durationController.close();
    await bufferingController.close();
    await completedController.close();
    await errorController.close();
    await bufferController.close();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════
// Helpers de construção
// ═══════════════════════════════════════════════════════════════════

/// Constrói o [MaterialApp] com [ModernVideoPlayerControls] para teste.
Widget buildTestApp({
  required Player player,
  String? skipLabel,
  VoidCallback? onSkip,
  VoidCallback? onNextEpisode,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          const ColoredBox(color: Colors.black, child: SizedBox.expand()),
          ModernVideoPlayerControls(
            player: player,
            title: 'Episódio 1 - Teste',
            animeTitle: 'Anime Teste',
            onBack: () {},
            skipLabel: skipLabel,
            onSkip: onSkip,
            onNextEpisode: onNextEpisode,
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Testes
// ═══════════════════════════════════════════════════════════════════

void main() {
  late _MockPlatformPlayer mockPlatform;
  late Player player;

  setUp(() {
    mockPlatform = _MockPlatformPlayer();
    player = Player(platformPlayer: mockPlatform);
  });

  tearDown(() async {
    await mockPlatform.dispose();
    player.dispose();
  });

  group('ModernVideoPlayerControls — buffering', () {
    testWidgets('loading inicial mostra layout + loading indicator', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(player: player));
      // Pump para processar a construção inicial
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Estado inicial: deve mostrar loading (primeira renderização).
      // O seek bar deve estar visível (parte do _buildLayout).
      expect(
        find.byType(Slider),
        findsOneWidget,
        reason: 'Seek bar deve estar visível mesmo durante loading inicial',
      );

      // O botão de voltar deve estar na árvore.
      expect(
        find.byIcon(Icons.arrow_back_rounded),
        findsOneWidget,
        reason: 'Botão voltar deve estar visível durante loading inicial',
      );
    });

    testWidgets('após playing, buffering não esconde controles', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Simula abertura de mídia: position > 0, duration conhecida
      mockPlatform.updateDuration(const Duration(minutes: 24));
      mockPlatform.updatePosition(const Duration(seconds: 5));
      mockPlatform.updateBuffer(const Duration(seconds: 30));

      // Simula playing = true
      mockPlatform.playingController.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Player está tocando — deve mostrar o botão pause
      expect(
        find.byIcon(Icons.pause_rounded),
        findsOneWidget,
        reason: 'Botão pause deve estar visível quando tocando',
      );

      // Simula buffering durante playback
      mockPlatform.startBuffering();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Durante buffering, o loading indicator aparece (canto superior direito)
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'Loading indicator deve aparecer durante buffering',
      );

      // MAS os controles continuam visíveis:
      // 1. Seek bar ainda presente
      expect(
        find.byType(Slider),
        findsOneWidget,
        reason: 'Seek bar deve continuar visível durante buffering',
      );

      // 2. Botão de voltar presente
      expect(
        find.byIcon(Icons.arrow_back_rounded),
        findsOneWidget,
        reason: 'Botão voltar deve continuar visível durante buffering',
      );

      // 3. Botão de play/pause presente
      expect(
        find.byIcon(Icons.pause_rounded),
        findsOneWidget,
        reason: 'Botão pause deve continuar visível durante buffering',
      );

      // 4. Seek bar deve ser interagível
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(
        slider.onChanged,
        isNotNull,
        reason: 'Seek bar deve ser interagível durante buffering',
      );
    });

    testWidgets('buffering → stopBuffering restaura estado playing', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Setup: player tocando
      mockPlatform.updateDuration(const Duration(minutes: 24));
      mockPlatform.updatePosition(const Duration(seconds: 5));
      mockPlatform.playingController.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Inicia buffering
      mockPlatform.startBuffering();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'Loading deve aparecer durante buffering',
      );

      // Termina buffering
      mockPlatform.stopBuffering();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Loading indicator deve sumir
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Loading deve sumir após buffering terminar',
      );

      // Botão de pause ainda presente (playing=true preservado)
      expect(
        find.byIcon(Icons.pause_rounded),
        findsOneWidget,
        reason: 'Botão pause deve estar presente após buffering',
      );
    });

    testWidgets('seek não quebra durante buffering', (tester) async {
      await tester.pumpWidget(buildTestApp(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Setup: player tocando
      mockPlatform.updateDuration(const Duration(minutes: 24));
      mockPlatform.updatePosition(const Duration(seconds: 5));
      mockPlatform.playingController.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Inicia buffering
      mockPlatform.startBuffering();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Seek via onChanged do Slider (simula arrastar para 50%)
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(0.5);

      // Não deve crashar — seek bar continua presente
      expect(
        find.byType(Slider),
        findsOneWidget,
        reason: 'Seek bar continua presente após seek durante buffering',
      );
    });

    testWidgets('skip button visível e clicável durante buffering', (
      tester,
    ) async {
      var skipClicked = false;

      await tester.pumpWidget(
        buildTestApp(
          player: player,
          skipLabel: 'Pular Intro',
          onSkip: () => skipClicked = true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Setup: player tocando, mostra skip button
      mockPlatform.updateDuration(const Duration(minutes: 24));
      mockPlatform.updatePosition(const Duration(seconds: 90));
      mockPlatform.playingController.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Skip button deve estar visível
      expect(
        find.text('Pular Intro'),
        findsOneWidget,
        reason: 'Botão skip deve estar visível',
      );

      // Inicia buffering
      mockPlatform.startBuffering();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Skip button continua visível durante buffering
      expect(
        find.text('Pular Intro'),
        findsOneWidget,
        reason: 'Botão skip deve continuar visível durante buffering',
      );

      // Clica no skip
      await tester.tap(find.text('Pular Intro'));
      await tester.pump();

      expect(
        skipClicked,
        isTrue,
        reason: 'Skip deve funcionar mesmo durante buffering',
      );
    });

    testWidgets('play/pause toggle não bloqueia durante buffering', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Setup: player tocando
      mockPlatform.updateDuration(const Duration(minutes: 24));
      mockPlatform.updatePosition(const Duration(seconds: 5));
      mockPlatform.playingController.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Inicia buffering
      mockPlatform.startBuffering();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tapa no centro do player para toggle play/pause
      // O GestureDetector no build() cobre toda a área
      await tester.tapAt(const Offset(200, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Não deve crashar — o toggle funcionou
      expect(
        find.byType(ModernVideoPlayerControls),
        findsOneWidget,
        reason: 'Player deve continuar funcionando após toggle',
      );
    });

    testWidgets('loading indicator tem estilo sutil (não central/tela cheia)', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(player: player));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Simula buffering com position > 0 (mid-playback)
      mockPlatform.updatePosition(const Duration(seconds: 5));
      mockPlatform.startBuffering();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Loading indicator presente
      final progressFinder = find.byType(CircularProgressIndicator);
      expect(
        progressFinder,
        findsOneWidget,
        reason: 'Loading indicator deve estar presente',
      );

      // Verifica o estilo: strokeWidth fino (2.5)
      final indicator = tester.widget<CircularProgressIndicator>(
        progressFinder,
      );
      expect(
        indicator.strokeWidth,
        2.5,
        reason: 'Loading indicator deve ser fino (2.5)',
      );

      // O loading NÃO deve estar no centro da tela — buscamos um Center
      // que seja pai do CircularProgressIndicator
      final centerParents = find.ancestor(
        of: progressFinder,
        matching: find.byType(Center),
      );
      expect(
        centerParents,
        findsNothing,
        reason: 'Loading não deve estar centralizado (era tela cheia)',
      );
    });
  });
}
