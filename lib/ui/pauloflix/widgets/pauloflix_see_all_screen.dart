/// Tela "Ver Todos" do PauloFlix — grid com busca e sincronização.
///
/// Reutiliza o PauloFlixProvider existente para dados e busca.
/// Usa TVDetector direto para detecção de TV (sem setState).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/pauloflix_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/responsive.dart';
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

          // Search Bar
          const SliverToBoxAdapter(child: _SearchBar()),

          // Results Count
          SliverToBoxAdapter(child: _ResultsCount(count: contents.length)),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Grid or Empty State
          if (contents.isEmpty)
            _buildEmptyState(context, l10n, isSyncing)
          else
            _buildGrid(context, contents),

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
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: l10n.sync,
            onPressed: provider.syncContent,
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

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    bool isSyncing,
  ) {
    return SliverFillRemaining(
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
              'Nenhum conteúdo disponível',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
            if (!isSyncing) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<PauloFlixProvider>().syncContent(),
                icon: const Icon(Icons.sync),
                label: Text(l10n.syncContent),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<PauloFlixContent> contents) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (width < Responsive.phoneMaxWidth) {
      crossAxisCount = 2;
    } else if (width < Responsive.tabletMaxWidth) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 6;
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final content = contents[index];
          return _ContentCard(content: content);
        }, childCount: contents.length),
      ),
    );
  }
}

// --- Search Bar (StatefulWidget para controller) ---

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TVSafeTextField(
        controller: _controller,
        onChanged: _onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar anime...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.5),
          ),
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
    );
  }
}

// --- Results Count ---

class _ResultsCount extends StatelessWidget {
  final int count;

  const _ResultsCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '$count anime${count != 1 ? 's' : ''} encontrado${count != 1 ? 's' : ''}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
    );
  }
}

// --- Content Card ---

class _ContentCard extends StatelessWidget {
  final PauloFlixContent content;

  const _ContentCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeightSync(context);

    return NetflixCard(
      imageUrl: content.imageUrl ?? '',
      title: content.displayName,
      rating: content.score,
      width: cardWidth,
      height: cardHeight,
      isTV: true, // TVDetector é estático, pode usar TVDetector.isTV
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
