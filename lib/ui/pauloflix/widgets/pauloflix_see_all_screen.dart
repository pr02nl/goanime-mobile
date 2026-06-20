/// Tela "Ver Todos" do PauloFlix — grid com busca e sincronização.
///
/// Reutiliza o PauloFlixProvider existente para dados e busca.
/// Usa TVDetector direto para detecção de TV (sem setState).
/// Suporte completo a D-pad com FocusTraversalGroup.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/pauloflix_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/pauloflix_badge.dart';
import '../../core/widgets/tv_safe_text_field.dart';
import '../view_models/pauloflix_provider.dart';
import 'pauloflix_episode_list_screen.dart';

class PauloFlixSeeAllScreen extends StatelessWidget {
  const PauloFlixSeeAllScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<PauloFlixProvider>();
    final contents = provider.contents;
    final isSyncing = provider.isSyncing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // AppBar
          _buildAppBar(context, l10n, isSyncing, provider),

          // Sync Progress
          if (isSyncing) _buildSyncProgress(provider),

          // Search Bar + Grid com FocusTraversalGroup
          SliverToBoxAdapter(
            child: _SearchBarWithGrid(contents: contents),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    bool isSyncing,
    PauloFlixProvider provider,
  ) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: AppColors.background,
      actions: [
        if (isSyncing)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF6366F1),
              ),
            ),
          )
        else
          FocusableWidget(
            onSelect: provider.syncContent,
            borderRadius: 24,
            focusPadding: EdgeInsets.zero,
            child: IconButton(
              icon: const Icon(Icons.sync),
              tooltip: l10n.sync,
              onPressed: provider.syncContent,
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.dns, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
            const Text(
              'PauloFlix',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgress(PauloFlixProvider provider) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                provider.syncProgress,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Search Bar + Grid com FocusTraversalGroup ---

class _SearchBarWithGrid extends StatefulWidget {
  final List<PauloFlixContent> contents;

  const _SearchBarWithGrid({required this.contents});

  @override
  State<_SearchBarWithGrid> createState() => _SearchBarWithGridState();
}

class _SearchBarWithGridState extends State<_SearchBarWithGrid> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    setState(() => _query = query);
    context.read<PauloFlixProvider>().search(query);
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  List<PauloFlixContent> get _filteredContents {
    if (_query.isEmpty) return widget.contents;
    return widget.contents
        .where(
          (c) =>
              c.displayName.toLowerCase().contains(_query.toLowerCase()) ||
              c.genres.any(
                (g) => g.toLowerCase().contains(_query.toLowerCase()),
              ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final contents = _filteredContents;
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (width < Responsive.phoneMaxWidth) {
      crossAxisCount = 2;
    } else if (width < Responsive.tabletMaxWidth) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 6;
    }

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TVSafeTextField(
              controller: _controller,
              onChanged: _onChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar anime...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: _clear,
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
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
          ),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${contents.length} anime${contents.length != 1 ? 's' : ''} encontrado${contents.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Grid or Empty State
          if (contents.isEmpty)
            _buildEmptyState()
          else
            _buildGrid(contents, crossAxisCount),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              color: Colors.white.withValues(alpha: 0.3),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _query.isNotEmpty
                  ? 'Nenhum resultado para "$_query"'
                  : 'Nenhum conteúdo disponível',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<PauloFlixContent> contents, int crossAxisCount) {
    return SizedBox(
      height: _calculateGridHeight(contents.length, crossAxisCount),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: contents.length,
        itemBuilder: (context, index) {
          return _ContentCard(
            content: contents[index],
            autofocus: index == 0, // Autofoco no primeiro card
          );
        },
      ),
    );
  }

  double _calculateGridHeight(int itemCount, int crossAxisCount) {
    if (itemCount == 0) return 0;
    final rows = (itemCount / crossAxisCount).ceil();
    // Altura do card = largura / 0.65 (aspectRatio)
    // Espaçamento = 12 * (rows - 1)
    return (rows * 200.0) + ((rows - 1) * 12.0); // 200 ≈ card height estimada
  }
}

// --- Content Card ---

class _ContentCard extends StatelessWidget {
  final PauloFlixContent content;
  final bool autofocus;

  const _ContentCard({
    required this.content,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return NetflixCard(
      imageUrl: content.imageUrl ?? '',
      title: content.displayName,
      rating: content.score,
      width: double.infinity,
      height: double.infinity,
      isTV: true,
      autofocus: autofocus,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PauloFlixEpisodeListScreen(content: content),
          ),
        );
      },
      overlayWidget: const PauloFlixBadge(),
    );
  }
}
