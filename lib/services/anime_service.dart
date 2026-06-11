import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/anime.dart';
import '../models/episode.dart';
import '../models/video.dart';
import '../services/allanime_service.dart';
import '../services/anilist_service.dart';
import '../services/episode_thumbnail_service.dart';

class AnimeService {
  static const String baseSiteUrl = 'https://animefire.plus';
  static const String _googleVideoUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1';
  static const String _bloggerOrigin = 'https://www.blogger.com';
  static const String _bloggerReferer = 'https://www.blogger.com/';

  static Future<List<Anime>> searchAnime(String animeName) async {
    try {
      debugPrint('[AnimeService] Searching in multiple sources: $animeName');

      // Buscar simultaneamente em AnimeFire e AllAnime
      final results = await Future.wait([
        _searchAnimeFire(animeName),
        _searchAllAnime(animeName),
      ]);

      // Combinar resultados
      final List<Anime> allAnimes = [];
      allAnimes.addAll(results[0]); // AnimeFire
      allAnimes.addAll(results[1]); // AllAnime

      debugPrint(
        '[AnimeService] Total results: ${allAnimes.length} (AnimeFire: ${results[0].length}, AllAnime: ${results[1].length})',
      );

      // Enriquecer com dados do AniList em paralelo
      await Future.wait(
        allAnimes.map((anime) => enrichAnimeWithAniList(anime)),
      );

      return allAnimes;
    } catch (e) {
      throw Exception('Error searching anime: $e');
    }
  }

