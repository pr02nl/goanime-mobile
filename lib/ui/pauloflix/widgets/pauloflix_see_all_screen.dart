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

import '../../../core/logger/app_logger.dart';
import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/paulo_flix_progress_stats.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_data.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/netflix_carousel.dart';
import '../../core/widgets/paginated_alphabetical_carousel.dart';
import '../../core/widgets/progress_overlay.dart';
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
  bool _isTV = false;

  // ─── Snapshot derivado (memoizado por hash do conteúdo) ─────────────
  List<PauloFlixContent> _allContents = const [];
  List<PauloFlixContent> _topRated = const [];
  Map<String, List<PauloFlixContent>> _byGenre = const {};
  PauloFlixContent? _featured;
  int _snapshotHash = 0;

  /// Mapa contentId → stats de progresso para todos os animes.
  /// Usado para overlays no grid e carrosséis.
  Map<int, PauloFlixProgressStats> _statsById = const {};

  // Cor de destaque da seção: roxo PauloFlix Animes.
  static const Color _accentColor = AppColors.animeAccent;

  /// Última localização conhecida para detectar retorno do player.
  String _lastLocation = '';

  /// Referência ao routerDelegate para add/remove listener em
  /// initState/dispose sem depender de GoRouter.of(context)
  /// (que não está disponível em dispose quando o widget já foi
  /// desmontado).
  late final Listenable _routerDelegate;

  @override
  void initState() {
    super.initState();

    // Captura a referência do routerDelegate em initState (quando
    // GoRouter.of(context) ainda funciona) para usar em dispose
    // (quando GoRouter.of(context) pode falhar porque o widget já
    // foi desmontado da árvore).
    _routerDelegate = GoRouter.of(context).routerDelegate;
    _routerDelegate.addListener(_onRouteChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<PauloFlixProvider>();
      await provider.loadContents();
      if (!mounted) return;

      // `loadContents()` chamou `notifyListeners()`, mas o rebuild do
      // widget (que popula `_allContents` via `_ensureSnapshotBuilt`)
      // só acontece no PRÓXIMO frame. Por isso, `_loadAllStats`
      // (que precisa de `_allContents` populado) deve ser chamado
      // num post-frame callback separado.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _loadAllStats();
        await _detectAndSetIsTV();
      });
    });
  }

  /// Detecta se o dispositivo é TV e ajusta `_isTV`.
  /// Extraído para método separado porque a lógica precisa rodar
  /// num post-frame callback ANINHADO (após `_loadAllStats()`).
  Future<void> _detectAndSetIsTV() async {
    if (!mounted) return;
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
  }

  /// Callback disparado quando o GoRouter notifica mudança de rota.
  /// Detecta quando voltamos do player (/pauloflix-see-all com
  /// localização diferente da anterior) e agenda refresh dos stats.
  ///
  /// Usa `addPostFrameCallback` para ler `GoRouterState.of(context)`
  /// APÓS a reconstrução do GoRouter (quando o InheritedWidget está
  /// atualizado). O listener do `routerDelegate` dispara durante
  /// `notifyListeners()` (antes da rebuild), então diferimos a leitura.
  ///
  /// Chama `_loadAllStats()` diretamente (sem delay) porque o save
  /// do progresso já foi iniciado em `_exitPlayer()` antes do `pop()`.
  void _onRouteChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentLocation = GoRouterState.of(context).uri.toString();
      final isHome = currentLocation == '/pauloflix-see-all';
      final wasDifferent = currentLocation != _lastLocation;
      if (isHome && wasDifferent) {
        _loadAllStats();
      }
      _lastLocation = currentLocation;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializa a localização atual APÓS o widget estar montado na
    // árvore de rota (GoRouterState.of(context) requer ModalRoute que
    // só está disponível em didChangeDependencies/build, não em initState).
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

  /// Carrega stats de progresso para todos os animes (usado para
  /// overlays nos cards do grid e carrosséis).
  /// Também tenta refresh do ContinueWatchingViewModel se disponível.
  Future<void> _loadAllStats() async {
    try {
      final repo = context.read<PauloFlixEpisodeProgressRepository>();
      final ids = _allContents.map((c) => c.id).whereType<int>().toList();
      if (ids.isEmpty) return;
      final stats = await repo.getProgressStatsForContents(ids);
      if (mounted) setState(() => _statsById = stats);
    } catch (e, st) {
      const AppLogger('SeeAllScreen').error('Erro ao carregar stats', e, st);
    }
  }

  /// Constrói o overlay de progresso para cards baseado nos stats.
  /// Badge ✓ verde se completo, barra roxa + "3/12" se em andamento.
  Widget? _buildProgressOverlay(PauloFlixContent content) {
    final id = content.id;
    if (id == null) return null;
    final stats = _statsById[id];
    if (stats == null) return null;

    final hasProgress =
        stats.isAnimeCompleted ||
        stats.isAnimeInProgress ||
        stats.completedEpisodes > 0;
    if (!hasProgress) return null;

    return ProgressOverlay.build(
      ratio: stats.progressRatio,
      isCompleted: stats.isAnimeCompleted,
      accentColor: _accentColor,
      fractionText: stats.totalEpisodes > 0
          ? '${stats.completedEpisodes}/${stats.totalEpisodes}'
          : null,
    );
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contents = context.select<PauloFlixProvider, List<PauloFlixContent>>(
      (p) => p.contents,
    );
    final isSyncing = context.select<PauloFlixProvider, bool>(
      (p) => p.isSyncing,
    );
    final syncProgress = context.select<PauloFlixProvider, String>(
      (p) => p.syncProgress,
    );

    // Memoiza as seções se o conteúdo mudou.
    _ensureSnapshotBuilt(contents);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          if (isSyncing && syncProgress.isNotEmpty)
            _buildSyncBanner(syncProgress),
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
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeightSync(context);
    final sectionHeight = cardHeight + 60;

    final slivers = <Widget>[];

    // 1. Hero banner.
    if (_featured != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: AnimeHeroBanner(content: _featured!, isTV: _isTV),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    }

    // 0. Continue assistindo (Fase 5.3) — topo da See All.
    // Some automaticamente via `SizedBox.shrink()` quando vazia.
    slivers.add(SliverToBoxAdapter(child: _buildContinueWatchingSection()));

    // 2. Mais bem avaliados.
    if (_topRated.isNotEmpty) {
      final items = [
        ..._topRated.map(
          (anime) => NetflixCard(
            imageUrl: anime.imageUrl ?? '',
            title: anime.displayName,
            rating: anime.score,
            width: cardWidth,
            height: cardHeight,
            isTV: _isTV,
            overlayWidget: _buildProgressOverlay(anime),
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
            height: sectionHeight,
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
            width: cardWidth,
            height: cardHeight,
            isTV: _isTV,
            overlayWidget: _buildProgressOverlay(anime),
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
            height: sectionHeight,
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
    final sorted = [..._allContents]
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeightSync(context);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: PaginatedAlphabeticalCarousel<PauloFlixContent>(
        title: '${l10n.sectionAllAnimes} (${_allContents.length})',
        items: sorted,
        isTV: _isTV,
        accentColor: _accentColor,
        cardBuilder: (context, content) {
          return NetflixCard(
            imageUrl: content.imageUrl ?? '',
            title: content.displayName,
            rating: content.score,
            width: cardWidth,
            height: cardHeight,
            isTV: _isTV,
            overlayWidget: _buildProgressOverlay(content),
            onTap: () {
              context.pushNamed('pauloflix-episodes', extra: content);
            },
          );
        },
      ),
    );
  }

  Widget _buildSyncBanner(String syncProgress) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.animeAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.animeAccent.withValues(alpha: 0.3),
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
                syncProgress,
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
  /// Encapsula o `ChangeNotifierProvider` + `_ContinueWatchingConsumer`
  /// (que usa `context.select` em vez de `Consumer` para evitar rebuilds
  /// desnecessários) para que o `PauloFlixContinueWatchingViewModel` viva
  /// dentro do `SliverToBoxAdapter` e suma naturalmente quando vazio.
  Widget _buildContinueWatchingSection() {
    return ChangeNotifierProvider<PauloFlixContinueWatchingViewModel>(
      create: (ctx) => PauloFlixContinueWatchingViewModel(
        repository: ctx.read<PauloFlixEpisodeProgressRepository>(),
      ),
      child: _ContinueWatchingConsumer(
        isTV: _isTV,
        onContentTap: _onContinueWatchingTap,
      ),
    );
  }

  /// Abre o player no episódio em progresso (último assistido não
  /// completo), incluindo a posição salva. O player lê o progresso
  /// do banco via [contentId + seasonId + episodeNumber].
  ///
  /// Se não houver episódio em progresso, fallback para a lista de
  /// episódios completa.
  Future<void> _onContinueWatchingTap(PauloFlixContent content) async {
    final isWide =
        MediaQuery.of(context).size.width >= Responsive.phoneMaxWidth;
    if (!isWide || content.id == null) {
      if (!mounted) return;
      context.pushNamed('pauloflix-episodes', extra: content);
      return;
    }

    final repo = context.read<PauloFlixEpisodeProgressRepository>();
    final episode = await repo.getLatestInProgressEpisodeForContent(
      content.id!,
    );

    if (episode == null) {
      if (!mounted) return;
      context.pushNamed('pauloflix-episodes', extra: content);
      return;
    }

    final allEpisodes = await repo.getEpisodesForSeason(episode.seasonId);
    final idx = allEpisodes.indexWhere(
      (e) => e.episodeNumber == episode.episodeNumber,
    );
    final episodeIndex = idx >= 0 ? idx : 0;

    // Busca seasonNumber para o TheIntroDB.
    final seasons = await repo.getSeasonsForContent(content.id!);
    final currentSeason = seasons.isEmpty
        ? null
        : seasons.firstWhere(
            (s) => s.id == episode.seasonId,
            orElse: () => seasons.first,
          );

    final episodeList = allEpisodes
        .map(
          (e) => Episode(
            number: e.episodeNumber.toString(),
            url: e.videoUrl,
            title: e.title,
            thumbnailUrl: e.thumbnailUrl,
          ),
        )
        .toList();

    if (!mounted) return;
    context.pushNamed(
      'player',
      extra: PlayerRouteData(
        episode: episodeList[episodeIndex],
        animeTitle: content.displayName,
        anime: Anime(
          name: content.displayName,
          url: content.serverUrl,
          source: AnimeSource.pauloFlix,
          fallbackImageUrl: content.imageUrl,
        ),
        isMovie: false,
        episodeList: episodeList,
        episodeIndex: episodeIndex,
        contentId: content.id,
        seasonId: episode.seasonId,
        episodeNumber: episode.episodeNumber.toString(),
        tmdbId: content.tmdbId,
        seasonNumber: currentSeason?.seasonNumber,
      ),
    );
  }
}

// ─── Continue Watching Consumer ──────────────────────────────────────

/// Substitui `Consumer<PauloFlixContinueWatchingViewModel>` por
/// `context.select` para evitar rebuilds desnecessários.
///
/// Cada propriedade (`loading`, `contents`, `statsById`) é selecionada
/// independentemente, então mudanças em `statsById` (carregadas após
/// a lista) não reconstroem a seção inteira.
class _ContinueWatchingConsumer extends StatelessWidget {
  final bool isTV;
  final void Function(PauloFlixContent content)? onContentTap;

  const _ContinueWatchingConsumer({required this.isTV, this.onContentTap});

  @override
  Widget build(BuildContext context) {
    final loading = context.select<PauloFlixContinueWatchingViewModel, bool>(
      (vm) => vm.loading,
    );
    // Esconde enquanto carrega (evita flash de "vazio" antes do
    // primeiro evento do stream).
    if (loading) return const SizedBox.shrink();

    final contents = context
        .select<PauloFlixContinueWatchingViewModel, List<PauloFlixContent>>(
          (vm) => vm.contents,
        );
    final statsById = context
        .select<
          PauloFlixContinueWatchingViewModel,
          Map<int, PauloFlixProgressStats>
        >((vm) => vm.statsById);

    return PauloFlixContinueWatchingSection(
      contents: contents,
      statsById: statsById,
      isTV: isTV,
      onContentTap: onContentTap,
    );
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
                color: AppColors.animeAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.animeAccent.withValues(alpha: 0.3),
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
