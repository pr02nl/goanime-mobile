/// Tela "Ver Todos" do PauloFlix — multi-seção estilo Netflix/YouTube.
///
/// Layout (top → bottom):
/// 1. AppBar pinned com badge "PauloFlix" + título "Animes" + botão sync
/// 2. Banner de progresso de sync (quando ativo)
/// 3. Hero banner (anime top-rated global)
/// 4. Carrossel "Mais Bem Avaliados" (top 12 por score)
/// 5. Carrosséis por gênero top 4 (≥3 animes por gênero)
/// 6. Grid paginado "Todos os Animes" com índice A–Z
///
/// A busca foi extraída para [PauloFlixSearchScreen] (acessada pelo
/// item "Buscar" da sidebar) para eliminar os problemas de foco do
/// `TVSafeTextField` embutido em listagem.
///
/// Toda a organização é feita em [initState] a partir de snapshot local
/// — NÃO chama `provider.search()` (anti-pattern #12 do skill
/// `flutter-reactivity-gotchas`).
///
/// Sem `autofocus: true` em cards (anti-pattern #19 — assertion no
/// FocusScope persistente do shell).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/pagination.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/netflix_carousel.dart';
import '../../core/widgets/paginated_letter_grid.dart';
import '../view_models/paulo_flix_continue_watching_viewmodel.dart';
import '../view_models/pauloflix_provider.dart';
import '_anime_hero_banner.dart';
import 'paulo_flix_continue_watching_section.dart';

class PauloFlixSeeAllScreen extends StatefulWidget {
  const PauloFlixSeeAllScreen({super.key});

  @override
  State<PauloFlixSeeAllScreen> createState() => _PauloFlixSeeAllScreenState();
}

class _PauloFlixSeeAllScreenState extends State<PauloFlixSeeAllScreen> {
  bool _checkedInitialSync = false;
  bool _isTV = false;

  // ─── Snapshot derivado (memoizado por hash do conteúdo) ─────────────
  List<PauloFlixContent> _allContents = const [];
  PaginationResult<PauloFlixContent> _pagination =
      const PaginationResult<PauloFlixContent>(
        pages: [],
        letterToPageIndex: {},
        availableLetters: [],
      );
  List<PauloFlixContent> _topRated = const [];
  Map<String, List<PauloFlixContent>> _byGenre = const {};
  PauloFlixContent? _featured;
  int _snapshotHash = 0;

  // Cor de destaque da seção: roxo PauloFlix Animes.
  static const Color _accentColor = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<PauloFlixProvider>();
      await provider.loadContents();
      if (!mounted) return;