  /// Busca no AnimeFire
  static Future<List<Anime>> _searchAnimeFire(String animeName) async {
    final String searchUrl =
        '$baseSiteUrl/pesquisar/${_treatAnimeName(animeName)}';

    try {
      final response = await http
          .get(Uri.parse(searchUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[AnimeFire] Search failed: ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);
      final animeElements = document.querySelectorAll('.row.ml-1.mr-1 a');

      List<Anime> animes = [];
      for (var element in animeElements) {
        final name = element.text.trim();
        final url = element.attributes['href'] ?? '';

        // Try to get thumbnail from img element
        String? thumbnail;
        final imgElement = element.querySelector('img.imgAnimes');
        if (imgElement != null) {
          thumbnail =
              imgElement.attributes['data-src'] ?? imgElement.attributes['src'];
        }

        if (name.isNotEmpty && url.isNotEmpty) {
          animes.add(
            Anime(
              name: name,
              url: url,
              source: AnimeSource.animeFire,
              fallbackImageUrl: thumbnail,
            ),
          );

          // Debug first few results
          if (animes.length <= 3) {
            debugPrint('[AnimeFire] Anime: $name, thumbnail: $thumbnail');
          }
        }
      }

      debugPrint('[AnimeFire] Found ${animes.length} results');
      return animes;
    } catch (e) {
      debugPrint('[AnimeFire] Search error: $e');
      return [];
    }
  }

  /// Busca no AllAnime
  static Future<List<Anime>> _searchAllAnime(String animeName) async {
    try {
      final response = await AllAnimeService.searchAnime(animeName);

      if (response == null || response.shows.isEmpty) {
        debugPrint('[AllAnime] No results found');
        return [];
      }

      List<Anime> animes = [];
      for (var show in response.shows) {
        final episodeInfo = show.episodeCount > 0
            ? ' (${show.episodeCount} eps)'
            : '';

        // Usar thumbnail do AllAnime como fallback se disponível
        final fallbackImage = show.thumbnail?.isNotEmpty == true
            ? show.thumbnail!
            : null;

        animes.add(
          Anime(
            name: '${show.displayName}$episodeInfo',
            url: show.id, // Para AllAnime, a "URL" é o ID
            source: AnimeSource.allAnime,
            allAnimeId: show.id,
            fallbackImageUrl: fallbackImage, // Fallback até AniList carregar
          ),
        );
      }

      debugPrint('[AllAnime] Found ${animes.length} results');
      return animes;
    } catch (e) {
      debugPrint('[AllAnime] Search error: $e');
      return [];
    }
  }

  /// Enriches an anime with data from AniList
  static Future<void> enrichAnimeWithAniList(Anime anime) async {
    try {
      anime.isLoadingAniList = true;

      final aniListResponse = await AniListService.fetchAnimeFromAniList(
        anime.name,
      );

      if (aniListResponse != null) {
        anime.aniListData = aniListResponse.data.media;
        debugPrint(
          '[AnimeService] Enriched ${anime.name} with AniList data - '
          'ID: ${anime.anilistId}, Cover: ${anime.imageUrl}',
        );
      } else {
        debugPrint('[AnimeService] No AniList data found for ${anime.name}');
      }
    } catch (e) {
      debugPrint(
        '[AnimeService] Failed to enrich ${anime.name} with AniList: $e',
      );
    } finally {
      anime.isLoadingAniList = false;
    }
  }

  static Future<List<Episode>> getAnimeEpisodes(Anime anime) async {
    try {
      debugPrint(
        '[AnimeService] Getting episodes for ${anime.name} from ${anime.sourceName}',
      );
      debugPrint('[AnimeService] Anime thumbnail URL: ${anime.imageUrl}');
      debugPrint(
        '[AnimeService] Has AniList data: ${anime.aniListData != null}',
      );
      debugPrint('[AnimeService] Fallback image: ${anime.fallbackImageUrl}');

      if (anime.source == AnimeSource.allAnime) {
        return await _getEpisodesFromAllAnime(anime);
      } else {
        return await _getEpisodesFromAnimeFire(anime);
      }
    } catch (e) {
      throw Exception('Error getting episodes: $e');
    }
  }

  /// Busca episódios do AnimeFire
  static Future<List<Episode>> _getEpisodesFromAnimeFire(Anime anime) async {
    try {
      debugPrint('[AnimeFire] Fetching episodes for: ${anime.name}');
      debugPrint('[AnimeFire] Anime thumbnail: ${anime.imageUrl}');

      final response = await http
          .get(Uri.parse(anime.url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to get episodes: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final episodeElements = document.querySelectorAll(
        'a.lEp.epT.divNumEp.smallbox.px-2.mx-1.text-left.d-flex',
      );

      // Extract episode numbers
      List<int> episodeNumbers = [];
      List<Episode> tempEpisodes = [];

      for (var element in episodeElements) {
        final number = element.text.trim();
        final url = element.attributes['href'] ?? '';
        if (number.isNotEmpty && url.isNotEmpty) {
          final episodeNumMatch = RegExp(r'\d+').firstMatch(number);
          if (episodeNumMatch != null) {
            final epNum = int.tryParse(episodeNumMatch.group(0)!);
            if (epNum != null) {
              episodeNumbers.add(epNum);
              tempEpisodes.add(Episode(number: number, url: url));
            }
          }
        }
      }

      // Batch fetch episode-specific thumbnails from multiple sources
      debugPrint('[AnimeFire] Fetching episode-specific thumbnails...');
      final kitsuThumbnails = await EpisodeThumbnailService.batchGetThumbnails(
        animeTitle: anime.name,
        episodeNumbers: episodeNumbers,
        malId: anime.malId?.toString(),
        anilistId: anime.anilistId?.toString(),
      );

      if (kitsuThumbnails.isNotEmpty) {
        debugPrint(
          '[AnimeFire] Got ${kitsuThumbnails.length} episode-specific thumbnails from Kitsu',
        );
      }

      List<Episode> episodes = [];
      for (int i = 0; i < tempEpisodes.length; i++) {
        final tempEp = tempEpisodes[i];
        final epNum = episodeNumbers[i];

        // Priority: Kitsu thumbnail > Anime thumbnail
        String? episodeThumbnail;
        if (kitsuThumbnails.containsKey(epNum)) {
          episodeThumbnail = kitsuThumbnails[epNum];
          if (episodes.length < 3) {
            debugPrint('[AnimeFire] Episode $epNum: Using Kitsu thumbnail');
          }
        } else {
          episodeThumbnail = anime.imageUrl;
          if (episodes.length < 3) {
            debugPrint('[AnimeFire] Episode $epNum: Using anime thumbnail');
          }
        }

        episodes.add(
          Episode(
            number: tempEp.number,
            url: tempEp.url,
            thumbnail: episodeThumbnail,
          ),
        );
      }

      debugPrint(
        '[AnimeFire] Converted ${episodes.length} episodes with thumbnails',
      );
      return episodes;
    } catch (e) {
      debugPrint('[AnimeFire] Get episodes error: $e');
      throw Exception('Error getting episodes from AnimeFire: $e');
    }
  }

  /// Busca episódios do AllAnime
  static Future<List<Episode>> _getEpisodesFromAllAnime(Anime anime) async {
    try {
      debugPrint('[AllAnime] Fetching episodes for: ${anime.name}');
      debugPrint('[AllAnime] Anime thumbnail: ${anime.imageUrl}');

      if (anime.allAnimeId == null) {
        throw Exception('AllAnime ID not found');
      }

      final detailedEpisodes = await AllAnimeService.getEpisodesListDetailed(
        anime.allAnimeId!,
      );

      if (detailedEpisodes.isEmpty) {
        debugPrint('[AllAnime] No episodes found');
        return [];
      }

      // Get show thumbnail as fallback
      final showThumbnail = anime.imageUrl;

      // Extract episode numbers for batch thumbnail fetching
      List<int> episodeNumbers = [];
      for (var ep in detailedEpisodes) {
        final epNum = int.tryParse(ep.episodeNumber);
        if (epNum != null) {
          episodeNumbers.add(epNum);
        }
      }

      // Batch fetch episode-specific thumbnails from multiple sources
      debugPrint('[AllAnime] Fetching episode-specific thumbnails...');
      final kitsuThumbnails = await EpisodeThumbnailService.batchGetThumbnails(
        animeTitle: anime.name,
        episodeNumbers: episodeNumbers,
        malId: anime.malId?.toString(),
        anilistId: anime.anilistId?.toString(),
      );

      if (kitsuThumbnails.isNotEmpty) {
        debugPrint(
          '[AllAnime] Got ${kitsuThumbnails.length} episode-specific thumbnails from Kitsu',
        );
      }

      List<Episode> episodes = [];
      for (var allAnimeEp in detailedEpisodes) {
        final displayNumber = allAnimeEp.episodeNumber.contains('.')
            ? 'Episódio ${allAnimeEp.episodeNumber}'
            : 'Episódio ${allAnimeEp.episodeNumber}';

        // Priority: Kitsu thumbnail > AllAnime thumbnail > Show thumbnail
        String? episodeThumbnail;

        final epNum = int.tryParse(allAnimeEp.episodeNumber);
        if (epNum != null && kitsuThumbnails.containsKey(epNum)) {
          episodeThumbnail = kitsuThumbnails[epNum];
          if (episodes.length < 3) {
            debugPrint('[AllAnime] Episode $epNum: Using Kitsu thumbnail');
          }
        } else {
          episodeThumbnail = allAnimeEp.getImageUrl();
          if (episodeThumbnail == null || episodeThumbnail.isEmpty) {
            episodeThumbnail = showThumbnail;
          }
        }

        episodes.add(
          Episode(
            number: displayNumber,
            url: allAnimeEp
                .episodeNumber, // Para AllAnime, guardamos o número do episódio
            thumbnail: episodeThumbnail, // Add thumbnail (with fallback)
            title: allAnimeEp.title,
            description: allAnimeEp.description,
          ),
        );

        // Log first few episodes for debugging
        if (episodes.length <= 3) {
          debugPrint(
            '[AllAnime] Episode ${allAnimeEp.episodeNumber} final thumbnail: $episodeThumbnail',
          );
        }
      }

      debugPrint(
        '[AllAnime] Converted ${episodes.length} episodes with thumbnails',
      );
      return episodes;
    } catch (e) {
      debugPrint('[AllAnime] Get episodes error: $e');
      throw Exception('Error getting episodes from AllAnime: $e');
    }
  }

  static Future<String> extractVideoURL(String episodeUrl) async {
    try {
      debugPrint('Extracting video URL from page: $episodeUrl');

      final response = await http.get(Uri.parse(episodeUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to get video page: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);

      // Try different selectors for video elements
      final selectors = [
        'video',
        'div[data-video-src]',
        'div[data-src]',
        'div[data-url]',
        'div[data-video]',
        'div[data-player]',
        'iframe[src*="video"]',
        'iframe[src*="player"]',
      ];

      for (String selector in selectors) {
        final elements = document.querySelectorAll(selector);
        if (elements.isNotEmpty) {
          debugPrint('Found elements with selector: $selector');

          // Try different attribute names
          final attributes = [
            'data-video-src',
            'data-src',
            'data-url',
            'data-video',
            'src',
          ];

          for (var element in elements) {
            for (String attr in attributes) {
              final videoSrc = element.attributes[attr];
              if (videoSrc != null && videoSrc.isNotEmpty) {
                debugPrint('Found video URL in attribute $attr: $videoSrc');
                return videoSrc;
              }
            }
          }
        }
      }

      // If no video element found, try to find in page content
      debugPrint('No video elements found, searching in page content');

      // Try to find blogger link
      final bloggerLink = _findBloggerLink(response.body);
      if (bloggerLink.isNotEmpty) {
        debugPrint('Found blogger link: $bloggerLink');
        return bloggerLink;
      }

      // Try to find direct video URL in content
      final videoUrlPattern = RegExp(r'https?://[^\s<>"]+?\.(?:mp4|m3u8)');
      final match = videoUrlPattern.firstMatch(response.body);
      if (match != null) {
        final directUrl = match.group(0)!;
        debugPrint('Found direct video URL: $directUrl');
        return directUrl;
      }

      throw Exception('No video source found in the page');
    } catch (e) {
      throw Exception('Error extracting video URL: $e');
    }
  }

  static Future<VideoStreamResult> extractActualVideoURL(
    String videoSrc,
  ) async {
    try {
      debugPrint('Processing video source: $videoSrc');

      // If it's a blogger.com URL, extract and process the actual video URL
      if (videoSrc.contains('blogger.com')) {
        return await _extractBloggerVideoURL(videoSrc);
      }

      // If the URL is from animefire.plus, fetch the content
      if (videoSrc.contains('animefire.plus/video/')) {
        debugPrint('Found animefire.plus video URL, fetching content...');

        final response = await http.get(Uri.parse(videoSrc));
        if (response.statusCode != 200) {
          throw Exception('Failed to get video data: ${response.statusCode}');
        }

        try {
          // Try to parse as JSON first
          final jsonData = json.decode(response.body);
          final videoResponse = VideoResponse.fromJson(jsonData);

          if (videoResponse.data.isNotEmpty) {
            debugPrint(
              'Found video data with ${videoResponse.data.length} qualities',
            );
            // Return the first available quality (can be enhanced later for quality selection)
            return VideoStreamResult(url: videoResponse.data[0].src);
          }
        } catch (jsonError) {
          debugPrint('Failed to parse as JSON, trying other methods...');
        }

        // Fallback: Try to find direct video URL in content
        final videoUrlPattern = RegExp(r'https?://[^\s<>"]+?\.(?:mp4|m3u8)');
        final match = videoUrlPattern.firstMatch(response.body);
        if (match != null) {
          final directUrl = match.group(0)!;
          debugPrint('Found direct video URL: $directUrl');
          return VideoStreamResult(url: directUrl);
        }

        // Try to find blogger link in the content
        final bloggerLink = _findBloggerLink(response.body);
        if (bloggerLink.isNotEmpty) {
          debugPrint('Found blogger link: $bloggerLink');
          return await _extractBloggerVideoURL(bloggerLink);
        }
      }

      // Default: try to fetch as JSON
      final response = await http.get(Uri.parse(videoSrc));
      if (response.statusCode != 200) {
        throw Exception('Failed to get video data: ${response.statusCode}');
      }

      final jsonData = json.decode(response.body);
      final videoResponse = VideoResponse.fromJson(jsonData);

      if (videoResponse.data.isEmpty) {
        throw Exception('No video data found');
      }

      return VideoStreamResult(url: videoResponse.data[0].src);
    } catch (e) {
      throw Exception('Error extracting actual video URL: $e');
    }
  }

  // Helper function to find Blogger video links
  static String _findBloggerLink(String content) {
    final pattern = RegExp(
      r'https://www\.blogger\.com/video\.g\?token=([A-Za-z0-9_-]+)',
    );
    final match = pattern.firstMatch(content);

    if (match != null) {
      return match.group(0) ?? '';
    }

    return '';
  }

  // Extract actual video URL from Blogger
  static Future<VideoStreamResult> _extractBloggerVideoURL(
    String bloggerUrl,
  ) async {
    try {
      debugPrint('Extracting actual video URL from Blogger: $bloggerUrl');

      final response = await http.get(
        Uri.parse(bloggerUrl),
        headers: {
          HttpHeaders.userAgentHeader: _googleVideoUserAgent,
          HttpHeaders.refererHeader: 'https://animefire.plus/',
        },
      );

      debugPrint('Blogger response status: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');

      if (response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        debugPrint('Found redirect location: $location');

        if (location.contains('googlevideo.com')) {
          return await _createVideoStreamResult(location, referer: bloggerUrl);
        }
      }

      final content = response.body;

      // Try VIDEO_CONFIG first (most reliable method)
      final videoConfigPattern = RegExp(
        r'var\s+VIDEO_CONFIG\s*=\s*({.*?});',
        dotAll: true,
      );
      final videoConfigMatch = videoConfigPattern.firstMatch(content);

      if (videoConfigMatch != null) {
        final configJson = videoConfigMatch.group(1)!;
        debugPrint('Found VIDEO_CONFIG, parsing...');

        try {
          final config = json.decode(configJson) as Map<String, dynamic>;

          if (config.containsKey('streams') && config['streams'] != null) {
            final streams = config['streams'] as List;
            debugPrint('Found ${streams.length} streams in VIDEO_CONFIG');

            for (final stream in streams) {
              if (stream is Map<String, dynamic>) {
                if (stream.containsKey('play_url') &&
                    stream['play_url'] != null) {
                  final videoUrl = stream['play_url'].toString();
                  if (videoUrl.isNotEmpty && videoUrl.contains('http')) {
                    debugPrint(
                      'Found video URL in VIDEO_CONFIG streams: $videoUrl',
                    );
                    return await _createVideoStreamResult(
                      videoUrl,
                      referer: bloggerUrl,
                    );
                  }
                }

                // Check for URL in different field names
                final possibleKeys = [
                  'url',
                  'stream_url',
                  'video_url',
                  'source',
                  'src',
                ];
                for (final key in possibleKeys) {
                  if (stream.containsKey(key) && stream[key] != null) {
                    final videoUrl = stream[key].toString();
                    if (videoUrl.isNotEmpty && videoUrl.contains('http')) {
                      debugPrint(
                        'Found video URL in VIDEO_CONFIG stream[$key]: $videoUrl',
                      );
                      return await _createVideoStreamResult(
                        videoUrl,
                        referer: bloggerUrl,
                      );
                    }
                  }
                }
              }
            }
          }

          if (config.containsKey('video') && config['video'] != null) {
            final video = config['video'] as Map<String, dynamic>;
            final possibleKeys = [
              'play_url',
              'url',
              'stream_url',
              'video_url',
              'source',
              'src',
            ];
            for (final key in possibleKeys) {
              if (video.containsKey(key) && video[key] != null) {
                final videoUrl = video[key].toString();
                if (videoUrl.isNotEmpty && videoUrl.contains('http')) {
                  debugPrint(
                    'Found video URL in VIDEO_CONFIG.video[$key]: $videoUrl',
                  );
                  return await _createVideoStreamResult(
                    videoUrl,
                    referer: bloggerUrl,
                  );
                }
              }
            }
          }

          final possibleKeys = [
            'url',
            'stream_url',
            'video_url',
            'source',
            'src',
          ];
          for (final key in possibleKeys) {
            if (config.containsKey(key) && config[key] != null) {
              final videoUrl = config[key].toString();
              if (videoUrl.isNotEmpty && videoUrl.contains('http')) {
                debugPrint('Found video URL in VIDEO_CONFIG[$key]: $videoUrl');
                return await _createVideoStreamResult(
                  videoUrl,
                  referer: bloggerUrl,
                );
              }
            }
          }
        } catch (jsonError) {
          debugPrint('Failed to parse VIDEO_CONFIG JSON: $jsonError');

          final playUrlPattern = RegExp(r'"play_url"\s*:\s*"([^"]+)"');
          final playUrlMatch = playUrlPattern.firstMatch(configJson);
          if (playUrlMatch != null) {
            final videoUrl = playUrlMatch.group(1)!;
            debugPrint(
              'Extracted play_url directly from JSON string: $videoUrl',
            );
            return await _createVideoStreamResult(
              videoUrl,
              referer: bloggerUrl,
            );
          }
        }
      }

      final patterns = [
        RegExp(
          r'https://[^"\s<>]+videoplayback[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(
          r'https://[^"\s<>]+\.googlevideo\.com[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(
          r'https://[^"\s<>]+\.googleusercontent\.com[^"\s<>]*videoplayback[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(
          r'https://[^"\s<>]+\.googleapis\.com[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(r'stream_url.*?"([^"]*)"', caseSensitive: false),
        RegExp(r'video_url.*?"([^"]*)"', caseSensitive: false),
        RegExp(r'"url":\s*"([^"]*videoplayback[^"]*)"', caseSensitive: false),
        RegExp(r'"url":\s*"([^"]*\.mp4[^"]*)"', caseSensitive: false),
        RegExp(r'https://[^"\s<>]+\.mp4[^"\s<>]*', caseSensitive: false),
      ];

      for (int i = 0; i < patterns.length; i++) {
        final pattern = patterns[i];
        final match = pattern.firstMatch(content);
        if (match != null) {
          String videoUrl = match.group(1) ?? match.group(0)!;
          videoUrl = videoUrl
              .replaceAll(r'\u003d', '=')
              .replaceAll(r'\u0026', '&')
              .replaceAll(r'\/', '/')
              .replaceAll(r'\', '')
              .replaceAll(r'\/', '/');

          debugPrint('Found video URL with pattern ${i + 1}: $videoUrl');

          if (videoUrl.startsWith('http') &&
              (videoUrl.contains('.mp4') ||
                  videoUrl.contains('googlevideo') ||
                  videoUrl.contains('googleusercontent'))) {
            return await _createVideoStreamResult(
              videoUrl,
              referer: bloggerUrl,
            );
          }
        }
      }

      final scriptMatches = RegExp(
        r'<script[^>]*>(.*?)</script>',
        dotAll: true,
      ).allMatches(content);
      for (final scriptMatch in scriptMatches) {
        final scriptContent = scriptMatch.group(1) ?? '';
        final jsPatterns = [
          RegExp(r'https://[^"]+videoplayback[^"]*'),
          RegExp(r'https://[^"]+\.googlevideo\.com[^"]*'),
          RegExp(
            r'https://[^"]+\.googleusercontent\.com[^"]*videoplayback[^"]*',
          ),
        ];

        for (final jsPattern in jsPatterns) {
          final jsMatch = jsPattern.firstMatch(scriptContent);
          if (jsMatch != null) {
            final videoUrl = jsMatch.group(0)!;
            debugPrint('Found video URL in JavaScript: $videoUrl');
            return await _createVideoStreamResult(
              videoUrl,
              referer: bloggerUrl,
            );
          }
        }
      }

      final tokenMatch = RegExp(
        r'token=([A-Za-z0-9_-]+)',
      ).firstMatch(bloggerUrl);
      if (tokenMatch != null) {
        final token = tokenMatch.group(1)!;
        debugPrint('Extracted token: $token');

        final alternativeUrls = [
          'https://www.blogger.com/video-play/mp4/$token',
          'https://blogger.googleusercontent.com/video.g?token=$token',
          'https://redirector.googlevideo.com/videoplayback?token=$token',
        ];

        for (final altUrl in alternativeUrls) {
          debugPrint('Trying alternative URL: $altUrl');
          try {
            final testResponse = await http.head(Uri.parse(altUrl));
            if (testResponse.statusCode == 200 ||
                testResponse.statusCode == 302) {
              debugPrint('Alternative URL works: $altUrl');
              return await _createVideoStreamResult(
                altUrl,
                referer: bloggerUrl,
              );
            }
          } catch (e) {
            debugPrint('Alternative URL failed: $altUrl - $e');
          }
        }
      }

      debugPrint('Could not extract video URL from Blogger response');
      return VideoStreamResult(url: bloggerUrl);
    } catch (e) {
      debugPrint('Error extracting Blogger video URL: $e');
      return VideoStreamResult(url: bloggerUrl);
    }
  }

  static Future<VideoStreamResult> _createVideoStreamResult(
    String url, {
    String? referer,
  }) async {
    if (url.contains('googlevideo.com') || url.contains('videoplayback')) {
      debugPrint('Processing Google Video URL for native playback...');
      return await _processGoogleVideoURL(url, referer: referer);
    }

    return VideoStreamResult(url: url);
  }

  // Process Google Video URLs for native compatibility
  static Future<VideoStreamResult> _processGoogleVideoURL(
    String googleVideoUrl, {
    String? referer,
  }) async {
    try {
      debugPrint('Processing Google Video URL for playback: $googleVideoUrl');

      final originalUri = Uri.parse(googleVideoUrl);
      final sanitizedUri = _sanitizeGoogleVideoUri(originalUri);

      final httpClient = HttpClient();
      httpClient.userAgent = _googleVideoUserAgent;
      httpClient.connectionTimeout = const Duration(seconds: 12);

      final request = await httpClient.getUrl(sanitizedUri);
      request.followRedirects = true;
      request.headers
        ..set(HttpHeaders.acceptHeader, 'video/mp4,video/*;q=0.9,*/*;q=0.8')
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9')
        ..set(HttpHeaders.acceptEncodingHeader, 'identity')
        ..set(HttpHeaders.rangeHeader, 'bytes=0-1')
        ..set(HttpHeaders.refererHeader, referer ?? _bloggerReferer)
        ..set('Origin', _bloggerOrigin)
        ..set(HttpHeaders.connectionHeader, 'keep-alive');

      final response = await request.close();
      final effectiveUri = response.redirects.isNotEmpty
          ? response.redirects.last.location
          : sanitizedUri;
      final cookies = response.cookies;
      debugPrint('Google Video URL response status: ${response.statusCode}');
      await response.drain();
      httpClient.close(force: true);

      final cookieHeader = cookies.isEmpty
          ? ''
          : cookies
                .map((cookie) => '${cookie.name}=${cookie.value}')
                .join('; ');

      final headers = <String, String>{
        HttpHeaders.userAgentHeader: _googleVideoUserAgent,
        HttpHeaders.acceptHeader: 'video/mp4,video/*;q=0.9,*/*;q=0.8',
        HttpHeaders.acceptLanguageHeader: 'en-US,en;q=0.9',
        HttpHeaders.acceptEncodingHeader: 'identity',
        HttpHeaders.refererHeader: referer ?? _bloggerReferer,
        'Origin': _bloggerOrigin,
      };

      if (cookieHeader.isNotEmpty) {
        headers[HttpHeaders.cookieHeader] = cookieHeader;
      }

      final finalUrl = effectiveUri.toString();
      debugPrint('Cleaned Google Video URL: $finalUrl');

      return VideoStreamResult(url: finalUrl, headers: headers);
    } catch (e) {
      debugPrint('Error processing Google Video URL: $e');
      return VideoStreamResult(url: googleVideoUrl);
    }
  }

  // Sanitize Google Video URI by removing problematic parameters
  static Uri _sanitizeGoogleVideoUri(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);

    params.remove('requiressl');

    final rmParams = params.keys.where((k) => k.startsWith('rm')).toList();
    for (final key in rmParams) {
      params.remove(key);
    }

    params.remove('ms');
    params.remove('mv');
    params.remove('pl');
    params.remove('ip');
    params.remove('ipbits');

    if (params.containsKey('ratebypass')) {
      params['ratebypass'] = 'yes';
    }

    return uri.replace(queryParameters: params);
  }

  static String _treatAnimeName(String animeName) {
    return animeName.toLowerCase().replaceAll(' ', '-');
  }
}
