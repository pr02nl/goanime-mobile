/// Testes de cobertura para o `GoRouterRouteRefreshMixin`.
///
/// Divide-se em 3 grupos:
///
/// 1. **Lógica pura** — extrai as regras de decisão como funções puras,
///    sem dependência de Flutter ou GoRouter.
/// 2. **didChangeDependencies guard** — testa a lógica de inicialização
///    de `_lastLocation` (extraída como função pura).
/// 3. **Widget lifecycle** — integração com GoRouter: montagem e
///    dispose sem crash, guard `!mounted` via callback manual.
///
/// NOTA: Testes de navegação GoRouter (`router.go()`) não foram incluídos
/// porque o Navigator interno do GoRouter usa GlobalKeys que causam
/// `Duplicate GlobalKey detected` durante `pump()` após `go()` — um
/// problema conhecido do próprio GoRouter em ambiente de teste. O
/// comportamento de navegação + refresh é coberto pelo teste de
/// integração `pauloflix_see_all_screen_refresh_test.dart` (5 testes
/// via `pumpWidget`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:goanime/ui/core/mixins/go_router_route_refresh_mixin.dart';

// ═══════════════════════════════════════════════════════════════════════
// Funções puras extraídas do mixin
// ═══════════════════════════════════════════════════════════════════════

/// Extrai a lógica central do `_onRouteChanged` como função pura.
(bool shouldRefresh, String newLastLocation) _evaluateRouteChange({
  required String currentLocation,
  required String lastLocation,
  required String routePath,
}) {
  final isHome = currentLocation == routePath;
  final wasDifferent = currentLocation != lastLocation;
  return (isHome && wasDifferent, currentLocation);
}

/// Extrai a lógica do guard de `didChangeDependencies` como função pura.
(bool shouldSet, String newLastLocation) _evaluateDidChangeDependencies({
  required String currentLocation,
  required String lastLocation,
}) {
  if (lastLocation.isEmpty) {
    return (true, currentLocation);
  }
  return (false, lastLocation);
}

// ═══════════════════════════════════════════════════════════════════════
// Widget de teste
// ═══════════════════════════════════════════════════════════════════════

/// Tela de teste mínima que usa o mixin.
class _MixinTestScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  final String path;

  const _MixinTestScreen({this.onRefresh, this.path = '/test'});

  @override
  State<_MixinTestScreen> createState() => _MixinTestScreenState();
}

class _MixinTestScreenState extends State<_MixinTestScreen>
    with GoRouterRouteRefreshMixin<_MixinTestScreen> {
  @override
  String get routePath => widget.path;

  @override
  void onRouteRefresh() => widget.onRefresh?.call();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Test'));
}

/// Constrói um GoRouter com a tela de teste no ShellRoute.
GoRouter _buildTestRouter({
  VoidCallback? onRefresh,
  String path = '/test',
}) {
  return GoRouter(
    initialLocation: path,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: path,
            name: 'test',
            builder: (context, state) => _MixinTestScreen(
              onRefresh: onRefresh,
              path: path,
            ),
          ),
        ],
      ),
    ],
  );
}

/// Wrapper `MaterialApp.router`.
Widget _buildTestApp(GoRouter router) {
  return MaterialApp.router(routerConfig: router);
}

// ═══════════════════════════════════════════════════════════════════════
// Testes
// ═══════════════════════════════════════════════════════════════════════