      // Primeira abertura: banco vazio → sincronizar.
      if (!_checkedInitialSync) {
        _checkedInitialSync = true;
        if (provider.contents.isEmpty) {
          provider.syncContent();
        }
      }

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
      if (mounted) {
        setState(() {
          _isTV = isTvBuild || screenWidth >= Responsive.tabletMaxWidth;
        });
      }
    });
  }

  /// Memoiza o snapshot derivado. Recomputa apenas se o conteúdo mudou
  /// (medido por `length + identidade do primeiro/último item`).
  void _ensureSnapshotBuilt(List<PauloFlixContent> contents) {
    final newHash =
        contents.length ^
        (contents.isNotEmpty ? contents.first.hashCode : 0) ^
        (contents.isNotEmpty ? contents.last.hashCode : 0);
    if (newHash == _snapshotHash) return;
    _snapshotHash = newHash;

    // Cópia defensiva (anti-pattern #12).
    _allContents = List<PauloFlixContent>.from(contents);

    // 1. Hero — top-rated global.
    _featured = PauloFlixProvider.pickFeaturedContent(_allContents);

    // 2. Top rated (top 12 por score).
    _topRated = [..._allContents]
      ..sort((a, b) {
        final scoreCmp = (b.score ?? 0).compareTo(a.score ?? 0);
        if (scoreCmp != 0) return scoreCmp;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
    if (_topRated.length > 12) _topRated = _topRated.sublist(0, 12);

    // 3. Por gênero (top 4 com ≥3 animes).
    _byGenre = PauloFlixProvider.groupByTopGenres(
      _allContents,
      perGenre: 12,
      minPerGenre: 3,
    );

    // 4. Paginação (24/página).
    _pagination = PauloFlixProvider.paginateByLetter(_allContents, perPage: 24);
  }

  void _syncContent() {
    context.read<PauloFlixProvider>().syncContent();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<PauloFlixProvider>();
    final contents = provider.contents;
    final isSyncing = provider.isSyncing;

    // Memoiza as seções se o conteúdo mudou.
    _ensureSnapshotBuilt(contents);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(l10n, isSyncing),
          if (isSyncing && provider.syncProgress.isNotEmpty)
            _buildSyncBanner(provider),
          if (contents.isEmpty && isSyncing)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: _accentColor),
              ),
            )
          else if (contents.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            ..._buildContentSlivers(l10n),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers(AppLocalizations l10n) {
    final slivers = <Widget>[];

    // 0. Continue assistindo (Fase 5.3) — topo da See All.
    // Some automaticamente via `SizedBox.shrink()` quando vazia.
    slivers.add(SliverToBoxAdapter(child: _buildContinueWatchingSection()));

    // 1. Hero banner.
    if (_featured != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: AnimeHeroBanner(content: _featured!, isTV: _isTV),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    }

    // 2. Mais bem avaliados.
    if (_topRated.isNotEmpty) {
      final items = [
        ..._topRated.map(
          (anime) => NetflixCard(
            imageUrl: anime.imageUrl ?? '',
            title: anime.displayName,
            rating: anime.score,
            width: 140,
            height: 220,
            isTV: _isTV,
            onTap: () {
              context.pushNamed('pauloflix-episodes', extra: anime);
            },
          ),
        ),
      ];
      slivers.add(
        SliverToBoxAdapter(
          child: NetflixCarousel(
            title: l10n.sectionTopRated,
            height: 220,
            isTV: _isTV,
            items: items,
          ),
        ),
      );
    }

    // 3. Por gênero (apenas os 4 top com ≥3 animes).
    for (final entry in _byGenre.entries) {
      if (entry.value.length < 3) continue;
      final items = [
        ...entry.value.map(
          (anime) => NetflixCard(
            imageUrl: anime.imageUrl ?? '',
            title: anime.displayName,
            rating: anime.score,
            width: 140,
            height: 220,
            isTV: _isTV,
            onTap: () {
              context.pushNamed('pauloflix-episodes', extra: anime);
            },
          ),
        ),
      ];
      slivers.add(
        SliverToBoxAdapter(
          child: NetflixCarousel(
            title: entry.key,
            height: 220,
            isTV: _isTV,
            items: items,
          ),
        ),
      );
    }

    // 4. Grid paginado "Todos os Animes" com índice A–Z.
    slivers.add(SliverToBoxAdapter(child: _buildAllAnimesSection(l10n)));

    return slivers;
  }

  Widget _buildAllAnimesSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.tv, size: 22, color: _accentColor),
                const SizedBox(width: 8),
                Text(
                  '${l10n.sectionAllAnimes} (${_allContents.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PaginatedLetterGrid<PauloFlixContent>(
            pagination: _pagination,
            isTV: _isTV,
            accentColor: _accentColor,
            nameOf: (c) => c.displayName,
            cardBuilder: (context, content) {
              return NetflixCard(
                imageUrl: content.imageUrl ?? '',
                title: content.displayName,
                rating: content.score,
                width: 140,
                height: 220,
                isTV: _isTV,
                onTap: () {
                  context.pushNamed('pauloflix-episodes', extra: content);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── AppBar + Sync banner ──────────────────────────────────────────

  Widget _buildAppBar(AppLocalizations l10n, bool isSyncing) {
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
                color: _accentColor,
              ),
            ),
          )
        else
          FocusableWidget(
            onSelect: _syncContent,
            borderRadius: 24,
            focusPadding: EdgeInsets.zero,
            child: IconButton(
              icon: const Icon(Icons.sync),
              tooltip: l10n.sync,
              onPressed: _syncContent,
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 14),
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

  Widget _buildSyncBanner(PauloFlixProvider provider) {
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
                color: _accentColor,
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

  /// Fase 5.3 — Seção "Continue assistindo" no topo da See All.
  ///
  /// Encapsula o `ChangeNotifierProvider` + `Consumer` para que o
  /// `PauloFlixContinueWatchingViewModel` viva dentro do `SliverToBoxAdapter`
  /// e suma naturalmente quando vazio
  /// (`PauloFlixContinueWatchingSection` retorna `SizedBox.shrink()`).
  Widget _buildContinueWatchingSection() {
    return ChangeNotifierProvider<PauloFlixContinueWatchingViewModel>(
      create: (ctx) => PauloFlixContinueWatchingViewModel(
        repository: ctx.read<PauloFlixEpisodeProgressRepository>(),
      ),
      child: Consumer<PauloFlixContinueWatchingViewModel>(
        builder: (_, vm, _) {
          // Esconde enquanto carrega (evita flash de "vazio" antes do
          // primeiro evento do stream).
          if (vm.loading) return const SizedBox.shrink();
          return PauloFlixContinueWatchingSection(
            contents: vm.contents,
            isTV: _isTV,
            onContentTap: _onContinueWatchingTap,
          );
        },
      ),
    );
  }

  /// Abre a tela de episodes do anime clicado em "Continue assistindo".
  /// Usa o mesmo `pushNamed` do hero banner e dos cards da grid.
  void _onContinueWatchingTap(PauloFlixContent content) {
    context.pushNamed('pauloflix-episode-list', extra: content);
  }
}

// ─── Empty State ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.tv_off,
                color: Color(0xFF8B5CF6),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhum anime disponível',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Sincronize com o servidor para ver os animes disponíveis.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
