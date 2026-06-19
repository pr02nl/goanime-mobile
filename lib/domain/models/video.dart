class VideoData {
  final String src;
  final String label;

  VideoData({required this.src, required this.label});

  factory VideoData.fromJson(Map<String, dynamic> json) {
    return VideoData(src: json['src'] ?? '', label: json['label'] ?? '');
  }
}

class VideoResponse {
  final List<VideoData> data;
  final Map<String, dynamic> resposta;

  VideoResponse({required this.data, required this.resposta});

  factory VideoResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    final List<VideoData> videoDataList = dataList
        .map((item) => VideoData.fromJson(item))
        .toList();

    return VideoResponse(data: videoDataList, resposta: json['resposta'] ?? {});
  }
}

class VideoStreamResult {
  final String url;
  final Map<String, String> headers;
  final bool isGoogleVideo;

  const VideoStreamResult({
    required this.url,
    Map<String, String>? headers,
    this.isGoogleVideo = false,
  }) : headers = headers ?? const {};

  bool get hasHeaders => headers.isNotEmpty;
}
