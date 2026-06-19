import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../domain/models/anime.dart';
import '../../domain/models/episode.dart';
import '../../domain/models/video.dart';
import '../../services/episode_thumbnail_service.dart';
import 'anilist_service.dart';

class AnimeService {
  static const String baseSiteUrl = 'https://animefire.plus';
  static const String _googleVideoUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1';

  static Future<List<Anime>> searchAnime(String animeName) async {
    try {
      debugPrint('[AnimeService] Searching in AnimeFire: $animeName');

      // Search in AnimeFire only
      final results = await _searchAnimeFire(animeName);

      debugPrint('[AnimeService] Total results: ${results.length}');

      // Enriquecer com dados do AniList em paralelo
      await Future.wait(results.map((anime) => enrichAnimeWithAniList(anime)));

      return results;
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

      final List<Anime> animes = [];
      for (final element in animeElements) {
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

      return await _getEpisodesFromAnimeFire(anime);
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
      final List<int> episodeNumbers = [];
      final List<Episode> tempEpisodes = [];

      for (final element in episodeElements) {
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

      final List<Episode> episodes = [];
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

      for (final String selector in selectors) {
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

          for (final element in elements) {
            for (final String attr in attributes) {
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

      final tokenMatch = RegExp(
        r'token=([A-Za-z0-9_-]+)',
      ).firstMatch(bloggerUrl);
      if (tokenMatch == null) {
        debugPrint('No token found in Blogger URL');
        return VideoStreamResult(url: bloggerUrl);
      }
      final token = tokenMatch.group(1)!;
      debugPrint('Extracted Blogger token: $token');

      // Step 1: Fetch the Blogger page to get session info (f.sid, bl)
      final pageClient = HttpClient();
      pageClient.userAgent = _googleVideoUserAgent;
      pageClient.connectionTimeout = const Duration(seconds: 15);

      String fSid = '';
      String bl = 'boq_bloggeruiserver_20260610.02_p0';

      try {
        final pageRequest = await pageClient.getUrl(Uri.parse(bloggerUrl));
        pageRequest.headers
          ..set(HttpHeaders.userAgentHeader, _googleVideoUserAgent)
          ..set(HttpHeaders.refererHeader, 'https://animefire.plus/')
          ..set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml,*/*')
          ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9')
          ..set(HttpHeaders.connectionHeader, 'keep-alive');

        final pageResponse = await pageRequest.close();
        final pageContent = await _collectResponse(pageResponse);

        final sidPattern = RegExp(r'"SNlM0e"\s*:\s*"([^"]+)"');
        final sidMatch = sidPattern.firstMatch(pageContent);
        if (sidMatch != null) {
          fSid = sidMatch.group(1)!;
          debugPrint('Found f.sid: $fSid');
        }

        final blPattern = RegExp(r'"boq_bloggeruiserver_[^"]+"');
        final blMatch = blPattern.firstMatch(pageContent);
        if (blMatch != null) {
          bl = blMatch.group(0)!.replaceAll('"', '');
          debugPrint('Found bl: $bl');
        }
      } catch (e) {
        debugPrint('Failed to fetch Blogger page for session info: $e');
      }
      pageClient.close(force: true);

      // Step 2: Call batchexecute API to get the actual video URLs
      final batchClient = HttpClient();
      batchClient.userAgent = _googleVideoUserAgent;
      batchClient.connectionTimeout = const Duration(seconds: 15);

      try {
        final queryParams = <String, String>{
          'rpcids': 'WcwnYd',
          'source-path': '/video.g',
          'bl': bl,
          'hl': 'pt-BR',
          '_reqid': '${DateTime.now().millisecondsSinceEpoch}',
          'rt': 'c',
        };
        if (fSid.isNotEmpty) {
          queryParams['f.sid'] = fSid;
        }

        final batchUrl = Uri.https(
          'www.blogger.com',
          '/_/BloggerVideoPlayerUi/data/batchexecute',
          queryParams,
        );

        debugPrint('Calling Blogger batchexecute API');

        final fReq = jsonEncode([
          [
            [
              'WcwnYd',
              jsonEncode([token, null, 0]),
              null,
              'generic',
            ],
          ],
        ]);

        final requestBody = 'f.req=${Uri.encodeComponent(fReq)}&';

        final batchRequest = await batchClient.postUrl(batchUrl);
        batchRequest.headers
          ..set(HttpHeaders.userAgentHeader, _googleVideoUserAgent)
          ..set(
            HttpHeaders.contentTypeHeader,
            'application/x-www-form-urlencoded;charset=UTF-8',
          )
          ..set(HttpHeaders.refererHeader, 'https://www.blogger.com/')
          ..set('origin', 'https://www.blogger.com')
          ..set(HttpHeaders.acceptHeader, '*/*')
          ..set(HttpHeaders.acceptLanguageHeader, 'pt-BR,pt;q=0.9,en-US;q=0.8')
          ..set('sec-ch-ua', '"Google Chrome";v="149", "Chromium";v="149"')
          ..set('sec-ch-ua-mobile', '?0')
          ..set('sec-ch-ua-platform', '"Windows"')
          ..set('sec-fetch-dest', 'empty')
          ..set('sec-fetch-mode', 'cors')
          ..set('sec-fetch-site', 'same-origin')
          ..set('x-same-domain', '1');

        batchRequest.write(requestBody);

        final batchResponse = await batchRequest.close();
        final batchContent = await _collectResponse(batchResponse);

        debugPrint(
          'Batchexecute response (${batchResponse.statusCode}): ${batchContent.length} bytes',
        );

        if (batchResponse.statusCode == 200) {
          final result = _parseBatchexecuteResponse(batchContent, bloggerUrl);
          if (result != null) {
            batchClient.close(force: true);
            return result;
          }
        }
      } catch (e) {
        debugPrint('Batchexecute API call failed: $e');
      }
      batchClient.close(force: true);

      // Fallback: try the old HTML parsing approach
      debugPrint('Falling back to HTML parsing approach...');
      return await _extractBloggerFromHTML(bloggerUrl);
    } catch (e) {
      debugPrint('Error extracting Blogger video URL: $e');
      return VideoStreamResult(url: bloggerUrl);
    }
  }

  static VideoStreamResult? _parseBatchexecuteResponse(
    String content,
    String bloggerUrl,
  ) {
    debugPrint('Parsing batchexecute response...');

    // Format: )]}\'\n{length}\n[["wrb.fr","WcwnYd","json_string",...]]
    final lines = content.split('\n');
    if (lines.length < 3) {
      debugPrint('Unexpected batchexecute response format');
      return null;
    }

    String jsonLine = '';
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('[[') || trimmed.startsWith('["')) {
        jsonLine = trimmed;
        break;
      }
    }

    if (jsonLine.isEmpty) {
      debugPrint('No JSON line found in batchexecute response');
      return null;
    }

    try {
      final outerArray = jsonDecode(jsonLine) as List;
      if (outerArray.isEmpty) return null;

      final innerArray = outerArray[0] as List;
      if (innerArray.length < 3) return null;

      final innerJsonString = innerArray[2] as String;
      debugPrint(
        'Inner JSON string (first 500 chars): ${innerJsonString.substring(0, innerJsonString.length > 500 ? 500 : innerJsonString.length)}',
      );

      final innerData = jsonDecode(innerJsonString) as List;

      // Structure: [1, null, [[url1, [itag1]], [url2, [itag2]], ...]]
      if (innerData.length >= 3 && innerData[2] is List) {
        final streams = innerData[2] as List;

        String? bestUrl;
        int bestItag = 0;

        for (final stream in streams) {
          if (stream is List && stream.length >= 2) {
            var url = stream[0] as String;
            final itagInfo = stream[1] as List;
            final itag = itagInfo[0] as int;

            url = url
                .replaceAll(r'\u003d', '=')
                .replaceAll(r'\u0026', '&')
                .replaceAll(r'\u003c', '<')
                .replaceAll(r'\u003e', '>')
                .replaceAll(r'\/', '/');

            debugPrint(
              'Found stream: itag=$itag, url=${url.substring(0, url.length > 100 ? 100 : url.length)}...',
            );

            if (itag > bestItag && url.contains('googlevideo.com')) {
              bestItag = itag;
              bestUrl = url;
            }
          }
        }

        if (bestUrl != null) {
          debugPrint('Best stream: itag=$bestItag');
          return _googleVideoResult(bestUrl);
        }
      }
    } catch (e) {
      debugPrint('Failed to parse batchexecute response: $e');
    }

    // Fallback: find any googlevideo URL in the response
    final urlPattern = RegExp(
      r'https://[^"\\]+\.googlevideo\.com/videoplayback[^"\\]*',
    );
    final urlMatch = urlPattern.firstMatch(content);
    if (urlMatch != null) {
      final videoUrl = urlMatch
          .group(0)!
          .replaceAll(r'\u003d', '=')
          .replaceAll(r'\u0026', '&')
          .replaceAll(r'\/', '/');
      debugPrint('Found googlevideo URL in response');
      return _googleVideoResult(videoUrl);
    }

    return null;
  }

  static Future<VideoStreamResult> _extractBloggerFromHTML(
    String bloggerUrl,
  ) async {
    try {
      final httpClient = HttpClient();
      httpClient.userAgent = _googleVideoUserAgent;
      httpClient.connectionTimeout = const Duration(seconds: 15);

      final request = await httpClient.getUrl(Uri.parse(bloggerUrl));
      request.headers
        ..set(HttpHeaders.userAgentHeader, _googleVideoUserAgent)
        ..set(HttpHeaders.refererHeader, 'https://animefire.plus/')
        ..set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml,*/*')
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9')
        ..set(HttpHeaders.connectionHeader, 'keep-alive');
      request.followRedirects = true;

      final response = await request.close();
      final content = await _collectResponse(response);
      httpClient.close(force: true);

      return _parseBloggerContent(content, bloggerUrl) ??
          VideoStreamResult(url: bloggerUrl);
    } catch (e) {
      debugPrint('HTML fallback extraction failed: $e');
      return VideoStreamResult(url: bloggerUrl);
    }
  }

  static Future<String> _collectResponse(HttpClientResponse response) async {
    final buffer = StringBuffer();
    await for (final chunk in response.transform(utf8.decoder)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  static VideoStreamResult _googleVideoResult(String url) {
    return VideoStreamResult(
      url: url,
      headers: const {
        'Referer': 'https://www.blogger.com/',
        'Origin': 'https://www.blogger.com',
      },
      isGoogleVideo: true,
    );
  }

  static VideoStreamResult? _parseBloggerContent(
    String content,
    String bloggerUrl,
  ) {
    debugPrint('Parsing Blogger page content (${content.length} bytes)');

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
                  return videoUrl.contains('googlevideo')
                      ? _googleVideoResult(videoUrl)
                      : VideoStreamResult(url: videoUrl);
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
                if (stream.containsKey(key) && stream[key] != null) {
                  final videoUrl = stream[key].toString();
                  if (videoUrl.isNotEmpty && videoUrl.contains('http')) {
                    debugPrint(
                      'Found video URL in VIDEO_CONFIG stream[$key]: $videoUrl',
                    );
                    return videoUrl.contains('googlevideo')
                        ? _googleVideoResult(videoUrl)
                        : VideoStreamResult(url: videoUrl);
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
                return videoUrl.contains('googlevideo')
                    ? _googleVideoResult(videoUrl)
                    : VideoStreamResult(url: videoUrl);
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
              return videoUrl.contains('googlevideo')
                  ? _googleVideoResult(videoUrl)
                  : VideoStreamResult(url: videoUrl);
            }
          }
        }
      } catch (jsonError) {
        debugPrint('Failed to parse VIDEO_CONFIG JSON: $jsonError');

        final playUrlPattern = RegExp(r'"play_url"\s*:\s*"([^"]+)"');
        final playUrlMatch = playUrlPattern.firstMatch(configJson);
        if (playUrlMatch != null) {
          final videoUrl = playUrlMatch.group(1)!;
          debugPrint('Extracted play_url directly from JSON string: $videoUrl');
          return videoUrl.contains('googlevideo')
              ? _googleVideoResult(videoUrl)
              : VideoStreamResult(url: videoUrl);
        }
      }
    }

    // Try broader JSON patterns for video URLs
    final jsonUrlPatterns = [
      RegExp(r'"play_url"\s*:\s*"([^"]+)"'),
      RegExp(r'"stream_url"\s*:\s*"([^"]+)"'),
      RegExp(r'"video_url"\s*:\s*"([^"]+)"'),
      RegExp(r'"source"\s*:\s*"(https?://[^"]+)"'),
      RegExp(r'"src"\s*:\s*"(https?://[^"]+)"'),
    ];

    for (final pattern in jsonUrlPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        var videoUrl = match.group(1)!;
        videoUrl = videoUrl
            .replaceAll(r'\u003d', '=')
            .replaceAll(r'\u0026', '&')
            .replaceAll(r'\/', '/');
        if (videoUrl.contains('googlevideo') ||
            videoUrl.contains('.mp4') ||
            videoUrl.contains('videoplayback')) {
          debugPrint('Found video URL with JSON pattern: $videoUrl');
          return videoUrl.contains('googlevideo')
              ? _googleVideoResult(videoUrl)
              : VideoStreamResult(url: videoUrl);
        }
      }
    }

    // Try regex patterns for video URLs
    final patterns = [
      RegExp(r'https://[^"\s<>]+videoplayback[^"\s<>]*', caseSensitive: false),
      RegExp(
        r'https://[^"\s<>]+\.googlevideo\.com[^"\s<>]*',
        caseSensitive: false,
      ),
      RegExp(
        r'https://[^"\s<>]+\.googleusercontent\.com[^"\s<>]*videoplayback[^"\s<>]*',
        caseSensitive: false,
      ),
      RegExp(r'https://[^"\s<>]+\.mp4[^"\s<>]*', caseSensitive: false),
    ];

    for (int i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      final match = pattern.firstMatch(content);
      if (match != null) {
        var videoUrl = match.group(1) ?? match.group(0)!;
        videoUrl = videoUrl
            .replaceAll(r'\u003d', '=')
            .replaceAll(r'\u0026', '&')
            .replaceAll(r'\/', '/')
            .replaceAll(r'\', '')
            .replaceAll(r'\/', '/');

        debugPrint('Found video URL with pattern ${i + 1}: $videoUrl');
        return videoUrl.contains('googlevideo')
            ? _googleVideoResult(videoUrl)
            : VideoStreamResult(url: videoUrl);
      }
    }

    // Scan script blocks
    final scriptMatches = RegExp(
      r'<script[^>]*>(.*?)</script>',
      dotAll: true,
    ).allMatches(content);
    for (final scriptMatch in scriptMatches) {
      final scriptContent = scriptMatch.group(1) ?? '';
      final jsPatterns = [
        RegExp(r'https://[^"]+videoplayback[^"]*'),
        RegExp(r'https://[^"]+\.googlevideo\.com[^"]*'),
        RegExp(r'https://[^"]+\.googleusercontent\.com[^"]*videoplayback[^"]*'),
      ];

      for (final jsPattern in jsPatterns) {
        final jsMatch = jsPattern.firstMatch(scriptContent);
        if (jsMatch != null) {
          final videoUrl = jsMatch.group(0)!;
          debugPrint('Found video URL in JavaScript: $videoUrl');
          return videoUrl.contains('googlevideo')
              ? _googleVideoResult(videoUrl)
              : VideoStreamResult(url: videoUrl);
        }
      }
    }

    // Look for any JSON-escaped video URLs
    final escapedUrlPattern = RegExp(
      r'https?:.{0,4}video.{0,200}',
      caseSensitive: false,
    );
    final escapedMatch = escapedUrlPattern.firstMatch(content);
    if (escapedMatch != null) {
      final videoUrl = escapedMatch
          .group(0)!
          .replaceAll(r'\u003d', '=')
          .replaceAll(r'\u0026', '&')
          .replaceAll(r'\/', '/')
          .replaceAll(r'\\', '/');
      if (videoUrl.contains('googlevideo') ||
          videoUrl.contains('.mp4') ||
          videoUrl.contains('videoplayback')) {
        debugPrint('Found escaped video URL: $videoUrl');
        return videoUrl.contains('googlevideo')
            ? _googleVideoResult(videoUrl)
            : VideoStreamResult(url: videoUrl);
      }
    }

    debugPrint('No video URL found in Blogger content');
    return null;
  }

  static String _treatAnimeName(String animeName) {
    return animeName.toLowerCase().replaceAll(' ', '-');
  }
}
