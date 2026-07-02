/// Mixin que adiciona detecção automática de retorno do player
/// (ou qualquer rota externa) para recarregar dados de progresso.
///
/// Uso:
/// ```dart
/// class _MyScreenState extends State<MyScreen>
///     with GoRouterRouteRefreshMixin {
///
///   @override
///   String get routePath => '/my-screen';
///
///   @override
///   void onRouteRefresh() {
///     _loadMyProgressData();
///   }
/// }
/// ```
///
/// O mixin injeta a lógica GoRouter nos lifecycle methods:
/// - `initState`: captura `routerDelegate` e adiciona listener
/// - `didChangeDependencies`: inicializa `_lastLocation`
/// - `dispose`: remove o listener do `routerDelegate`
///
/// A classe consumidora deve chamar `super.initState()`,
/// `super.didChangeDependencies()` e `super.dispose()` para que
/// o mixin funcione corretamente.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Qualquer State que use este mixin deve:
/// 1. Declarar `routePath` — a rota que identifica esta tela
/// 2. Implementar `onRouteRefresh()` — ação a executar no retorno
mixin GoRouterRouteRefreshMixin<T extends StatefulWidget> on State<T> {
  /// Rota que identifica esta tela (ex: '/pauloflix-see-all').
  /// O mixin detecta quando a navegação retorna para esta rota.
  String get routePath;

  /// Callback chamado quando o usuário retorna para `routePath`
  /// vindo de uma rota diferente (ex: do player).
  void onRouteRefresh();

  /// Última localização conhecida. Usado para detectar se a rota
  /// atual é diferente da anterior (evita refresh desnecessário).
  String _lastLocation = '';

  /// Referência ao routerDelegate capturada em initState para
  /// add/remove listener sem depender de `GoRouter.of(context)`
  /// (que não está disponível em dispose quando o widget já foi
  /// desmontado da árvore).
  late final Listenable _routerDelegate;

  @override
  void initState() {
    super.initState();
    _routerDelegate = GoRouter.of(context).routerDelegate;
    _routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializa a localização atual APÓS o widget estar montado
    // na árvore de rota (GoRouterState.of(context) requer ModalRoute
    // que só está disponível em didChangeDependencies/build, não em
    // initState).
    //
    // Guard `if (_lastLocation.isEmpty)`: didChangeDependencies pode
    // disparar múltiplas vezes (ex: tema, locale) e não queremos
    // resetar _lastLocation no meio da sessão.
    if (_lastLocation.isEmpty) {
      _lastLocation = GoRouterState.of(context).uri.toString();
    }
  }

  @override
  void dispose() {
    _routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  /// Callback disparado quando o GoRouter notifica mudança de rota.
  /// Detecta quando voltamos do player (`routePath` com localização
  /// diferente da anterior) e agenda refresh dos dados.
  ///
  /// Usa `addPostFrameCallback` para ler `GoRouterState.of(context)`
  /// APÓS a reconstrução do GoRouter (quando o InheritedWidget está
  /// atualizado). O listener do `routerDelegate` dispara durante
  /// `notifyListeners()` (antes da rebuild), então diferimos a leitura.
  void _onRouteChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentLocation = GoRouterState.of(context).uri.toString();
      final isHome = currentLocation == routePath;
      final wasDifferent = currentLocation != _lastLocation;
      if (isHome && wasDifferent) {
        onRouteRefresh();
      }
      _lastLocation = currentLocation;
    });
  }
}
