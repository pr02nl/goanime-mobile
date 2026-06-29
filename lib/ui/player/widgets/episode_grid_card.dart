/// Card de episódio em modo grid para a tela de lista de episódios.
///
/// Extraído de `modern_episode_list_screen.dart` para reduzir o tamanho do
/// arquivo orquestrador.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/download_service.dart';
import '../../../domain/models/episode.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/episode_utils.dart';
import '../../core/widgets/focusable_widget.dart';

/// Card de episódio exibido em modo grid (grade).
class EpisodeGridCard extends StatelessWidget {
  final Episode episode;
  final int index;
  final VoidCallback onTap;
  final String animeTitle;
  final String sourceName;

  const EpisodeGridCard({
    super.key,
    required this.episode,
    required this.index,
    required this.onTap,
    required this.animeTitle,
    required this.sourceName,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 16,
      focusPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Stack(
            children: [
              // Thumbnail (Fase 6 — PauloFlix NFO enrichment).
              // Renderizado PRIMEIRO para ficar atrás do gradient overlay
              // e do número do episódio. Usa CachedNetworkImage com fade-in
              // e fallback gracioso quando a URL é null ou falha.
              if (episode.thumbnailUrl != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: episode.thumbnailUrl!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (context, url) => const SizedBox.shrink(),
                      errorWidget: (context, url, error) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),

              // Gradient overlay (preto 60% no bottom) para garantir
              // legibilidade do número/badge do episódio quando a
              // thumb é clara. Cobre toda a área do card com um
              // fade vertical: transparente no topo, preto translúcido
              // embaixo. Não muda o gradient base do `Container` —
              // apenas adiciona uma camada de legibilidade.
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      extractEpisodeNumber(episode.number),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'EP',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Download status badge (top-left)
              Positioned(
                top: 8,
                left: 8,
                child: Consumer<DownloadService>(
                  builder: (context, downloadService, _) {
                    final episodeNumber = extractEpisodeNumber(
                      episode.number,
                    );
                    final downloadId = '${animeTitle}_$episodeNumber';
                    final download = downloadService.getDownload(downloadId);

                    if (download?.status == DownloadStatus.completed) {
                      return Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.download_done,
                          color: Colors.white,
                          size: 14,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),

              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
