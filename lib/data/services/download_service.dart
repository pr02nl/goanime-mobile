import 'dart:io';

import '../../core/logger/app_logger.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/database/tables/downloads.dart'
    show DownloadQuality, DownloadStatus;
import '../../domain/repositories/downloads_repository.dart';

// Re-exporta os enums para o código que ainda importa daqui
// (ex: downloads_screen.dart, episode_grid_card.dart).
export '../../core/database/tables/downloads.dart'
    show DownloadQuality, DownloadStatus;

/// Intervalo mínimo entre notificações de progresso (em ms).
/// Evita sobrecarregar a UI com dezenas de rebuilds por segundo
/// durante downloads rápidos.
const int _kProgressThrottleMs = 500;

// Os enums `DownloadQuality` e `DownloadStatus` são importados de
// `tables/downloads.dart` (definidos lá para uso com Drift `intEnum<>`).
// `DownloadItem` (modelo de domínio, manual) é importado de
// `download_service.dart`. Ambos compartilham os mesmos enums via
// import e re-export.

/// Download item model
class DownloadItem {
  final String id;
  final String animeId;
  final String animeName;
  final String episodeNumber;
  final String episodeTitle;
  final String videoUrl;
  final String thumbnailUrl;
  final DownloadQuality quality;
  DownloadStatus status;
  double progress;
  int bytesDownloaded;
  int totalBytes;
  String? filePath;
  String? error;
  DateTime createdAt;
  DateTime? completedAt;

