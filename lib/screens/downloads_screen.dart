import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/download_service.dart';
import '../ui/core/themes/app_colors.dart';
import '../widgets/focusable_widget.dart';

/// Downloads screen - Netflix-style UI for managing downloads
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).downloads,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textPrimary),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: AppLocalizations.of(context).activeTab),
            Tab(text: AppLocalizations.of(context).completedTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ActiveDownloadsTab(), _CompletedDownloadsTab()],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final downloadService = context.read<DownloadService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          AppLocalizations.of(context).downloadSettings,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                AppLocalizations.of(context).maxConcurrentDownloads,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Slider(
                value: downloadService.maxConcurrentDownloads.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: downloadService.maxConcurrentDownloads.toString(),
                onChanged: (value) {
                  downloadService.maxConcurrentDownloads = value.toInt();
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                downloadService.clearCompleted();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(AppLocalizations.of(context).clearAllCompleted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).close),
          ),
        ],
      ),
    );
  }
}

/// Active downloads tab
class _ActiveDownloadsTab extends StatelessWidget {
  const _ActiveDownloadsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, _) {
        final activeDownloads = downloadService.activeDownloads;

        if (activeDownloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.download_outlined,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).noActiveDownloads,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeDownloads.length,
          itemBuilder: (context, index) {
            final download = activeDownloads[index];
            return _DownloadCard(download: download, isActive: true);
          },
        );
      },
    );
  }
}

/// Completed downloads tab
class _CompletedDownloadsTab extends StatelessWidget {
  const _CompletedDownloadsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, _) {
        final completedDownloads = downloadService.completedDownloads;

        if (completedDownloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).noCompletedDownloads,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        // Group by anime
        final Map<String, List<DownloadItem>> groupedDownloads = {};
        for (final download in completedDownloads) {
          groupedDownloads
              .putIfAbsent(download.animeId, () => [])
              .add(download);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedDownloads.length,
          itemBuilder: (context, index) {
            final animeId = groupedDownloads.keys.elementAt(index);
            final episodes = groupedDownloads[animeId]!;
            episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

            return _AnimeDownloadGroup(
              animeId: animeId,
              animeName: episodes.first.animeName,
              thumbnailUrl: episodes.first.thumbnailUrl,
              episodes: episodes,
            );
          },
        );
      },
    );
  }
}

/// Download card widget
class _DownloadCard extends StatelessWidget {
  final DownloadItem download;
  final bool isActive;

  const _DownloadCard({required this.download, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<DownloadService>();

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: download.thumbnailUrl,
                width: 80,
                height: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surface,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surface,
                  child: const Icon(Icons.error),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    download.animeName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(
                      context,
                    ).episode(download.episodeNumber),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 8),
                    // Progress bar
                    LinearProgressIndicator(
                      value: download.progress,
                      backgroundColor: AppColors.background,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Status text
                    Text(
                      _getStatusText(context, download, downloadService),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Action buttons
            if (isActive)
              _buildActiveActions(context, download, downloadService)
            else
              _buildCompletedActions(context, download, downloadService),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveActions(
    BuildContext context,
    DownloadItem download,
    DownloadService downloadService,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (download.status == DownloadStatus.downloading)
          IconButton(
            icon: const Icon(Icons.pause, color: AppColors.accent),
            onPressed: () => downloadService.pauseDownload(download.id),
          )
        else if (download.status == DownloadStatus.paused)
          IconButton(
            icon: const Icon(Icons.play_arrow, color: AppColors.accent),
            onPressed: () => downloadService.resumeDownload(download.id),
          )
        else if (download.status == DownloadStatus.failed)
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent),
            onPressed: () => downloadService.retryDownload(download.id),
          ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () =>
              _showDeleteDialog(context, download, downloadService),
        ),
      ],
    );
  }

  Widget _buildCompletedActions(
    BuildContext context,
    DownloadItem download,
    DownloadService downloadService,
  ) {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () => _showDeleteDialog(context, download, downloadService),
    );
  }

  String _getStatusText(
    BuildContext context,
    DownloadItem download,
    DownloadService downloadService,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (download.status) {
      case DownloadStatus.downloading:
        final percentage = (download.progress * 100).toStringAsFixed(1);
        final downloaded = downloadService.formatBytes(
          download.bytesDownloaded,
        );
        final total = downloadService.formatBytes(download.totalBytes);
        return '$percentage% • $downloaded / $total';
      case DownloadStatus.paused:
        return l10n.paused;
      case DownloadStatus.queued:
        return l10n.waiting;
      case DownloadStatus.failed:
        return l10n.failedWith(download.error ?? l10n.unknownError);
      default:
        return '';
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    DownloadItem download,
    DownloadService downloadService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          AppLocalizations.of(context).deleteDownload,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          AppLocalizations.of(context).deleteDownloadConfirmation,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              downloadService.deleteDownload(download.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
  }
}

/// Anime download group widget (for completed downloads)
class _AnimeDownloadGroup extends StatefulWidget {
  final String animeId;
  final String animeName;
  final String thumbnailUrl;
  final List<DownloadItem> episodes;

  const _AnimeDownloadGroup({
    required this.animeId,
    required this.animeName,
    required this.thumbnailUrl,
    required this.episodes,
  });

  @override
  State<_AnimeDownloadGroup> createState() => _AnimeDownloadGroupState();
}

class _AnimeDownloadGroupState extends State<_AnimeDownloadGroup> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Header
          FocusableWidget(
            onSelect: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: 8,
            focusPadding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: widget.thumbnailUrl,
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.background,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.background,
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.animeName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).episodesCount(widget.episodes.length),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Episodes list
          if (_isExpanded)
            ...widget.episodes.map(
              (episode) => _EpisodeListItem(episode: episode),
            ),
        ],
      ),
    );
  }
}

/// Episode list item
class _EpisodeListItem extends StatelessWidget {
  final DownloadItem episode;

  const _EpisodeListItem({required this.episode});

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<DownloadService>();

    return FocusableWidget(
      onSelect: () => _playEpisode(context),
      borderRadius: 8,
      focusPadding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.background, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Episode number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  episode.episodeNumber,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Episode title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.episodeTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (episode.totalBytes > 0)
                    Text(
                      downloadService.formatBytes(episode.totalBytes),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            // Play button
            IconButton(
              icon: const Icon(
                Icons.play_circle_filled,
                color: AppColors.accent,
                size: 32,
              ),
              onPressed: () => _playEpisode(context),
            ),
          ],
        ),
      ),
    );
  }

  void _playEpisode(BuildContext context) {
    if (episode.filePath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _LocalVideoPlayerScreen(
          filePath: episode.filePath!,
          episodeTitle: AppLocalizations.of(
            context,
          ).episode(episode.episodeNumber),
        ),
      ),
    );
  }
}

/// Local video player screen for downloaded files
class _LocalVideoPlayerScreen extends StatefulWidget {
  final String filePath;
  final String episodeTitle;

  const _LocalVideoPlayerScreen({
    required this.filePath,
    required this.episodeTitle,
  });

  @override
  State<_LocalVideoPlayerScreen> createState() =>
      _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends State<_LocalVideoPlayerScreen> {
  Player? _player;
  VideoController? _videoController;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _player = Player();
      _videoController = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
          androidAttachSurfaceAfterVideoParameters: true,
        ),
      );

      await _player!.open(Media(widget.filePath), play: true);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.episodeTitle,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _errorMessage != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    '${AppLocalizations.of(context).error}: $_errorMessage',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : _isInitialized && _videoController != null
            ? Video(controller: _videoController!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
