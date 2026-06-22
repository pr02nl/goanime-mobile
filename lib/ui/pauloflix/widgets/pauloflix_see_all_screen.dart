/// Tela "Ver Todos" do PauloFlix — grid de animes sincronizados do servidor.
///
/// A busca foi extraída para [PauloFlixSearchScreen] (acessada pelo
/// item "Buscar" da sidebar) para eliminar os problemas de foco do
/// `TVSafeTextField` embutido em listagem.
///
/// Suporte completo a D-pad com FocusTraversalGroup; sem `autofocus: true`
/// em cards para evitar race com o dispose de nodes do shell
/// (anti-pattern #19 do skill `flutter-reactivity-gotchas`).
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

          // Grid
          SliverToBoxAdapter(child: _ContentsGrid(contents: contents)),

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

// --- Grid simples (sem busca local; busca foi para PauloFlixSearchScreen) ---

class _ContentsGrid extends StatelessWidget {
  final List<PauloFlixContent> contents;

  const _ContentsGrid({required this.contents});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (width < Responsive.phoneMaxWidth) {
      crossAxisCount = 2;
    } else if (width < Responsive.tabletMaxWidth) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 6;
    }

    if (contents.isEmpty) {
      return const _EmptyState();
    }

    return FocusTraversalGroup(
      child: SizedBox(
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
            // Sem autofocus aqui: o shell já gerencia o foco inicial via
            // _contentScopeNode + _lastContentFocusNode, e autofocus em
            // um NetflixCard aninhado num FocusTraversalGroup sob um
            // FocusScope persistente causa corrida com o dispose do
            // node da rota anterior — disparando o assertion
            // "Focused child does not have the same idea of its
            // enclosing scope" no FocusScopeNode do shell.
            return _ContentCard(content: contents[index]);
          },
        ),
      ),
    );
  }

  double _calculateGridHeight(int itemCount, int crossAxisCount) {
    if (itemCount == 0) return 0;
    final rows = (itemCount / crossAxisCount).ceil();
    // Altura do card = largura / 0.65 (aspectRatio)
    // Espaçamento = 12 * (rows - 1)
    return (rows * 200.0) + ((rows - 1) * 12.0);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.tv_off,
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
          ],
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
    return NetflixCard(
      imageUrl: content.imageUrl ?? '',
      title: content.displayName,
      rating: content.score,
      width: double.infinity,
      height: double.infinity,
      isTV: true,
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
