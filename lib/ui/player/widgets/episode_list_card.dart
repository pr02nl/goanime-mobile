/// Card de episódio em modo lista para a tela de lista de episódios.
///
/// Extraído de `modern_episode_list_screen.dart` para reduzir o tamanho do
/// arquivo orquestrador.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/episode.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/episode_utils.dart';
import '../../core/widgets/focusable_widget.dart';
import '../../downloads/widgets/download_button.dart';
import '../../../data/services/download_service.dart';

/// Card de episódio exibido em modo lista (horizontal).
class EpisodeListCard extends StatelessWidget {
  final Episode episode;
  final int index;
  final VoidCallback onTap;
  final String animeTitle;
  final String animeThumbnail;
  final String sourceName;
  final String animeUrl;

  const EpisodeListCard({
    super.key,
    required this.episode,
    required this.index,
    required this.onTap,
    required this.animeTitle,
    required this.animeThumbnail,
    required this.sourceName,
    required this.animeUrl,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl =
        (episode.thumbnail != null && episode.thumbnail!.isNotEmpty)
        ? episode.thumbnail!
        : (animeThumbnail.isNotEmpty ? animeThumbnail : null);
    final hasImage = thumbnailUrl != null;

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
              colors: [Color(0xCC1A1A2E), Color(0x9916213E)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x0DFFFFFF)),
          ),
          child: Row(
            children: [
              _buildThumbnail(context, thumbnailUrl, hasImage),
              _buildEpisodeInfo(context),
              _buildDownloadButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    String? thumbnailUrl,
    bool hasImage,
  ) {
    return Container(
      width: 120,
      height: 80,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryShadow,
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: hasImage
                ? CachedNetworkImage(
                    imageUrl: thumbnailUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.getPrimaryGradient(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.getPrimaryGradient(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.getPrimaryGradient(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.movie, color: Colors.white54, size: 32),
                    ),
                  ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x8064FFDA), width: 1),
              ),
              child: Text(
                extractEpisodeNumber(episode.number),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: Center(
              child: Icon(
                Icons.play_circle_filled,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeInfo(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).episode(extractEpisodeNumber(episode.number)),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (episode.title != null && episode.title!.isNotEmpty)
              Text(
                episode.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text(
                animeTitle,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (episode.description != null && episode.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  episode.description!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    final thumbnailUrl =
        (episode.thumbnail != null && episode.thumbnail!.isNotEmpty)
        ? episode.thumbnail!
        : (animeThumbnail.isNotEmpty ? animeThumbnail : '');

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DownloadButton(
        animeId: animeUrl,
        animeName: animeTitle,
        episodeNumber: extractEpisodeNumber(episode.number),
        episodeTitle:
            AppLocalizations.of(context).episode(extractEpisodeNumber(episode.number)),
        videoUrl: episode.url,
        thumbnailUrl: thumbnailUrl,
        quality: DownloadQuality.auto,
      ),
    );
  }
}
