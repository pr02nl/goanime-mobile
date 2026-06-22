import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/pauloflix_content.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/tv_safe_text_field.dart';
import '../view_models/pauloflix_provider.dart';

/// Tela de busca de animes PauloFlix.
///
/// Espelha o padrão de [PauloFlixMoviesSearchScreen] — extraída de
/// [PauloFlixSeeAllScreen] para eliminar os problemas de foco do
/// `TVSafeTextField` embutido em listagem (anti-pattern #16 do skill
/// `flutter-reactivity-gotchas`).
///
/// Por que tela dedicada:
/// 1. TextField consumia foco de teclado no desktop/d-pad sem liberar
///    (Esc não saía, setas viravam cursor de texto).
/// 2. Manter a busca em tela cheia permite navegação independente
///    dos cards de filtro/netflix/TV pattern.
/// 3. Filtro local sobre snapshot — não chama `provider.search()`
///    (anti-pattern #12: estado global da see-all ficaria sujo).
class PauloFlixSearchScreen extends StatefulWidget {
  const PauloFlixSearchScreen({super.key});

  /// Versão pura do filtro — exposta para testes.
  ///
  /// Critério: match em `displayName` (case-insensitive) OU em qualquer
  /// gênero (case-insensitive). Query vazia retorna a lista original
  /// (sem alocação nova).
  @visibleForTesting
  static List<PauloFlixContent> applyFilter(
    List<PauloFlixContent> contents,
    String query,
  ) {
    if (query.isEmpty) return contents;
    return contents.where((c) {
      return c.displayName.toLowerCase().contains(query) ||
          c.genres.any((g) => g.toLowerCase().contains(query));
    }).toList();
  }

  @override
  State<PauloFlixSearchScreen> createState() => _PauloFlixSearchScreenState();
}

class _PauloFlixSearchScreenState extends State<PauloFlixSearchScreen> {
  static const Color _accentColor = Color(0xFF6366F1);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'pauloflix-search',
  );
  final FocusNode _firstCardFocusNode = FocusNode(
    debugLabel: 'pauloflix-search.first-card',
  );

  /// Snapshot LOCAL dos animes PauloFlix no momento da entrada da tela.
  /// Filtro é feito sobre essa lista, não sobre o Provider.
  List<PauloFlixContent> _allContents = const [];
  List<PauloFlixContent> _filteredContents = const [];
  String _searchQuery = '';
  bool _isTV = false;
  bool _snapshotLoaded = false;

  /// Debounce trailing edge de 150ms para o filtro de busca: cada keystroke
  /// reagenda o `_applyFilter()` e só o último dispara a atualização do estado.
  Timer? _debounce;
  static const Duration _debounceDuration = Duration(milliseconds: 150);

  /// Hardware keyboard: instalado em initState, removido em dispose.
  bool _hardwareKeyboardHandlerInstalled = false;

  @override
  void initState() {
    super.initState();

    // Detecta TV + carrega snapshot local no primeiro frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Snapshot: copia os animes do provider no momento de entrada.
      // NUNCA chama provider.search() — isso filtrearia o estado global
      // e a see-all mostraria os resultados quando o usuário voltasse.
      final provider = context.read<PauloFlixProvider>();
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
        _allContents = List<PauloFlixContent>.from(contents);
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
  /// TextField (text editing) ou no NetflixCard focado.
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
  /// de 150ms.
  ///
  /// Casos especiais:
  /// - Se query é vazia, aplica IMEDIATAMENTE (sem esperar debounce).
  /// - [_clearSearch] chama [_applyFilter] direto pelo mesmo motivo.
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
  ///
  /// IMPORTANTE: este método NÃO chama `provider.search()` — todo o filtro
  /// é sobre a cópia local em `_allContents` (anti-pattern #12).
  void _applyFilter() {
    if (!mounted) return;
    final q = _searchController.text.toLowerCase().trim();
    _searchQuery = q;
    _filteredContents = PauloFlixSearchScreen.applyFilter(_allContents, q);
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
                hintText: 'Buscar anime...',
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
                    color: _accentColor,
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
                child: CircularProgressIndicator(color: _accentColor),
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
                      _isEmptyState() ? Icons.search_off : Icons.tv_off,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isEmptyState()
                          ? 'Nenhum resultado para "$_searchQuery"'
                          : 'Nenhum anime disponível',
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
                  // ao primeiro card por d-pad.
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

  /// Sem badge na busca — igual ao padrão de `PauloFlixMoviesSearchScreen`.
  /// O badge da home sinaliza origem do conteúdo; em tela de busca usamos
  /// só o card limpo para reduzir ruído visual.
  Widget _buildCard(BuildContext context, PauloFlixContent content) {
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
          'pauloflix-episodes',
          extra: content,
        );
      },
    );
  }
}
