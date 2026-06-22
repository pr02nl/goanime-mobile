import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/tv_safe_text_field.dart';
import '../view_models/pauloflix_movies_provider.dart';

/// Tela de busca de filmes PauloFlix.
///
/// **Padrão YouTube/Netflix**: tela inicia **vazia**, query no banco
/// (Drift) à medida que o usuário digita. Zero carga inicial de
/// dados em memória — funciona bem com milhares de filmes.
///
/// A busca é feita via `PauloFlixMoviesProvider.searchByName(query)`
/// (delega ao `PauloFlixMoviesRepository.searchByName` que faz
/// `LIKE + ESCAPE` no SQL puro).
///
/// **Foco**: `autofocus: true` no TextField é seguro aqui porque esta
/// tela está **fora do `ShellRoute`** (ver `app_router.dart:86-90`),
/// ou seja, o `FocusScope` persistente do shell
/// `MainNavigationScreen` não está presente. Sem risco do
/// anti-pattern #19 do skill `flutter-reactivity-gotchas`.
class PauloFlixMoviesSearchScreen extends StatefulWidget {
  const PauloFlixMoviesSearchScreen({super.key});

  @override
  State<PauloFlixMoviesSearchScreen> createState() =>
      _PauloFlixMoviesSearchScreenState();
}

class _PauloFlixMoviesSearchScreenState
    extends State<PauloFlixMoviesSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'pauloflix-movie-search',
  );
  final FocusNode _firstCardFocusNode = FocusNode(
    debugLabel: 'pauloflix-movie-search.first-card',
  );

  /// Resultados da query SQL. Tela inicia vazia (sem snapshot).
  List<PauloFlixMovie> _results = const [];
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isTV = false;

  /// Contador de geração: cada keystroke incrementa. Quando a busca
  /// assíncrona termina, descarta o resultado se uma busca mais nova
  /// já foi disparada (evita race de "iron" chegar depois de "iron man").
  int _searchGeneration = 0;

  /// Debounce trailing edge de 300ms para a busca no banco.
  /// Cada keystroke reagenda a busca; só o último dispara SQL.
  Timer? _debounce;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  /// Hardware keyboard: instalado em initState, removido em dispose.
  bool _hardwareKeyboardHandlerInstalled = false;

  @override
  void initState() {
    super.initState();
    // Detecta TV no primeiro frame (sem tocar provider/repo).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Detecta TV via PlatformDispatcher + TVDetector.
      final screenWidth =
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .physicalSize
              .width /
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
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

  /// Captura Esc globalmente → sai da tela de busca. Evita que o usuário
  /// fique preso no TextField (era o bug original do desktop).
  ///
  /// NÃO interceptamos space/setas/enter aqui — esses devem cair no
  /// TextField (text editing) ou no NetflixCard focado (já tem
  /// onKeyEvent nativo via CallbackShortcuts do MediaDesktopControls).
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

  /// Handler do `onChanged` do TextField. Implementa debounce trailing edge
  /// de 300ms.
  ///
  /// Casos especiais:
  /// - Se query é vazia, limpa IMEDIATAMENTE (sem esperar debounce).
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

  /// Executa a busca no banco (via provider) e atualiza o estado.
  /// Usa [_searchGeneration] para descartar resultados de buscas
  /// obsoletas (race com digitação rápida).
  Future<void> _performSearch(String query) async {
    final myGen = ++_searchGeneration;
    final provider = context.read<PauloFlixMoviesProvider>();
    final results = await provider.searchByName(query);
    if (!mounted) return;
    if (myGen != _searchGeneration) return; // busca mais nova já foi disparada
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

  bool _isIdleState() {
    return _searchQuery.isEmpty && !_isSearching;
  }

  bool _isEmptyResultState() {
    return !_isSearching &&
        _searchQuery.isNotEmpty &&
        _results.isEmpty;
  }

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
              // `autofocus: true` é SEGURO aqui — esta tela está
              // FORA do ShellRoute, então o FocusScope persistente
              // do shell `MainNavigationScreen` não está presente.
              // Sem risco do anti-pattern #19 (assertion no
              // _focusedChildren.last.enclosingScope).
              autofocus: true,
              downFocusNode: _firstCardFocusNode,
              onSubmitted: (_) {
                _searchFocusNode.unfocus();
                _firstCardFocusNode.requestFocus();
              },
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Buscar filme...',
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
                  borderSide: const BorderSide(
                    color: Color(0xFFDC2626),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Contador (só aparece depois que tem query)
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
                      'Digite para buscar filmes',
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
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFDC2626)),
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
                  final content = _results[index];
                  // Primeiro card recebe focusNode explícito para que o
                  // seta-para-baixo no campo de busca possa entregá-lo
                  // ao primeiro card por d-pad no futuro (já preparado).
                  final card = _buildCard(context, content);
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

  // Nota: a busca de filmes intencionalmente NÃO mostra badge
  // (PauloFlixMoviesBadge / CollectionBadge) — o badge da home sinaliza
  // origem do conteúdo e natureza (filme vs coleção); em tela de busca
  // usamos só o card limpo para reduzir ruído visual.
  Widget _buildCard(BuildContext context, PauloFlixMovie content) {
    return NetflixCard(
      imageUrl: content.imageUrl ?? '',
      title: content.displayName,
      rating: content.score,
      width: double.infinity,
      height: double.infinity,
      isTV: _isTV,
      showTitle: true,
      showRating: content.score != null,
      onTap: () {
        context.pushNamed(
          'pauloflix-movie-detail',
          extra: content,
        );
      },
    );
  }
}
