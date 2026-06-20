/// Painel de informações abaixo do player de vídeo.
///
/// Extraído de `video_player_screen.dart` para reduzir o tamanho do
/// arquivo orquestrador. Exibe: título, tags de qualidade, info do servidor,
/// botões de ação e navegação entre episódios.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';

/// Painel de informações exibido abaixo do player (modo não-fullscreen).
///
/// [Uso]:
/// ```dart
/// VideoPlayerInfoPanel(
///   animeTitle: widget.animeTitle,
///   displayLabel: _displayLabel,
///   currentVideoUrl: _currentVideoUrl,
///   isGoogleStream: _isGoogleStream,
///   showWebViewOption: _showWebViewOption,
///   bloggerVideoUrl: _bloggerVideoUrl,
///   isMovie: widget.isMovie,
///   hasNextEpisode: _hasNextEpisode,
///   hasPreviousEpisode: _hasPreviousEpisode,
///   subtitleSelectorTag: SubtitleSelectorTag(...),
///   onRetry: _initializeVideoPlayer,
///   onCopyLink: _copyStreamLink,
///   onWebViewFallback: _openWebViewFallback,
///   onNextEpisode: _goToNextEpisode,
///   onPreviousEpisode: _goToPreviousEpisode,
/// )
/// ```
class VideoPlayerInfoPanel extends StatelessWidget {
  final String animeTitle;
  final String displayLabel;
  final String? currentVideoUrl;
  final bool isGoogleStream;
  final bool showWebViewOption;
  final String? bloggerVideoUrl;
  final bool isMovie;
  final bool hasNextEpisode;
  final bool hasPreviousEpisode;
  final Widget? subtitleSelectorTag;
  final VoidCallback onRetry;
  final VoidCallback onCopyLink;
  final VoidCallback onWebViewFallback;
  final VoidCallback onNextEpisode;
  final VoidCallback onPreviousEpisode;

  const VideoPlayerInfoPanel({
    super.key,
    required this.animeTitle,
    required this.displayLabel,
    this.currentVideoUrl,
    required this.isGoogleStream,
    required this.showWebViewOption,
    this.bloggerVideoUrl,
    required this.isMovie,
    required this.hasNextEpisode,
    required this.hasPreviousEpisode,
    this.subtitleSelectorTag,
    required this.onRetry,
    required this.onCopyLink,
    required this.onWebViewFallback,
    required this.onNextEpisode,
    required this.onPreviousEpisode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface.withValues(alpha: 0.8),
            AppColors.surfaceLight.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleSection(context),
          const SizedBox(height: 20),
          _buildTagsRow(context),
          if (currentVideoUrl != null) ...[
            const SizedBox(height: 20),
            _buildServerInfoSection(context),
          ],
          const SizedBox(height: 20),
          _buildActionButtons(context),
          if (!isMovie && hasNextEpisode || hasPreviousEpisode) ...[
            const SizedBox(height: 12),
            _buildEpisodeNavigationButtons(context),
          ],
          if (showWebViewOption && bloggerVideoUrl != null) ...[
            const SizedBox(height: 12),
            _buildAlternativePlayerButton(context),
          ],
        ],
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          animeTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayLabel,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsRow(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTag(
          AppLocalizations.of(context).dynamicQuality,
          const Color(0xFF9C27B0),
          Icons.high_quality_rounded,
        ),
        _buildTag(
          AppLocalizations.of(context).optimizedPlayer,
          const Color(0xFF2196F3),
          Icons.offline_bolt_rounded,
        ),
        if (isGoogleStream)
          _buildTag(
            AppLocalizations.of(context).googleVideo,
            const Color(0xFF4CAF50),
            Icons.cloud_done_rounded,
          ),
        ?subtitleSelectorTag,
      ],
    );
  }

  Widget _buildServerInfoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.getPrimaryGradient(),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sensors, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).serverInUse,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Uri.parse(currentVideoUrl!).host,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopyLink,
            icon: const Icon(Icons.copy, color: AppColors.primary),
            tooltip: AppLocalizations.of(context).copyLink,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).syncStream),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: currentVideoUrl == null ? null : onCopyLink,
            icon: const Icon(Icons.link),
            label: Text(AppLocalizations.of(context).copyLink),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlternativePlayerButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onWebViewFallback,
        icon: const Icon(Icons.open_in_browser),
        label: Text(AppLocalizations.of(context).alternativePlayer),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeNavigationButtons(BuildContext context) {
    return Row(
      children: [
        if (hasPreviousEpisode)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onPreviousEpisode,
              icon: const Icon(Icons.skip_previous_rounded),
              label: Text(AppLocalizations.of(context).previousEpisode),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        else
          const SizedBox(),
        if (hasPreviousEpisode && hasNextEpisode) const SizedBox(width: 12),
        if (hasNextEpisode)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onNextEpisode,
              icon: const Icon(Icons.skip_next_rounded),
              label: Text(AppLocalizations.of(context).nextEpisode),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        else
          const SizedBox(),
      ],
    );
  }

  Widget _buildTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