  DownloadItem({
    required this.id,
    required this.animeId,
    required this.animeName,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.quality = DownloadQuality.auto,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.filePath,
    this.error,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animeId': animeId,
      'animeName': animeName,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'quality': quality.index,
      'status': status.index,
      'progress': progress,
      'bytesDownloaded': bytesDownloaded,
      'totalBytes': totalBytes,
      'filePath': filePath,
      'error': error,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'],
      animeId: map['animeId'],
      animeName: map['animeName'],
      episodeNumber: map['episodeNumber'],
      episodeTitle: map['episodeTitle'],
      videoUrl: map['videoUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      quality: DownloadQuality.values[map['quality']],
      status: DownloadStatus.values[map['status']],
      progress: map['progress'],
      bytesDownloaded: map['bytesDownloaded'],
      totalBytes: map['totalBytes'],
      filePath: map['filePath'],
      error: map['error'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
    );
  }

  DownloadItem copyWith({
    DownloadStatus? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? filePath,
    String? error,
    DateTime? completedAt,
  }) {
    return DownloadItem(
      id: id,
      animeId: animeId,
      animeName: animeName,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Download service - manages all download operations
class DownloadService extends ChangeNotifier {
  /// Ctor único com repository injetado.
  ///
  /// [httpClient] é opcional; em produção recebe o `AuthenticatedHttpClient`
  /// para que downloads de arquivos PauloFlix (que exigem JWT) passem
  /// pela auth. Em testes, pode-se omitir (cai no `http.Client()` default).
  DownloadService.withRepository(
    this._repository, {
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  /// HTTP client usado pelos downloads. Null em testes (cai no
  /// `http.Client()` puro, sem auth).
  final http.Client? _httpClient;

  /// Repository Drift — fonte de verdade da persistência de downloads.
  final DownloadsRepository _repository;

  final Map<String, DownloadItem> _downloads = {};
  final Map<String, http.Client> _downloadClients = {};
  int _maxConcurrentDownloads = 3;
  int _activeDownloadCount = 0;

  // Cache de listas computadas
  List<DownloadItem>? _cachedActive;
  List<DownloadItem>? _cachedCompleted;
  bool _cacheDirty = true;

  /// Timestamp da última notificação (throttle de progresso).
  int _lastNotifyMs = 0;

  List<DownloadItem> get downloads => _downloads.values.toList();

  List<DownloadItem> get activeDownloads {
    if (_cacheDirty || _cachedActive == null) {
      _cachedActive = _downloads.values
          .where(
            (d) =>
                d.status == DownloadStatus.downloading ||
                d.status == DownloadStatus.queued,
          )
          .toList();
    }
    return _cachedActive!;
  }

  List<DownloadItem> get completedDownloads {
    if (_cacheDirty || _cachedCompleted == null) {
      _cachedCompleted = _downloads.values
          .where((d) => d.status == DownloadStatus.completed)
          .toList();
    }
    return _cachedCompleted!;
  }

  /// Invalida os caches e notifica ouvintes.
  void _markDirty() {
    _cacheDirty = true;
  }

  /// Notifica ouvintes com throttle de progresso.
  /// [force] ignora o throttle (usado para mudanças de estado que não
  /// são apenas progresso: completed, failed, paused, etc.).
  void _notify([bool force = false]) {
    if (force) {
      _markDirty();
      notifyListeners();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNotifyMs < _kProgressThrottleMs) {
      return; // Throttled — não notifica ainda
    }
    _lastNotifyMs = now;
    _markDirty();
    notifyListeners();
  }

  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  set maxConcurrentDownloads(int value) {
    _maxConcurrentDownloads = value.clamp(1, 5);
    _notify(true);
  }

  /// Initialize the download service — carrega os downloads do Drift
  /// e aplica o reset stale→queued (Fase 1 fix).
  Future<void> initialize() async {
    final items = await _repository.getAll();
    _downloads.clear();
    for (final download in items) {
      _downloads[download.id] = download;
      // Reset downloading → queued (Fase 1 fix).
      if (download.status == DownloadStatus.downloading) {
        await _repository.resetStaleToQueued();
        final reset = download.copyWith(status: DownloadStatus.queued);
        _downloads[download.id] = reset;
      }
    }
    _notify(true);
  }

  /// Add a download to the queue
  Future<String> addDownload({
    required String animeId,
    required String animeName,
    required String episodeNumber,
    required String episodeTitle,
    required String videoUrl,
    required String thumbnailUrl,
    DownloadQuality quality = DownloadQuality.auto,
  }) async {
    final id = '${animeId}_$episodeNumber';

    // Check if already exists
    if (_downloads.containsKey(id)) {
      final existing = _downloads[id]!;
      if (existing.status == DownloadStatus.completed) {
        throw Exception('Episode already downloaded');
      }
      if (existing.status == DownloadStatus.downloading ||
          existing.status == DownloadStatus.queued) {
        throw Exception('Episode is already in download queue');
      }
      // If failed or cancelled, allow re-download
      await deleteDownload(id);
    }

    final download = DownloadItem(
      id: id,
      animeId: animeId,
      animeName: animeName,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
    );

    _downloads[id] = download;
    await _repository.save(download);

    _notify(true);
    _processQueue();

    return id;
  }

  /// Add multiple downloads (batch download)
  Future<List<String>> addBatchDownloads({
    required String animeId,
    required String animeName,
    required List<Map<String, String>> episodes,
    required String thumbnailUrl,
    DownloadQuality quality = DownloadQuality.auto,
  }) async {
    final List<String> downloadIds = [];

    for (final episode in episodes) {
      try {
        final id = await addDownload(
          animeId: animeId,
          animeName: animeName,
          episodeNumber: episode['number']!,
          episodeTitle: episode['title'] ?? 'Episode ${episode['number']}',
          videoUrl: episode['url']!,
          thumbnailUrl: thumbnailUrl,
          quality: quality,
        );
        downloadIds.add(id);
      } catch (e, st) {
        const AppLogger('Download').error('Failed to add episode ${episode['number']}', e, st);
      }
    }

    return downloadIds;
  }

  /// Process the download queue
  void _processQueue() {
    if (_activeDownloadCount >= _maxConcurrentDownloads) {
      return;
    }

    final queuedDownloads =
        _downloads.values
            .where((d) => d.status == DownloadStatus.queued)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final download in queuedDownloads) {
      if (_activeDownloadCount >= _maxConcurrentDownloads) break;
      _startDownload(download.id);
    }
  }

  /// Start a download
  Future<void> _startDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    _activeDownloadCount++;
    _downloads[id] = download.copyWith(status: DownloadStatus.downloading);
    await _repository.save(_downloads[id]!);
    _notify(true);

    try {
      // Validate URL
      final Uri uri;
      try {
        uri = Uri.parse(download.videoUrl);
        if (!uri.hasScheme ||
            (uri.scheme != 'http' && uri.scheme != 'https')) {
          throw Exception('Invalid URL format');
        }
        if (uri.host.isEmpty) {
          throw Exception('Invalid URL format');
        }
      // ignore: unused_catch_stack
      } catch (e, st) {
        if (e.toString().contains('Invalid URL format')) {
          rethrow;
        }
        throw Exception('Invalid video URL: ${download.videoUrl}');
      }

      // Start the download (PauloFlix URLs are direct file URLs)
      await _downloadHttp(id);
    } catch (e, st) {
      const AppLogger('Download').error('Download error for $id', e, st);
      _downloads[id] = download.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      );
      await _repository.save(_downloads[id]!);
    } finally {
      _activeDownloadCount--;
      _downloadClients[id]?.close();
      _downloadClients.remove(id);
      _notify(true);
      _processQueue();
    }
  }

  /// Download via HTTP
  Future<void> _downloadHttp(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    const AppLogger('Download').debug('Starting download for $id');
    const AppLogger('Download').debug('Episode URL: ${download.videoUrl}');
    const AppLogger('Download').debug('Anime ID: ${download.animeId}');

    // PauloFlix URLs are direct MKV/MP4 file URLs — no resolution needed.
    final String actualVideoUrl = download.videoUrl;

    // Create download directory
    final downloadDir = await _getDownloadDirectory();
    if (downloadDir == null) {
      throw Exception(
        'Download directory not available. Check storage permissions.',
      );
    }
    final safeAnimeName = _sanitizeFileName(download.animeName);
    final animeDir = Directory(path.join(downloadDir.path, safeAnimeName));
    await animeDir.create(recursive: true);

    final fileName = 'Episode_${download.episodeNumber}.mp4';
    final filePath = path.join(animeDir.path, fileName);
    const AppLogger('Download').debug('Saving to: $filePath');

    // Set filePath immediately so cancel/retry can clean up partial file
    _downloads[id] = _downloads[id]!.copyWith(filePath: filePath);
    await _repository.save(_downloads[id]!);
    _notify(true);

    // Create HTTP client (injetado em produção com AuthenticatedHttpClient)
    final client = _httpClient ?? http.Client();
    _downloadClients[id] = client;

    try {
      // Get content length first
      const AppLogger('Download').debug('Getting content length...');
      final headResponse = await client
          .head(Uri.parse(actualVideoUrl))
          .timeout(const Duration(seconds: 30));
      final totalBytes =
          int.tryParse(headResponse.headers['content-length'] ?? '0') ?? 0;
      const AppLogger('Download').debug(
        'Total size: $totalBytes bytes (${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB)',
      );

      // Start streaming download
      const AppLogger('Download').debug('Starting stream...');
      final request = http.Request('GET', Uri.parse(actualVideoUrl));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final file = File(filePath);
      final sink = file.openWrite();
      int bytesDownloaded = 0;
      int lastNotificationBytes = 0;
      int lastSaveBytes = 0;
      const notificationInterval = 256 * 1024; // 256KB
      const saveInterval = 1024 * 1024; // 1MB

      await for (final chunk in response.stream) {
        // Check if download was cancelled
        if (!_downloads.containsKey(id) ||
            _downloads[id]!.status == DownloadStatus.cancelled) {
          await sink.close();
          await file.delete();
          return;
        }

        // Check if download was paused
        if (_downloads[id]!.status == DownloadStatus.paused) {
          await sink.close();
          return;
        }

        sink.add(chunk);
        bytesDownloaded += chunk.length;

        // Update progress in memory
        final progress = totalBytes > 0 ? bytesDownloaded / totalBytes : 0.0;
        _downloads[id] = _downloads[id]!.copyWith(
          progress: progress,
          bytesDownloaded: bytesDownloaded,
          totalBytes: totalBytes > 0 ? totalBytes : bytesDownloaded,
        );

        // Notify UI with throttle (max every 500ms) instead of every 256KB
        if (bytesDownloaded - lastNotificationBytes >= notificationInterval) {
          lastNotificationBytes = bytesDownloaded;
          _notify();
        }

        // Save to DB and log every 1MB or 1%
        final shouldSave = totalBytes > 0
            ? (totalBytes >= 100 &&
                  (bytesDownloaded - lastSaveBytes) >= (totalBytes ~/ 100))
            : ((bytesDownloaded - lastSaveBytes) >= saveInterval);

        if (shouldSave) {
          lastSaveBytes = bytesDownloaded;
          const AppLogger('Download').debug(
            'Progress: ${(progress * 100).toStringAsFixed(1)}% (${(bytesDownloaded / 1024 / 1024).toStringAsFixed(2)} MB)',
          );
          await _repository.save(_downloads[id]!);
        }
      }

      await sink.flush();
      await sink.close();

      const AppLogger('Download').debug('Download completed: $id');
      const AppLogger('Download').debug('File saved to: $filePath');

      // Download completed
      _downloads[id] = _downloads[id]!.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        completedAt: DateTime.now(),
      );
      await _repository.save(_downloads[id]!);
      _notify(true);
    // ignore: unused_catch_stack
    } catch (e, st) {
      rethrow;
    }
  }

  /// Pause a download
  Future<void> pauseDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.downloading) {
      return;
    }

    _downloads[id] = download.copyWith(status: DownloadStatus.paused);
    await _repository.save(_downloads[id]!);
    _notify(true);
  }

  /// Resume a download
  Future<void> resumeDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.paused) {
      return;
    }

