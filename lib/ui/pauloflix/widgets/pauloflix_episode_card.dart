/// Card de episódio no estilo Netflix com thumbnail e metadados.
///
/// Exibe thumbnail 16:9, número do episódio (S01E01), título,
/// duração e botão play proeminente.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/pauloflix_models.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';

/// Card de episódio estilo Netflix.
///
/// [Uso]:
/// ```dart
/// PauloflixEpisodeCard(
///   episode: episode,
///   seasonNumber: 1,
///   thumbnailUrl: 'https://...',
///   onTap: () => playEpisode(episode),
/// )
/// ```
class PauloflixEpisodeCard extends StatelessWidget {
  final PauloFlixEpisode episode;
  final int seasonNumber;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final bool isTV;

  const PauloflixEpisodeCard({
    super.key,
    required this.episode,
    required this.seasonNumber,
    this.thumbnailUrl,
    required this.onTap,
    this.isTV = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 8,
      focusPadding: EdgeInsets.zero,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: isTV ? 120 : 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                _buildThumbnail(),
                _buildInfo(),
                _buildPlayButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return SizedBox(
      width: isTV ? 160 : 140,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail ou placeholder
          if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: thumbnailUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.movie_outlined,
                    color: Colors.white24,
                    size: 32,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white24,
                    size: 32,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
              ),
              child: Center(
                child: Text(
                  'E${episode.number}',
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Gradiente overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    AppColors.surface.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),

          // Número do episódio (badge)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'E${episode.number.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Ícone de play centralizado
          const Positioned.fill(
            child: Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Título do episódio
            Text(
              episode.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTV ? 16 : 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Metadados
            Row(
              children: [
                // Número completo SxxExx
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'S${seasonNumber.toString().padLeft(2, '0')}E${episode.number.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Tamanho do arquivo (se disponível)
                if (episode.fileSize != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.storage_outlined,
                    color: Colors.white38,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${episode.fileSize}MB',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: isTV ? 48 : 40,
        height: isTV ? 48 : 40,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: isTV ? 28 : 24,
        ),
      ),
    );
  }
}
