// ─────────────────────────────────────────────────────────────────────────────
// _KeyActivable — ativação por teclado/TV sem nó de foco extra
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyActivable extends StatelessWidget {
  final Widget child;
  final VoidCallback onActivate;

  const KeyActivable({
    super.key,
    required this.child,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onActivate();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}
