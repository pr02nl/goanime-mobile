/// Models for TheIntroDB API
///
/// API base: `https://api.theintrodb.org/v3`
/// Docs: https://theintrodb.org/docs
///
/// Response format (JSON):
/// ```json
/// {
///   "intro": [{ "start_ms": null, "end_ms": 90000 }],
///   "credits": [{ "start_ms": 1800000, "end_ms": null }],
///   "recap": [...],
///   "preview": [...]
/// }
/// ```
/// Times are in milliseconds. `start_ms: null` = beginning of media,
/// `end_ms: null` = end of media.
library;

class IntroDbSegment {
  /// Start time in seconds. `0.0` when API returned `null` (beginning).
  final double startSec;

  /// End time in seconds. `double.infinity` when API returned `null`
  /// (end of media).
  final double endSec;

  IntroDbSegment({required this.startSec, required this.endSec});

  factory IntroDbSegment.fromJson(Map<String, dynamic> json) {
    final startMs = json['start_ms'] as int?;
    final endMs = json['end_ms'] as int?;
    return IntroDbSegment(
      startSec: startMs != null ? startMs / 1000.0 : 0.0,
      endSec: endMs != null ? endMs / 1000.0 : double.infinity,
    );
  }
}

/// Resposta completa da API TheIntroDB para um media.
///
/// Cada campo é uma lista porque a base comunitária pode ter múltiplas
/// submissões para o mesmo segmento. O mixin usa o PRIMEIRO item de cada
/// lista (o mais verificado/confiável).
class IntroDbResponse {
  final List<IntroDbSegment> intro;
  final List<IntroDbSegment> credits;
  final List<IntroDbSegment> recap;
  final List<IntroDbSegment> preview;

  IntroDbResponse({
    required this.intro,
    required this.credits,
    required this.recap,
    required this.preview,
  });

  factory IntroDbResponse.fromJson(Map<String, dynamic> json) {
    return IntroDbResponse(
      intro: _parseSegments(json['intro']),
      credits: _parseSegments(json['credits']),
      recap: _parseSegments(json['recap']),
      preview: _parseSegments(json['preview']),
    );
  }

  static List<IntroDbSegment> _parseSegments(dynamic data) {
    if (data == null || data is! List) return [];
    return data
        .map((e) => IntroDbSegment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retorna `true` se há pelo menos um segmento de intro ou créditos.
  bool get hasAnySegment =>
      intro.isNotEmpty || credits.isNotEmpty || recap.isNotEmpty;
}
