import 'package:flutter_test/flutter_test.dart';
import 'package:goanime/ui/player/widgets/modern_video_player_controls.dart';

void main() {
  group('isBufferSufficient', () {
    // ─── Buffered <= zero ──────────────────────────────────────────

    test('buffered = Duration.zero → false', () {
      expect(
        isBufferSufficient(Duration.zero, const Duration(seconds: 60), Duration.zero),
        isFalse,
      );
    });

    test('buffered = negativo → false', () {
      expect(
        isBufferSufficient(const Duration(seconds: -1), const Duration(seconds: 60), Duration.zero),
        isFalse,
      );
    });

    // ─── Remaining <= zero (vídeo já acabou) ──────────────────────

    test('remaining = 0 (position == duration) → true se buffered >= 5s', () {
      expect(
        isBufferSufficient(const Duration(seconds: 5), const Duration(seconds: 60), const Duration(seconds: 60)),
        isTrue,
      );
    });

    test('remaining = 0 (position == duration) → false se buffered < 5s', () {
      expect(
        isBufferSufficient(const Duration(seconds: 4), const Duration(seconds: 60), const Duration(seconds: 60)),
        isFalse,
      );
    });

    test('remaining < 0 (position > duration) → true se buffered >= 5s', () {
      expect(
        isBufferSufficient(const Duration(seconds: 5), const Duration(seconds: 60), const Duration(seconds: 70)),
        isTrue,
      );
    });

    test('duration = 0 (sem duração conhecida) → true se buffered >= 5s', () {
      expect(
        isBufferSufficient(const Duration(seconds: 5), Duration.zero, Duration.zero),
        isTrue,
      );
    });

    test('duration = 0 com buffered < 5s → false', () {
      expect(
        isBufferSufficient(const Duration(seconds: 3), Duration.zero, Duration.zero),
        isFalse,
      );
    });

    // ─── Clamp mínimo de 30s ──────────────────────────────────────

    test('restante 30s → alvo = 30s (50%=15s, clamp mínimo 30s, 30s == restante)', () {
      // 30s restantes, 50% = 15s → clamp para 30s → 30s == remaining
      // precisa de buffer completo do trecho final
      expect(
        isBufferSufficient(const Duration(seconds: 30), const Duration(seconds: 60), const Duration(seconds: 30)),
        isTrue,
      );
    });

    test('restante 30s com buffered = 29s → false', () {
      expect(
        isBufferSufficient(const Duration(seconds: 29), const Duration(seconds: 60), const Duration(seconds: 30)),
        isFalse,
      );
    });

    test('restante 60s → alvo = 30s (50%=30s, >= 30s), buffered=30s → true', () {
      expect(
        isBufferSufficient(const Duration(seconds: 30), const Duration(seconds: 120), const Duration(seconds: 60)),
        isTrue,
      );
    });

    test('restante 60s, buffered=29s → false', () {
      expect(
        isBufferSufficient(const Duration(seconds: 29), const Duration(seconds: 120), const Duration(seconds: 60)),
        isFalse,
      );
    });

    // ─── Clamp máximo de 120s ─────────────────────────────────────

    test('restante 60min → alvo = 120s (50%=30min, cap max 120s)', () {
      expect(
        isBufferSufficient(const Duration(seconds: 120), const Duration(hours: 1), const Duration(minutes: 0)),
        isTrue,
      );
    });

    test('restante 60min, buffered=119s → false', () {
      expect(
        isBufferSufficient(const Duration(seconds: 119), const Duration(hours: 1), const Duration(minutes: 0)),
        isFalse,
      );
    });

    // ─── Capped pelo remaining (remaining < threshold) ─────────────

    test('restante 10s (menor que min 30s) → alvo = 10s (usar remaining)', () {
      expect(
        isBufferSufficient(const Duration(seconds: 10), const Duration(seconds: 60), const Duration(seconds: 50)),
        isTrue,
      );
    });

    test('restante 10s, buffered=9s → false', () {
      expect(
        isBufferSufficient(const Duration(seconds: 9), const Duration(seconds: 60), const Duration(seconds: 50)),
        isFalse,
      );
    });

    test('restante 20s (menor que min 30s) → alvo = 20s (usar remaining)', () {
      expect(
        isBufferSufficient(const Duration(seconds: 20), const Duration(seconds: 60), const Duration(seconds: 40)),
        isTrue,
      );
    });

    test('restante 20s, buffered=19s → false', () {
      expect(
        isBufferSufficient(const Duration(seconds: 19), const Duration(seconds: 60), const Duration(seconds: 40)),
        isFalse,
      );
    });

    // ─── Casos do mundo real ──────────────────────────────────────

    test('episódio 24min, pos=23min (restante 60s) → alvo=30s, buffered=30s → true', () {
      expect(
        isBufferSufficient(
          const Duration(seconds: 30),
          const Duration(minutes: 24),
          const Duration(minutes: 23),
        ),
        isTrue,
      );
    });

    test('episódio 24min, pos=12min (restante 12min) → alvo=120s (cap), buffered=120s → true', () {
      expect(
        isBufferSufficient(
          const Duration(seconds: 120),
          const Duration(minutes: 24),
          const Duration(minutes: 12),
        ),
        isTrue,
      );
    });

    test('filme 2h, pos=1h55min (restante 5min=300s) → alvo=120s (50% de 300=150s, cap max 120s)', () {
      expect(
        isBufferSufficient(
          const Duration(seconds: 120),
          const Duration(hours: 2),
          const Duration(minutes: 115),
        ),
        isTrue,
      );
    });

    test('filme 2h, pos=1h55min (restante 5min), buffered=119s → false', () {
      expect(
        isBufferSufficient(
          const Duration(seconds: 119),
          const Duration(hours: 2),
          const Duration(minutes: 115),
        ),
        isFalse,
      );
    });

    // ─── Valores exatos nos limites ───────────────────────────────

    test('restante = alvo exato (ex: restante 2min, alvo=30s, remaining > alvo)', () {
      // 2min restantes, 50% = 60s, > 30s, < 120s, capped=60s, remaining=120s > 60s
      // effective = 60s, buffered >= 60s
      expect(
        isBufferSufficient(const Duration(seconds: 60), const Duration(minutes: 3), const Duration(minutes: 1)),
        isTrue,
      );
    });

    test('restante 45s (50%=22.5s, clamp min 30s, 30s < 45s) → alvo=30s', () {
      expect(
        isBufferSufficient(const Duration(seconds: 30), const Duration(minutes: 1), const Duration(seconds: 15)),
        isTrue,
      );
    });

    test('restante 2h (120min, 50%=60min, cap max 120s) → alvo=120s, buffered=120s → true', () {
      expect(
        isBufferSufficient(const Duration(seconds: 120), const Duration(hours: 3), const Duration(hours: 1)),
        isTrue,
      );
    });

    // ─── Simetria / não depende de valores absolutos ─────────────

    test('mesmo cenário com duration maior produz mesmo resultado', () {
      // posição 50% do vídeo: restante = metade
      // halfRemaining = 25% da duração total
      // para duration 10min, pos=5min: restante=300s, half=150s, capped=120s
      // para duration 8min, pos=4min: restante=240s, half=120s, capped=120s
      expect(
        isBufferSufficient(const Duration(seconds: 120), const Duration(minutes: 10), const Duration(minutes: 5)),
        isTrue,
      );
    });
  });
}
