import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/pauloflix_content.dart';
import '../../core/widgets/netflix_hero_card.dart';

/// Hero banner que destaca um anime/coleção no topo da See All.
///
/// Wrapper sobre [NetflixHeroCard] (mesmo padrão de
/// `_movie_hero_banner.dart` para filmes) que adiciona:
/// * `PauloFlixBadge` (azul, canto superior esquerdo) — sinaliza
///   que o conteúdo vem do file server PauloFlix.
/// * Score com estrelinha (se `content.score != null`).
/// * Tap em qualquer área → vai para a lista de episódios.
///
/// **Por que wrapper e não código próprio:** antes desta refatoração
/// (Fase N+3), o `_AnimeHeroBanner` duplicava ~140 linhas de
/// Stack/CachedNetworkImage/gradient/texto/botão que o
/// `NetflixHeroCard` já implementa. Os 2 extras (badge + score)
/// viraram props opcionais no `NetflixHeroCard` (`badge: Widget?`
/// e `score: double?`) — wrapper abaixo só compõe.
class AnimeHeroBanner extends StatelessWidget {
  final PauloFlixContent content;
  final bool isTV;
  final double height;
  final bool hasSeasons;
  final int seasonCount;
  final void Function()? onPlay;

  const AnimeHeroBanner({
    super.key,
    required this.content,
    required this.isTV,
    this.hasSeasons = false,
    this.seasonCount = 0,
    this.height = 420,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    // `bannerUrl` (wide 16:9) tem prioridade sobre `imageUrl`
    // (poster 2:3) para o hero. Mesma heurística do
    // `MovieHeroBanner` (banner > poster para área wide).
    final hasBanner =
        content.bannerUrl != null && content.bannerUrl!.isNotEmpty;
    final imageUrl = hasBanner ? content.bannerUrl! : (content.imageUrl ?? '');

    return SizedBox(
      height: height,
      child: NetflixHeroCard(
        imageUrl: imageUrl,
        title: content.displayName,
        description: content.description,
        // Badge PauloFlix (azul) — sinaliza origem do file server.
        // badge: const PauloFlixBadge(),
        // Score com estrelinha (null se não disponível).
        score: content.score,
        hasSeasons: hasSeasons,
        seasonCount: seasonCount,
        height: height,
        isTV: isTV,
        genres: content.genres,
        // Botão Play → vai para a lista de episódios.
        onPlay: () {
          if (onPlay != null) {
            onPlay!();
            return;
          }
          _openEpisodeList(context);
        },
      ),
    );
  }

  void _openEpisodeList(BuildContext context) {
    context.pushNamed('pauloflix-episodes', extra: content);
  }
}
