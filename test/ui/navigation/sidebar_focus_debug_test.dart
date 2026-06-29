// Teste de instrumentação: simula o fluxo ← → no MainNavigationScreen
// em wide layout. Imprime o estado de foco em cada passo para
// diagnosticar o bug "foco preso na sidebar após →".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goanime/ui/core/widgets/focusable_widget.dart';

void main() {
  testWidgets('debug: fluxo ← → na sidebar em wide layout', (tester) async {
    // Setup de tamanho wide (TV/desktop): 1920x1080
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Router mínimo: 2 rotas para podermos "navegar" entre elas
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const _TestHome(),
        ),
        GoRoute(
          path: '/watchlist',
          name: 'watchlist',
          builder: (context, state) => const _TestWatchlist(),
        ),
      ],
    );

    final logs = <String>[];

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    logs.add('=== ESTADO 1: inicial ===');
    logs.add('primaryFocus = ${FocusManager.instance.primaryFocus}');
    logs.add(
      'primaryFocus.canRequestFocus = ${FocusManager.instance.primaryFocus?.canRequestFocus}',
    );
    logs.add('location = ${router.routerDelegate.currentConfiguration.uri}');

    // 2. Pressionar ← no edge do conteúdo → deve abrir sidebar
    logs.add('\n=== ENVIANDO ← (abre sidebar) ===');
    final leftEvent = await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    logs.add('sendKeyEvent result: $leftEvent');
    await tester.pumpAndSettle();

    logs.add('=== ESTADO 2: após ← ===');
    logs.add('primaryFocus = ${FocusManager.instance.primaryFocus}');
    logs.add(
      'primaryFocus.context = ${FocusManager.instance.primaryFocus?.context}',
    );

    // 3. Pressionar → → deve fechar sidebar e focar conteúdo
    logs.add('\n=== ENVIANDO → (fecha sidebar) ===');
    final rightHandled = await tester.sendKeyEvent(
      LogicalKeyboardKey.arrowRight,
    );
    logs.add('rightHandled = $rightHandled');
    await tester.pumpAndSettle();

    logs.add('=== ESTADO 3: após → ===');
    logs.add('primaryFocus = ${FocusManager.instance.primaryFocus}');
    logs.add(
      'primaryFocus.context = ${FocusManager.instance.primaryFocus?.context}',
    );

    // Imprime todos os logs coletados
    for (final l in logs) {
      // ignore: avoid_print
      print(l);
    }
  });
}

class _TestHome extends StatelessWidget {
  const _TestHome();
  @override
  Widget build(BuildContext context) {
    return const _FocusableCard(label: 'card-home');
  }
}

class _TestWatchlist extends StatelessWidget {
  const _TestWatchlist();
  @override
  Widget build(BuildContext context) {
    return const _FocusableCard(label: 'card-watchlist');
  }
}

class _FocusableCard extends StatefulWidget {
  final String label;
  const _FocusableCard({required this.label});
  @override
  State<_FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<_FocusableCard> {
  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: () => debugPrint('[${widget.label}] select'),
      onFocus: () => debugPrint('[${widget.label}] focus'),
      child: SizedBox(
        width: 200,
        height: 200,
        child: Center(child: Text(widget.label)),
      ),
    );
  }
}