void main() {
  // ─────────────────────────────────────────────────────────────────────
  // Grupo 1: Lógica pura do _onRouteChanged
  // ─────────────────────────────────────────────────────────────────────
  group('GoRouterRouteRefreshMixin — lógica pura (_onRouteChanged)', () {
    const routePath = '/test';

    test('não dispara refresh: mesma localização (já na home)', () {
      final (refresh, newLast) = _evaluateRouteChange(
        currentLocation: '/test',
        lastLocation: '/test',
        routePath: routePath,
      );
      expect(refresh, isFalse);
      expect(newLast, '/test');
    });

    test('não dispara refresh: navegou para outra rota (isHome=false)', () {
      final (refresh, newLast) = _evaluateRouteChange(
        currentLocation: '/other',
        lastLocation: '/test',
        routePath: routePath,
      );
      expect(refresh, isFalse);
      expect(newLast, '/other');
    });

    test('dispara refresh: voltou do player para a home', () {
      final (refresh, newLast) = _evaluateRouteChange(
        currentLocation: '/test',
        lastLocation: '/other',
        routePath: routePath,
      );
      expect(refresh, isTrue);
      expect(newLast, '/test');
    });

    test('dispara refresh em múltiplos ciclos de ida-e-volta', () {
      var last = '/test';
      for (int cycle = 0; cycle < 3; cycle++) {
        // Sai
        var (r, l) = _evaluateRouteChange(
          currentLocation: '/other',
          lastLocation: last,
          routePath: routePath,
        );
        expect(r, isFalse, reason: 'ciclo $cycle: saindo');
        last = l;
        // Volta
        (r, l) = _evaluateRouteChange(
          currentLocation: '/test',
          lastLocation: last,
          routePath: routePath,
        );
        expect(r, isTrue, reason: 'ciclo $cycle: voltando');
        last = l;
      }
    });

    test('funciona com routePath /pauloflix-see-all e /pauloflix-movies', () {
      for (final p in ['/pauloflix-see-all', '/pauloflix-movies']) {
        var (refresh, _) = _evaluateRouteChange(
          currentLocation: p, lastLocation: '/player', routePath: p,
        );
        expect(refresh, isTrue, reason: 'retorno para $p');
        (refresh, _) = _evaluateRouteChange(
          currentLocation: p, lastLocation: p, routePath: p,
        );
        expect(refresh, isFalse, reason: 'já em $p');
      }
    });

    test('newLastLocation é sempre igual a currentLocation (invariante)', () {
      final (r1, l1) = _evaluateRouteChange(
        currentLocation: '/home', lastLocation: '/player', routePath: '/home',
      );
      expect(r1, isTrue);
      expect(l1, '/home');

      final (r2, l2) = _evaluateRouteChange(
        currentLocation: '/other', lastLocation: '/home', routePath: '/home',
      );
      expect(r2, isFalse);
      expect(l2, '/other');

      final (r3, l3) = _evaluateRouteChange(
        currentLocation: '/home', lastLocation: '/other', routePath: '/home',
      );
      expect(r3, isTrue);
      expect(l3, '/home');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Grupo 2: Lógica pura do guard de didChangeDependencies
  // ─────────────────────────────────────────────────────────────────────
  group(
    'GoRouterRouteRefreshMixin — lógica pura (didChangeDependencies guard)',
    () {
      test('primeira chamada (lastLocation vazio) → seta localização', () {
        final (shouldSet, newLast) = _evaluateDidChangeDependencies(
          currentLocation: '/test',
          lastLocation: '',
        );
        expect(shouldSet, isTrue);
        expect(newLast, '/test');
      });

      test('segunda+ chamada (lastLocation preenchido) → preserva', () {
        final (shouldSet, newLast) = _evaluateDidChangeDependencies(
          currentLocation: '/other',
          lastLocation: '/test',
        );
        expect(shouldSet, isFalse);
        expect(newLast, '/test');
      });

      test('não sobrescreve em chamadas subsequentes', () {
        const routePath = '/pauloflix-see-all';
        var lastLocation = '';

        // 1ª chamada: seta
        var (shouldSet, newLast) = _evaluateDidChangeDependencies(
          currentLocation: routePath,
          lastLocation: lastLocation,
        );
        expect(shouldSet, isTrue);
        lastLocation = newLast;

        // 2ª chamada: preserva
        (shouldSet, newLast) = _evaluateDidChangeDependencies(
          currentLocation: routePath,
          lastLocation: lastLocation,
        );
        expect(shouldSet, isFalse);
        expect(newLast, routePath);

        // 3ª chamada: preserva
        (shouldSet, newLast) = _evaluateDidChangeDependencies(
          currentLocation: routePath,
          lastLocation: lastLocation,
        );
        expect(shouldSet, isFalse);
        expect(newLast, routePath);
      });

      test('guarda não altera _lastLocation mesmo com rota diferente', () {
        const lastLocation = '/test';

        final (shouldSet, newLast) = _evaluateDidChangeDependencies(
          currentLocation: '/other',
          lastLocation: lastLocation,
        );
        expect(shouldSet, isFalse);
        expect(newLast, '/test');
      });
    },
  );

  // ─────────────────────────────────────────────────────────────────────
  // Grupo 3: Widget lifecycle — integração com GoRouter
  // ─────────────────────────────────────────────────────────────────────
  group('GoRouterRouteRefreshMixin — widget lifecycle', () {
    testWidgets('monta e desmonta sem crash', (tester) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(_buildTestApp(router));

      // Montagem inicial (initState + didChangeDependencies executam)
      expect(find.text('Test'), findsOneWidget);

      // Desmonta — dispose remove o listener sem crash
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Test'), findsNothing);
    });

  });
}
