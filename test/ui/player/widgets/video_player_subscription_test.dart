import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Teste para o padrão de gerenciamento de subscriptions usado em
/// `video_player_screen.dart`:
///
/// 1. `_initializeVideoPlayer`: `_debugTracksSub?.cancel()` antes de
///    `_debugTracksSub = _player.stream.tracks.listen(...)`
/// 2. `_cleanupControllers`: cancel + null em todas as subscriptions
/// 3. `dispose`: cancel em todas as subscriptions (fire-and-forget)
///
/// Não testamos `ModernVideoPlayerScreen` diretamente porque o `Player` do
/// media_kit depende de libs nativas (Android/iOS) indisponíveis em
/// flutter_test. Em vez disso, validamos o padrão com um `StreamController`
/// genérico, usando contadores de callback para provar que listeners
/// anteriores não recebem dados após cancelamento.
///
/// Nota: em flutter_test, `StreamController.broadcast().add()` agenda o
/// evento como microtask (não síncrono), então usamos `await Future(() {})`
/// para drenar a fila antes de verificar os contadores.
void main() {
  group('Padrão de subscription: cancel antes de reassign', () {
    late StreamController<String> controller;
    late StreamSubscription<String>? sub;

    setUp(() {
      controller = StreamController<String>.broadcast();
      sub = null;
    });

    tearDown(() {
      sub?.cancel();
      controller.close();
    });

    test('primeira subscription é criada sem cancelamento prévio', () {
      sub?.cancel();
      sub = controller.stream.listen((_) {});

      expect(sub, isNotNull);
      expect(controller.hasListener, isTrue);
    });

    test('segunda subscription cancela a anterior — apenas a nova recebe dados',
        () async {
      var callCount = 0;

      // Primeira inicialização
      sub?.cancel();
      sub = controller.stream.listen((_) => callCount++);
      final firstSub = sub;

      // Segunda inicialização (troca de episódio)
      sub?.cancel();
      sub = controller.stream.listen((_) => callCount++);
      final secondSub = sub;

      // Emite dado — apenas o segundo listener deve contar
      controller.add('data');
      // Drena microtask do broadcast stream em flutter_test
      await Future(() {});
      expect(callCount, 1,
          reason: 'A primeira subscription foi cancelada e não deve contar');
      expect(secondSub, isNotNull);
      expect(firstSub, isNot(secondSub),
          reason: 'São objetos de subscription diferentes');
    });

    test('múltiplas trocas de episódio não acumulam listeners', () async {
      var callCount = 0;

      // Simula 5 trocas de episódio
      for (var i = 0; i < 5; i++) {
        sub?.cancel();
        sub = controller.stream.listen((_) => callCount++);
      }

      // Emite dado — apenas o último listener deve contar
      controller.add('data');
      // Drena microtask do broadcast stream em flutter_test
      await Future(() {});
      expect(callCount, 1,
          reason:
              'Apenas o último listener deve receber o dado (5 trocas, 1 ativo)');
    });
  });

  group('Padrão de cleanup (cancel + null)', () {
    late StreamController<String> controller;
    StreamSubscription<String>? sub1;
    StreamSubscription<String>? sub2;

    setUp(() {
      controller = StreamController<String>.broadcast();
      sub1 = null;
      sub2 = null;
    });

    tearDown(() {
      sub1?.cancel();
      sub2?.cancel();
      controller.close();
    });

    test('cleanup cancela e zera todas as subscriptions', () async {
      sub1 = controller.stream.listen((_) {});
      sub2 = controller.stream.listen((_) {});

      // Simula _cleanupControllers
      await sub1?.cancel();
      await sub2?.cancel();
      sub1 = null;
      sub2 = null;

      expect(sub1, isNull);
      expect(sub2, isNull);
      expect(controller.hasListener, isFalse,
          reason: 'Nenhum listener ativo após cleanup');
    });

    test('dispose cancela fire-and-forget sem await', () {
      sub1 = controller.stream.listen((_) {});
      sub2 = controller.stream.listen((_) {});

      // Simula dispose (sem await — fire-and-forget)
      sub1?.cancel();
      sub2?.cancel();
      sub1 = null;
      sub2 = null;

      expect(sub1, isNull);
      expect(sub2, isNull);
      expect(controller.hasListener, isFalse,
          reason: 'Nenhum listener ativo após dispose');
    });

    test('chamar cleanup duplamente não causa erro (idempotente)', () async {
      sub1 = controller.stream.listen((_) {});
      sub2 = controller.stream.listen((_) {});

      // Primeira chamada de cleanup
      await sub1?.cancel();
      await sub2?.cancel();
      sub1 = null;
      sub2 = null;

      // Segunda chamada de cleanup (sub já são null)
      await sub1?.cancel(); // no-op, não lança erro
      await sub2?.cancel(); // no-op, não lança erro
      sub1 = null;
      sub2 = null;

      expect(controller.hasListener, isFalse,
          reason: 'Cleanup duplo não deve reativar listeners');
    });
  });

  group('Padrão de subscription aninhada (_waitForEmbeddedSubtitleTracks)', () {
    late StreamController<String> controller;

    setUp(() {
      controller = StreamController<String>.broadcast();
    });

    tearDown(() {
      controller.close();
    });

    test(
        'subscription interna (_tracksSub) sobrescreve a externa (_debugTracksSub) sem vazar',
        () async {
      StreamSubscription<String>? tracksSub;
      StreamSubscription<String>? debugSub;
      var debugCallCount = 0;
      var tracksCallCount = 0;

      // Simula _initializeVideoPlayer: cria debugSub
      debugSub = controller.stream.listen((_) => debugCallCount++);

      // Simula _waitForEmbeddedSubtitleTracks: cria tracksSub
      // (sobrescreve _tracksSub)
      final completer = Completer<void>();
      tracksSub = controller.stream.listen((_) {
        tracksCallCount++;
        completer.complete();
      });
      controller.add('data');
      await completer.future;

      // Ambos os listeners receberam o dado (broadcast)
      expect(debugCallCount, 1,
          reason: 'debugSub recebeu o dado (broadcast)');
      expect(tracksCallCount, 1,
          reason: 'tracksSub recebeu o dado (broadcast)');

      // Simula _cleanupControllers — cancela ambos
      await debugSub.cancel();
      await tracksSub.cancel();
      debugSub = null;
      tracksSub = null;

      expect(controller.hasListener, isFalse,
          reason: 'Nenhum listener ativo após cleanup');
    });
  });
}