    _downloads[id] = download.copyWith(status: DownloadStatus.queued);
    await _repository.save(_downloads[id]!);
    _notify(true);
    _processQueue();
  }

  /// Cancel a download
  Future<void> cancelDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    _downloads[id] = download.copyWith(status: DownloadStatus.cancelled);
    _downloadClients[id]?.close();
    await _repository.save(_downloads[id]!);

    // Delete partial file
    if (download.filePath != null) {
      final file = File(download.filePath!);
      if (file.existsSync()) {
        await file.delete();
      }
    }

    _notify(true);
  }

  /// Retry a failed download
  Future<void> retryDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.failed) {
      return;
    }

    _downloads[id] = download.copyWith(
      status: DownloadStatus.queued,
      error: null,
      progress: 0,
      bytesDownloaded: 0,
    );
    await _repository.save(_downloads[id]!);
    _notify(true);
    _processQueue();
  }

  /// Delete a download
  Future<void> deleteDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    // Cancel if active
    if (download.status == DownloadStatus.downloading) {
      await cancelDownload(id);
    }

    // Delete file
    if (download.filePath != null) {
      final file = File(download.filePath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }

    // Remove from database via repository
    await _repository.delete(id);
    _downloads.remove(id);
    _notify(true);
  }

  /// Clear all completed downloads
  Future<void> clearCompleted() async {
    final completed = _downloads.values
        .where((d) => d.status == DownloadStatus.completed)
        .toList();

    for (final download in completed) {
      await deleteDownload(download.id);
    }
  }

  /// Clear all failed downloads
  Future<void> clearFailedDownloads() async {
    final failed = _downloads.values
        .where(
          (d) =>
              d.status == DownloadStatus.failed ||
              d.status == DownloadStatus.cancelled,
        )
        .toList();

    for (final download in failed) {
      await deleteDownload(download.id);
    }
  }

  /// Get download by ID
  DownloadItem? getDownload(String id) => _downloads[id];

  /// Get downloads for an anime
  List<DownloadItem> getAnimeDownloads(String animeId) {
    return _downloads.values.where((d) => d.animeId == animeId).toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  }

  /// Get download directory with Android TV compatibility
  Future<Directory?> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Try external storage first (legacy behavior)
        Directory? directory;
        try {
          directory = await getExternalStorageDirectory();
        } catch (e, st) {
          const AppLogger('Download').warning('External storage not available', e, st);
        }

        // Fallback to app documents for Android TV compatibility
        if (directory == null) {
          directory = await getApplicationDocumentsDirectory();
          const AppLogger('Download').debug(
            'Using app documents directory (Android TV mode)',
          );
        }

        final downloadDir = Directory(
          path.join(directory.path, 'PauloFlix', 'Downloads'),
        );
        if (!downloadDir.existsSync()) {
          downloadDir.createSync(recursive: true);
        }
        return downloadDir;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final downloadDir = Directory(path.join(directory.path, 'Downloads'));
        if (!downloadDir.existsSync()) {
          downloadDir.createSync(recursive: true);
        }
        return downloadDir;
      }
    } catch (e, st) {
      const AppLogger('Download').error('Failed to get download directory', e, st);
      return null;
    }
  }

  /// Sanitize file name
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:\"/\\\\|?*]'), '_')
        .replaceAll(RegExp(r'\\s+'), '_')
        .trim();
  }

  /// Get total download size
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Dispose resources
  @override
  void dispose() {
    for (final client in _downloadClients.values) {
      client.close();
    }
    _downloadClients.clear();
    super.dispose();
  }
}
