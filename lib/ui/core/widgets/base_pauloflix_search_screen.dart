import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/app_colors.dart';
import '../utils/responsive.dart';
import '../utils/tv_detector.dart';
import 'tv_safe_text_field.dart';

/// Tela de busca genérica para conteúdo PauloFlix (animes ou filmes).
///
/// Implementa o padrão YouTube/Netflix: tela inicia **vazia**, query no
/// banco (Drift) à medida que o usuário digita. Zero carga inicial de
/// dados em memória.
///
/// A busca é feita via [searchFunction] callback, permitindo reuso
/// tanto para `PauloFlixProvider.searchByName` quanto para
/// `PauloFlixMoviesProvider.searchByName`.
///
/// **Foco**: `autofocus: true` no TextField é seguro aqui porque esta
/// tela está **fora do `ShellRoute`**, ou seja, o `FocusScope`
/// persistente do shell `MainNavigationScreen` não está presente.
class BasePauloFlixSearchScreen<T> extends StatefulWidget {
  /// Placeholder do campo de texto (ex: "Buscar anime...").
  final String hintText;

  /// Texto exibido no estado ocioso (ex: "Digite para buscar animes").
  final String idleText;

  /// Cor do accent usada no bordo do TextField e no spinner.
  final Color accentColor;

  /// Rótulo para os FocusNode (debug). Deve ser único por instância.
  final String debugLabel;

  /// Callback que executa a busca. Recebe a query e o BuildContext
  /// (para acessar um Provider) e retorna a lista de resultados.
  final Future<List<T>> Function(String query, BuildContext context)
      searchFunction;

  /// Callback que constrói o card para cada item da lista.
  final Widget Function(BuildContext context, T item, bool isTV) cardBuilder;

  const BasePauloFlixSearchScreen({
    super.key,
    required this.hintText,
    required this.idleText,
    required this.accentColor,
    required this.debugLabel,
    required this.searchFunction,
    required this.cardBuilder,
  });

  @override
  State<BasePauloFlixSearchScreen<T>> createState() =>
      _BasePauloFlixSearchScreenState<T>();
}

class _BasePauloFlixSearchScreenState<T>
    extends State<BasePauloFlixSearchScreen<T>> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final FocusNode _firstCardFocusNode;

  List<T> _results = const [];
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isTV = false;
  int _searchGeneration = 0;
  Timer? _debounce;
  static const Duration _debounceDuration = Duration(milliseconds: 300);
  bool _hardwareKeyboardHandlerInstalled = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode(debugLabel: '${widget.debugLabel}-search');
    _firstCardFocusNode =
        FocusNode(debugLabel: '${widget.debugLabel}.first-card');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final screenWidth =
          WidgetsBinding.instance.platformDispatcher.views.first.physicalSize
              .width /
          WidgetsBinding.instance.platformDispatcher.views.first
              .devicePixelRatio;
      final isTvBuild = await TVDetector.isTV;
      if (!mounted) return;
      setState(() {
        _isTV = isTvBuild || screenWidth >= Responsive.tabletMaxWidth;
      });
    });

    _installHardwareKeyboardHandler();
  }

  @override
  void dispose() {
    _uninstallHardwareKeyboardHandler();
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _firstCardFocusNode.dispose();
    super.dispose();
  }

  void _installHardwareKeyboardHandler() {
    if (_hardwareKeyboardHandlerInstalled) return;
    _hardwareKeyboardHandlerInstalled = true;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  void _uninstallHardwareKeyboardHandler() {
    if (!_hardwareKeyboardHandlerInstalled) return;
    _hardwareKeyboardHandlerInstalled = false;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        return true;
      }
    }
    return false;
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      _debounce?.cancel();
      setState(() {
        _results = const [];
        _searchQuery = '';
        _isSearching = false;
      });
      return;
    }
    _debounce?.cancel();
    setState(() {
      _isSearching = true;
    });
    _debounce = Timer(_debounceDuration, () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    final myGen = ++_searchGeneration;
    final results = await widget.searchFunction(query, context);
    if (!mounted) return;
    if (myGen != _searchGeneration) return;
    setState(() {
      _results = results;
      _searchQuery = query.toLowerCase().trim();
      _isSearching = false;
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _searchFocusNode.requestFocus();
    setState(() {
      _results = const [];
      _searchQuery = '';
      _isSearching = false;
    });
  }

  bool _isIdleState() => _searchQuery.isEmpty && !_isSearching;

  bool _isEmptyResultState() =>
      !_isSearching && _searchQuery.isNotEmpty && _results.isEmpty;

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Responsive.phoneMaxWidth) return 2;
    if (width < Responsive.tabletMaxWidth) return 4;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: TVSafeTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              downFocusNode: _firstCardFocusNode,
              onSubmitted: (_) {
                _searchFocusNode.unfocus();
                _firstCardFocusNode.requestFocus();
              },
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.accentColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Contador de resultados
          if (_searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_results.length} '
                      '${_results.length == 1 ? "resultado" : "resultados"}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'filtro: "$_searchQuery"',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isIdleState())
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.idleText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else if (_isSearching)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child:
                    CircularProgressIndicator(color: widget.accentColor),
              ),
            )
          else if (_isEmptyResultState())
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum resultado para "$_searchQuery"',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = _results[index];
                  final card =
                      widget.cardBuilder(context, item, _isTV);
                  return index == 0
                      ? Focus(focusNode: _firstCardFocusNode, child: card)
                      : card;
                }, childCount: _results.length),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
