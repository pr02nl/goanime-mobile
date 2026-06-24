/// Tela de lista de episódios do PauloFlix no estilo Netflix.
///
/// Exibe hero banner, seletor de temporadas horizontal e cards de episódio
/// com thumbnail. Usa ViewModel para gerenciamento de estado.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/services/paulo_flix_episode_sync_service.dart';
import '../../../domain/models/anime.dart';
import '../../../domain/models/episode.dart';
import '../../../domain/models/pauloflix_content.dart';
import '../../../domain/repositories/paulo_flix_episode_progress_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routing/route_data.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../core/widgets/pauloflix_badge.dart';
import '../view_models/paulo_flix_episode_progress_viewmodel.dart';
import 'pauloflix_episode_card.dart';
import 'pauloflix_season_selector.dart';

class PauloFlixEpisodeListScreen extends StatelessWidget {
  final PauloFlixContent content;

  const PauloFlixEpisodeListScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // IMPORTANTE: `context.read<...>()` precisa do `BuildContext` do
      // `MultiProvider` global, NÃO do `PauloFlixEpisodeListScreen`.
      // O `create:` callback recebe um `BuildContext` ancorado no
      // widget acima deste `ChangeNotifierProvider` — esse `context`
      // tem acesso ao `PauloFlixEpisodeProgressRepository` e
      // `PauloFlixEpisodeSyncService` declarados em `app.dart`.
      //
      // Se movêssemos o `context.read<...>()` para FORA do callback
      // (no `build` direto), o Flutter lançaria `ProviderNotFoundException`
      // porque esse `context` é ancestral do provider que estamos
      // criando (ver doc do package:provider).
      create: (ctx) => PauloFlixEpisodeProgressViewModel(
        content: content,
        repository: ctx.read<PauloFlixEpisodeProgressRepository>(),
        syncService: ctx.read<PauloFlixEpisodeSyncService>(),
      )..loadSeasons(),
      child: const _PauloFlixEpisodeListView(),
    );
  }
}

class _PauloFlixEpisodeListView extends StatelessWidget {
  const _PauloFlixEpisodeListView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PauloFlixEpisodeProgressViewModel>();
    final isTV = MediaQuery.of(context).size.width > 1200;

    return Scaffold(
      backgroundColor: AppColors.background,
      // AppBar dedicada (NÃO `SliverAppBar` colapsável) para que o
      // botão back fique sempre presente e o foco não dependa do
      // estado de scroll.
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          vm.content.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Hero Banner — SliverToBoxAdapter com altura fixa.
          // Substitui a antiga SliverAppBar colapsável que sumia com
          // o foco ao rolar (FlexibleSpaceBar.enlarge não estava
          // expondo nenhum nó focável depois do colapso).
          SliverToBoxAdapter(
            child: _HeroBanner(content: vm.content),
          ),

          // Info Panel
          SliverToBoxAdapter(child: _InfoPanel(content: vm.content)),

          // Season Selector — SEM `FocusTraversalGroup`. O traversal
          // default do Flutter + a `ListView` horizontal do widget já
          // dão a navegação esperada: ←/→ entre pills, ↑/↓ saem do
          // widget normalmente (sobe para o hero/Assistir, ou desce
          // para a lista de episódios). Envolver em um grupo próprio
          // com política custom prende o foco (bug da iteração
          // anterior: usuário não conseguia sair do selector com ↑/↓).
          if (!vm.isLoading && vm.hasSeasons)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: PauloflixSeasonSelector(
                  seasons: vm.scrapingSeasons,
                  selectedIndex: vm.selectedSeasonIndex,
                  onSeasonSelected: (index) => vm.selectSeason(index),
                  isCompletedByIndex: vm.isCompletedByIndex,
                ),
              ),
            ),

          // Content States
          if (vm.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (vm.errorMessage != null)
            SliverFillRemaining(child: _ErrorState(errorMessage: vm.errorMessage!))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _EpisodesList(isTV: isTV),
            ),

          // Padding final para garantir que o último episódio não fica
          // colado no fim da tela (e que o traversal para baixo do
          // último card tem "respiro" antes do SliverFillRemaining).
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// --- Hero Banner ---

