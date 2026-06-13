/// Utilitários para extração de informações de episódios
library;

/// Extrai apenas o número do episódio de um texto completo
/// Exemplo: "Dandadan - Episódio 5" -> "5"
String extractEpisodeNumber(String episodeText) {
  final episodeNumber = int.tryParse(episodeText);
  if (episodeNumber != null) {
    return episodeText;
  }

  // Tenta extrair número do texto usando diferentes padrões
  final patterns = [
    RegExp(r'Episódio\s*(\d+)', caseSensitive: false),
    RegExp(r'Episode\s*(\d+)', caseSensitive: false),
    RegExp(r'Ep\.?\s*(\d+)', caseSensitive: false),
    RegExp(r'-\s*(\d+)$'),
    RegExp(r'\d+'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(episodeText);
    if (match != null) {
      if (match.groupCount > 0) {
        return match.group(1) ?? match.group(0) ?? episodeText;
      }
    }
  }

  return episodeText;
}

/// Gera uma chave única para identificar um episódio
/// Usada para evitar conflitos entre múltiplas instâncias do player
String buildEpisodeKey({
  required String animeTitle,
  required String episodeNumber,
  required String episodeUrl,
  String? animeAnilistId,
  String? animeMalId,
  String? animeAllAnimeId,
  String? animeUrl,
}) {
  final buffer = StringBuffer()
    ..write(animeTitle)
    ..write('::')
    ..write(episodeNumber)
    ..write('::')
    ..write(episodeUrl);

  final identifiers = <String?>[
    animeAnilistId,
    animeMalId,
    animeAllAnimeId,
    animeUrl,
  ];

  final extraIdentifier = identifiers.firstWhere(
    (value) => value != null && value.isNotEmpty,
    orElse: () => null,
  );

  if (extraIdentifier != null) {
    buffer
      ..write('::')
      ..write(extraIdentifier);
  }

  return buffer.toString();
}
