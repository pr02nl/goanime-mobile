import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/models/pauloflix_movie.dart';
import '../providers/pauloflix_movies_provider.dart';
import '../ui/core/themes/app_colors.dart';
import '../ui/core/utils/responsive.dart';
import '../ui/core/utils/tv_detector.dart';
import '../ui/core/widgets/netflix_card.dart';
import '../ui/core/widgets/tv_safe_text_field.dart';
import 'pauloflix_movie_detail_screen.dart';

/// Tela de busca de filmes PauloFlix.
///
/// Substitui o TextField que ficava embutido em
/// [PauloFlixMoviesHomeScreen]. Foi extraída para uma tela dedicada porque:
/// 1. O TextField consumia foco de teclado no desktop/d-pad sem liberar
///    (Escape não saía, Tab era o único caminho livre).
/// 2. Manter a busca em tela cheia permite que o resultado seja navegável
///    de forma independente (Netflix/YouTube pattern).
/// 3. A lógica de Provider é global — filtrar localmente nesta tela evita
///    que o estado da home-screen fique turbinado com filtro de busca.
///
/// O snapshot local de [_allContents] garante que mudanças feitas no Provider
/// em outras telas (sync de filmes, etc.) não perturbem a busca já em curso.
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

  // Snapshot LOCAL dos filmes PauloFlix no momento da entrada da tela.
  // Filtro é feito sobre essa lista, não sobre o Provider.
  List<PauloFlixMovie> _allContents = const [];
  List<PauloFlixMovie> _filteredContents = const [];
  String _searchQuery = '';
  bool _isTV = false;
  bool _snapshotLoaded = false;

  // Debounce trailing edge de 150ms para o filtro de busca: cada keystroke
  // reagenda o _applyFilter() e só o último dispara a atualização do estado.
  // Custo do filtro é O(n) sobre snapshot local em memória (microssegundos),
  // mas o debounce padroniza o ritmo da UI em teclado físico (cada tecla é
  // ~30–80ms no desktop) e deixa espaço para instrumentação futura sem
  // precisar refatorar.
  Timer? _debounce;
  static const Duration _debounceDuration = Duration(milliseconds: 150);

  // Hardware keyboard: instalado em initState, removido em dispose.
  bool _hardwareKeyboardHandlerInstalled = false;

  @override
  void initState() {
    super.initState();

    // Detecta TV + carrega snapshot local no primeiro frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Snapshot: copia os filmes do provider no momento de entrada.
      // NUNCA chama provider.search() — isso filtrearia o estado global
      // e a home-screen mostraria os resultados quando o usuário voltasse.
      final provider = context.read<PauloFlixMoviesProvider>();
      final contents = provider.contents;

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
        _allContents = List<PauloFlixMovie>.from(contents);
        _filteredContents = _allContents;
        _isTV = isTvBuild || screenWidth >= Responsive.tabletMaxWidth;
        _snapshotLoaded = true;
      });

      // Auto-foco no campo de busca para o teclado ficar pronto imediatamente.
      _searchFocusNode.requestFocus();
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
  /// de 150ms:
  ///
  /// 1. Cada keystroke CANCELA o timer anterior.
  /// 2. Agenda novo timer que, ao disparar, chama [_applyFilter] com o
  ///    valor ATUAL do `_searchController.text` (não a String capturada
  ///    no handler — isso é importante para digitações rápidas).
  ///
  /// Casos especiais:
  /// - Se query é vazia, aplica IMEDIATAMENTE (sem esperar debounce).
  ///   UX: ao limpar campo, lista volta completo sem delay perceptível.
  /// - [_clearSearch] chama [_applyFilter] direto para o mesmo motivo.
  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      // Limpar/empty → aplica já, sem debounce.
      _debounce?.cancel();
      _searchQuery = '';
      _filteredContents = _allContents;
      setState(() {});
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, _applyFilter);
  }

  /// Aplica o filtro sobre o snapshot local. Chamado pelo debounce timer
  /// ou diretamente por [_clearSearch].
  void _applyFilter() {
    if (!mounted) return;
    final q = _searchController.text.toLowerCase().trim();
    _searchQuery = q;
    _filteredContents = _allContents.where((c) {
      return c.displayName.toLowerCase().contains(q) ||
          c.genres.any((g) => g.toLowerCase().contains(q));
    }).toList();
    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _searchFocusNode.requestFocus();
    _searchQuery = '';
    _filteredContents = _allContents;
    setState(() {});
  }

  bool _isEmptyState() {
    return _snapshotLoaded &&
        _searchQuery.isNotEmpty &&
        _filteredContents.isEmpty;
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

          // Contador
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredContents.length} '
                    '${_filteredContents.length == 1 ? "resultado" : "resultados"}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
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

          if (!_snapshotLoaded)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFDC2626)),
              ),
            )
          else if (_filteredContents.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isEmptyState() ? Icons.search_off : Icons.movie_outlined,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isEmptyState()
                          ? 'Nenhum resultado para "$_searchQuery"'
                          : 'Nenhum filme disponível',
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
                  final content = _filteredContents[index];
                  // Primeiro card recebe focusNode explícito para que o
                  // seta-para-baixo no campo de busca possa entregá-lo
                  // ao primeiro card por d-pad no futuro (já preparado).
                  final card = _buildCard(context, content);
                  return index == 0
                      ? Focus(focusNode: _firstCardFocusNode, child: card)
                      : card;
                }, childCount: _filteredContents.length),
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PauloFlixMovieDetailScreen(content: content),
          ),
        );
      },
    );
  }
}