class _HeroBanner extends StatelessWidget {
  final PauloFlixContent content;

  const _HeroBanner({required this.content});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PauloFlixEpisodeProgressViewModel>();
    final isTV = MediaQuery.of(context).size.width > 1200;
    final heroHeight = isTV ? 350.0 : 280.0;

    // Container de altura fixa (NÃO `SliverAppBar` colapsável). O
    // título do anime já é mostrado na `AppBar` da Scaffold pai, então
    // aqui exibimos apenas a arte + gradientes + botão "Assistir".
    // O `_HeroBanner` agora é um widget comum (sem `SliverAppBar`), e
    // o `SliverToBoxAdapter` que o contém garante que ele é renderizado
    // como um bloco normal do `CustomScrollView` — o foco do botão
    // "Assistir" não depende mais do estado de scroll.
    //
    // Imagem: prioriza `content.bannerUrl` (capa do anime), com
    // fallback para `season.fanart.jpg` (capa por season). Quando o
    // user troca de season, o hero atualiza (Provider notifica).
    final heroUrl = vm.selectedSeasonHeroUrl;
    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner Image
          if (heroUrl != null)
            Image.network(
              heroUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            )
          else
            _buildFallback(),

          // Gradient Top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Gradient Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 150,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.background],
                ),
              ),
            ),
          ),

          // Play Button
          if (vm.hasSeasons)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: FocusableWidget(
                  onSelect: () {
                    final episodes = vm.episodes;
                    if (episodes.isNotEmpty) {
                      _playEpisode(context, episodes.first, 0);
                    }
                  },
                  borderRadius: 30,
                  focusPadding: EdgeInsets.zero,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Assistir',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white12, size: 80),
      ),
    );
  }

  void _playEpisode(BuildContext context, dynamic episode, int index) {
    final vm = context.read<PauloFlixEpisodeProgressViewModel>();
    // Mapeia `PauloFlixEpisodeRecord` (banco) → `Episode` (player).
    // Os campos `positionSeconds`/`isCompleted` ficam no record
    // (acessíveis por `vm.episodes[index]`), mas o player consome
    // só o `Episode` legacy — o service do player lê do banco via
    // `seasonId`+`episodeNumber`.
    final selectedSeason = vm.selectedSeason;
    final seasonId = selectedSeason?.id;
    final records = vm.episodes;
    final scrapings = vm.scrapingEpisodesForSelected;
    final episodes = <Episode>[
      for (var i = 0; i < records.length; i++)
        Episode(
          number: scrapings[i].number.toString(),
          url: scrapings[i].url,
          title: records[i].title,
          thumbnailUrl: scrapings[i].thumbnailUrl,
        ),
    ];

    context.pushNamed(
      'player',
      extra: PlayerRouteData(
        episode: episodes[index],
        animeTitle: vm.content.displayName,
        anime: Anime(
          name: vm.content.displayName,
          url: vm.content.serverUrl,
          source: AnimeSource.pauloFlix,
          fallbackImageUrl: vm.content.imageUrl,
        ),
        isMovie: false,
        episodeList: episodes,
        episodeIndex: index,
        contentId: vm.content.id,
        seasonId: seasonId,
        episodeNumber: records[index].episodeNumber.toString(),
      ),
    );
  }
}

// --- Info Panel ---

class _InfoPanel extends StatelessWidget {
  final PauloFlixContent content;

