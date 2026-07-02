/// Testes puros para a lógica de decisão do `GoRouterRouteRefreshMixin`.
///
/// A lógica central do mixin está em `_onRouteChanged()`:
///
/// ```dart
/// final currentLocation = GoRouterState.of(context).uri.toString();
/// final isHome = currentLocation == routePath;
/// final wasDifferent = currentLocation != _lastLocation;
/// if (isHome && wasDifferent) {
///   onRouteRefresh();
/// }
/// _lastLocation = currentLocation;
/// ```
///
/// Este arquivo testa exclusivamente as regras de decisão sem dependência
/// de Flutter ou GoRouter — a função `_evaluateRouteChange` extrai a
/// lógica pura de comparação de localizações.
///
/// Testes de integração com GoRouter + ShellRoute + push/pop estão
/// cobertos em `test/ui/pauloflix/widgets/pauloflix_see_all_screen_refresh_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════
// Lógica pura extraída do mixin
// ═══════════════════════════════════════════════════════════════════════

/// Extrai a lógica central do `GoRouterRouteRefreshMixin._onRouteChanged`
/// como função pura para teste isolado.
///
/// Retorna `(shouldRefresh, newLastLocation)` onde:
/// - `shouldRefresh`: `true` se `currentLocation` é a rota inicial e
///   diferente da última localização conhecida
/// - `newLastLocation`: sempre igual a `currentLocation` (o mixin sempre
///   atualiza `_lastLocation` independente do resultado)
(bool shouldRefresh, String newLastLocation) _evaluateRouteChange({
  required String currentLocation,
  required String lastLocation,
  required String routePath,
}) {
  final isHome = currentLocation == routePath;
  final wasDifferent = currentLocation != lastLocation;
  return (isHome && wasDifferent, currentLocation);
}

// ═══════════════════════════════════════════════════════════════════════
// Testes
// ═══════════════════════════════════════════════════════════════════════

void main() {
  group('GoRouterRouteRefreshMixin — lógica pura', () {
    const routePath = '/test';

    test(
      'não dispara refresh quando já está na home e _lastLocation '
      'foi inicializado (estado pós-didChangeDependencies)',
      () {
        final (refresh, newLast) = _evaluateRouteChange(
          currentLocation: '/test',
          lastLocation: '/test',
          routePath: routePath,
        );
        expect(refresh, isFalse, reason: 'mesma localização → wasDifferent=false');
        expect(newLast, '/test');
      },
    );

    test(
      'não dispara refresh quando currentLocation != routePath '
      '(usuário navegou para outra tela)',
      () {
        final (refresh, newLast) = _evaluateRouteChange(
          currentLocation: '/other',
          lastLocation: '/test',
          routePath: routePath,
        );
        expect(refresh, isFalse, reason: 'isHome=false');
        expect(newLast, '/other');
      },
    );

    test(
      'dispara refresh quando volta do player/outra rota para a home '
      '(currentLocation == routePath && lastLocation != routePath)',
      () {
        final (refresh, newLast) = _evaluateRouteChange(
          currentLocation: '/test',
          lastLocation: '/other',
          routePath: routePath,
        );
        expect(refresh, isTrue, reason: 'isHome=true, wasDifferent=true');
        expect(newLast, '/test');
      },
    );

    test(
      'não dispara refresh se já está na home (mesmo currentLocation '
      'e lastLocation)',
      () {
        final (refresh, newLast) = _evaluateRouteChange(
          currentLocation: '/test',
          lastLocation: '/test',
          routePath: routePath,
        );
        expect(refresh, isFalse, reason: 'wasDifferent=false');
        expect(newLast, '/test');
      },
    );

    test(
      'não dispara refresh quando sai da home em direção a outra rota',
      () {
        final (refresh, newLast) = _evaluateRouteChange(
          currentLocation: '/other',
          lastLocation: '/test',
          routePath: routePath,
        );
        expect(refresh, isFalse, reason: 'isHome=false');
        expect(newLast, '/other');
      },
    );

    test('dispara refresh em múltiplos ciclos de ida-e-volta', () {
      // Estado inicial
      var lastLocation = '/test';

      // Ciclo 1: navega para /other
      var (refresh, newLast) = _evaluateRouteChange(
        currentLocation: '/other',
        lastLocation: lastLocation,
        routePath: routePath,
      );
      expect(refresh, isFalse);
      lastLocation = newLast;

      // Ciclo 1: volta para /test
      (refresh, newLast) = _evaluateRouteChange(
        currentLocation: '/test',
        lastLocation: lastLocation,
        routePath: routePath,
      );
      expect(refresh, isTrue);
      lastLocation = newLast;

      // Ciclo 2: navega para /other
      (refresh, newLast) = _evaluateRouteChange(
        currentLocation: '/other',
        lastLocation: lastLocation,
        routePath: routePath,
      );
      expect(refresh, isFalse);
      lastLocation = newLast;

      // Ciclo 2: volta para /test
      (refresh, newLast) = _evaluateRouteChange(
        currentLocation: '/test',
        lastLocation: lastLocation,
        routePath: routePath,
      );
      expect(refresh, isTrue);
      lastLocation = newLast;

      // Ciclo 3: última volta deve funcionar também
      // (navega para /other e volta)
      (refresh, newLast) = _evaluateRouteChange(
        currentLocation: '/other',
        lastLocation: lastLocation,
        routePath: routePath,
      );
      expect(refresh, isFalse);
      lastLocation = newLast;

      (refresh, _) = _evaluateRouteChange(
        currentLocation: '/test',
        lastLocation: lastLocation,
        routePath: routePath,
      );
      expect(refresh, isTrue);
    });

    test('funciona com routePath /pauloflix-see-all (animes)', () {
      const animePath = '/pauloflix-see-all';

      // Saiu e voltou
      var (refresh, _) = _evaluateRouteChange(
        currentLocation: animePath,
        lastLocation: '/player',
        routePath: animePath,
      );
      expect(refresh, isTrue);

      // Já estava na home
      (refresh, _) = _evaluateRouteChange(
        currentLocation: animePath,
        lastLocation: animePath,
        routePath: animePath,
      );
      expect(refresh, isFalse);
    });

    test('funciona com routePath /pauloflix-movies (filmes)', () {
      const moviePath = '/pauloflix-movies';

      var (refresh, _) = _evaluateRouteChange(
        currentLocation: moviePath,
        lastLocation: '/player',
        routePath: moviePath,
      );
      expect(refresh, isTrue);

      (refresh, _) = _evaluateRouteChange(
        currentLocation: moviePath,
        lastLocation: moviePath,
        routePath: moviePath,
      );
      expect(refresh, isFalse);
    });

    test('newLastLocation é sempre igual a currentLocation', () {
      // Verifica que o mixin sempre atualiza _lastLocation, independente
      // do resultado do refresh.
      final (r1, l1) = _evaluateRouteChange(
        currentLocation: '/home',
        lastLocation: '/player',
        routePath: '/home',
      );
      expect(r1, isTrue);
      expect(l1, '/home');

      final (r2, l2) = _evaluateRouteChange(
        currentLocation: '/other',
        lastLocation: '/home',
        routePath: '/home',
      );
      expect(r2, isFalse);
      expect(l2, '/other');

      final (r3, l3) = _evaluateRouteChange(
        currentLocation: '/home',
        lastLocation: '/other',
        routePath: '/home',
      );
      expect(r3, isTrue);
      expect(l3, '/home');
    });
  });
}