  const _InfoPanel({required this.content});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PauloFlixEpisodeProgressViewModel>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges Row
          Row(
            children: [
              const PauloFlixBadge(),
              if (content.score != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        content.score!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (vm.hasSeasons) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${vm.seasons.length} ${vm.seasons.length == 1 ? 'temporada' : 'temporadas'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),

          // Descrição
          if (content.description != null) ...[
            const SizedBox(height: 12),
            Text(
              content.description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Gêneros
          if (content.genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: content.genres
                  .take(5)
                  .map(
                    (genre) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        genre,
                        style: const TextStyle(color: AppColors.primary, fontSize: 11),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Error State ---

class _ErrorState extends StatelessWidget {
  final String errorMessage;

  const _ErrorState({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = context.read<PauloFlixEpisodeProgressViewModel>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FocusableWidget(
              onSelect: vm.refresh,
              borderRadius: 8,
              child: ElevatedButton.icon(
                onPressed: vm.refresh,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Episodes List ---

class _EpisodesList extends StatelessWidget {
  final bool isTV;

  const _EpisodesList({required this.isTV});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PauloFlixEpisodeProgressViewModel>();

    // Empty (episodes são reativos via watch stream — sem loading/error
    // explícitos; o VM carrega via `loadSeasons` que tem seu próprio
    // estado de loading).
    if (vm.episodes.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 48, color: Colors.white24),
              SizedBox(height: 12),
              Text('Nenhum episódio encontrado', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    // Episodes — envelopados em `FocusTraversalGroup` com
    // `_VerticalClampedTraversalPolicy` para clamp vertical:
    // ↑ no primeiro card = no-op (mantém foco ali), ↓ no último
    // card = no-op. Horizontal delega ao default.
    //
    // Por que `SliverToBoxAdapter` + `Column` em vez de `SliverList`:
    // o Flutter NÃO fornece `SliverFocusTraversalGroup` na API
    // pública (apenas `FocusTraversalGroup` para árvore de widgets
    // comuns). `SliverMainAxisGroup` aceita outros slivers mas não
    // envelopa com `FocusTraversalGroup`. Para aplicar a política
    // de traversal à lista inteira, precisamos que os `FocusNode`s
    // dos cards sejam descendentes diretos de um `FocusTraversalGroup`
    // na árvore de widgets — não dá para "saltar" o `SliverList` que
    // virtualiza filhos. A `Column` dentro de um `SliverToBoxAdapter`
    // garante que todos os cards estão materializados (sem
    // virtualização). Para listas de episódios (tipicamente < 50
    // itens) o custo é aceitável e a previsibilidade de foco é o
    // requisito de TV mais crítico.
    //
    // Por que resolve o bug original: sem o grupo, ao pressionar ↑
    // no primeiro card o traversal default saía do `SliverList` e
    // ia procurar descendentes focáveis na vertical acima. Como a
    // antiga `SliverAppBar` colapsável (e a atual `AppBar`) não têm
    // nó focável vizinho, o foco caía no botão back do route. Com o
    // clamp, ↑ no 1º card = fica no 1º card.
    final season = vm.selectedSeason;
    final records = vm.episodes;
    final scrapings = vm.scrapingEpisodesForSelected;
    return SliverToBoxAdapter(
      child: FocusTraversalGroup(
        policy: _VerticalClampedTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < records.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == records.length - 1 ? 0 : 8,
                ),
                child: PauloflixEpisodeCard(
                  episode: scrapings[index],
                  seasonNumber: season?.seasonNumber ?? 1,
                  positionSeconds: records[index].positionSeconds,
                  durationSeconds: records[index].durationSeconds,
                  isCompleted: records[index].isCompleted,
                  isTV: isTV,
                  onTap: () => _playEpisode(context, records[index], index),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _playEpisode(BuildContext context, dynamic episode, int index) {
    final vm = context.read<PauloFlixEpisodeProgressViewModel>();
    // Mapeia `PauloFlixEpisodeRecord` (banco) → `Episode` (player).
    // Os campos `positionSeconds`/`isCompleted` ficam no record
    // (acessíveis por `vm.episodes[index]`), mas o player consome
    // só o `Episode` legacy — o service do player lê do banco via
    // `seasonId`+`episodeNumber`.
    final selectedSeason = vm.selectedSeason;
    final seasonId = selectedSeason?.id;
    final records = vm.episodes;
    final scrapings = vm.scrapingEpisodesForSelected;
    final episodes = <Episode>[
      for (var i = 0; i < records.length; i++)
        Episode(
          number: scrapings[i].number.toString(),
          url: scrapings[i].url,
          title: records[i].title,
          thumbnailUrl: scrapings[i].thumbnailUrl,
        ),
    ];

    context.pushNamed(
      'player',
      extra: PlayerRouteData(
        episode: episodes[index],
        animeTitle: vm.content.displayName,
        anime: Anime(
          name: vm.content.displayName,
          url: vm.content.serverUrl,
          source: AnimeSource.pauloFlix,
          fallbackImageUrl: vm.content.imageUrl,
        ),
        isMovie: false,
        episodeList: episodes,
        episodeIndex: index,
        contentId: vm.content.id,
        seasonId: seasonId,
        episodeNumber: records[index].episodeNumber.toString(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Focus traversal policies
// ─────────────────────────────────────────────────────────────────────────────

/// Política de travessia usada pela lista vertical de episódios.
///
/// **Objetivo:** controlar APENAS a borda INFERIOR do grupo. A
/// borda SUPERIOR é deixada aberta (delega ao `super.inDirection`),
/// para que ↑ no primeiro card suba normalmente para o widget
/// acima (season selector → hero/Assistir → AppBar).
///
/// **Comportamento:**
/// - ↑/↓ DENTRO do grupo → navega para o próximo/anterior card.
/// - ↓ no ÚLTIMO card → clamp (mantém foco no último). É a única
///   direção que prendemos, porque abaixo da lista não há nenhum
///   widget focável (o `SliverFillRemaining` não tem nó focável) e
///   o traversal default pularia para o botão back do `Navigator`.
/// - ↑ no PRIMEIRO card → `super.inDirection` (delega, sai do grupo).
///   Isso permite que o usuário suba para o season selector com ↑.
/// - ←/→ → `super.inDirection` (não prendemos horizontal).
///
/// **Como identificamos o "primeiro" e "último":** pela posição
/// `rect.center.dy` dos descendentes focáveis do scope (cards
/// empilhados na `Column` têm `dy` crescentes de cima para baixo).
class _VerticalClampedTraversalPolicy extends WidgetOrderTraversalPolicy {
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (direction == TraversalDirection.down) {
      return _handleDown(currentNode);
    }
    // ↑, ←, → → delega ao default (sobe do 1º card, navega lateral).
    return super.inDirection(currentNode, direction);
  }

  bool _handleDown(FocusNode currentNode) {
    final scope = currentNode.nearestScope!;
    final FocusNode? focusedChild = scope.focusedChild;
    if (focusedChild == null) return false;

    // Filtra descendentes focáveis que compartilham overlap horizontal
    // com o nó focado (heurística para selecionar os cards da mesma
    // coluna).
    final List<FocusNode> columnNodes = scope.traversalDescendants
        .where(
          (FocusNode n) =>
              n.canRequestFocus &&
              !n.skipTraversal &&
              n.context != null &&
              _sameColumn(n, focusedChild),
        )
        .toList();

    if (columnNodes.isEmpty) return false;

    // Ordena por posição vertical (cima para baixo).
    columnNodes.sort((a, b) => a.rect.center.dy.compareTo(b.rect.center.dy));

    final int idx = columnNodes.indexOf(focusedChild);
    if (idx < 0) return false;

    if (idx < columnNodes.length - 1) {
      // Não é o último — segue para o próximo.
      _requestFocusInDirection(columnNodes[idx + 1]);
    } else {
      // Clamp: mantém foco no último card (no-op).
      _requestFocusInDirection(focusedChild);
    }
    return true;
  }

  /// Verifica se [node] está na mesma "coluna" vertical que
  /// [focusedChild] via overlap horizontal.
  bool _sameColumn(FocusNode node, FocusNode focusedChild) {
    final a = node.rect;
    final b = focusedChild.rect;
    return a.left < b.right && a.right > b.left;
  }

  void _requestFocusInDirection(FocusNode target) {
    requestFocusCallback(
      target,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }
}


