/// Estatísticas agregadas de progresso de um anime PauloFlix.
///
/// **Computado em runtime** (decisão 7 do plano
/// `.hermes/plans/2026-06-22_2230-pauloflix-episodes-progress.md`) — não
/// há flag persistida em `paulo_flix_content`.
///
/// Produzido por `PauloFlixEpisodeProgressRepository.getStatsForContent(contentId)`
/// via 1 query SQL com `COUNT` + `SUM(CASE WHEN ...)` agregado por season.
///
/// Usos:
/// - `progressRatio` → barra de progresso no card "Continue assistindo" da
///   home (decisão 8).
/// - `isAnimeCompleted` → pode ser usado para badge "✓ Anime completo" em
///   cards (futuro, fora do escopo desta feature).
/// - `isAnimeInProgress` → query alternativa para a home se quisermos
///   mostrar "Em andamento" mesmo sem ter `positionSeconds > 0` (futuro).
class PauloFlixProgressStats {
  /// Total de episódios do anime (soma de todas as seasons).
  final int totalEpisodes;

  /// Quantos episódios estão com `isCompleted = true`.
  final int completedEpisodes;

  /// Quantos episódios estão parcialmente assistidos
  /// (`positionSeconds > 0 && isCompleted = false`).
  /// Exclui episódios completados e episódios nunca abertos.
  final int inProgressEpisodes;

  const PauloFlixProgressStats({
    required this.totalEpisodes,
    required this.completedEpisodes,
    required this.inProgressEpisodes,
  });

  /// Progresso como fração 0.0 (nenhum) a 1.0 (todos completos).
  ///
  /// Retorna 0.0 quando `totalEpisodes == 0` (anime sem nenhum episode
  /// sincronizado ainda — "não começou" ≠ "completou nada").
  double get progressRatio =>
      totalEpisodes == 0 ? 0.0 : completedEpisodes / totalEpisodes;

  /// `true` se o anime inteiro foi assistido (todos os episódios
  /// completados e há pelo menos 1 episódio conhecido).
  ///
  /// Anime sem episodes (`totalEpisodes == 0`) **não** é considerado
  /// completo — significa "ainda não sincronizou", não "assistiu tudo".
  bool get isAnimeCompleted =>
      totalEpisodes > 0 && completedEpisodes == totalEpisodes;

  /// `true` se o anime tem pelo menos 1 episódio parcialmente assistido.
  /// Útil para a query alternativa "em andamento" que não depende de
  /// `positionSeconds > 0` (mas isso é derivado do banco, não do stats).
  bool get isAnimeInProgress => inProgressEpisodes > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PauloFlixProgressStats &&
          totalEpisodes == other.totalEpisodes &&
          completedEpisodes == other.completedEpisodes &&
          inProgressEpisodes == other.inProgressEpisodes;

  @override
  int get hashCode => Object.hash(
        totalEpisodes,
        completedEpisodes,
        inProgressEpisodes,
      );

  @override
  String toString() =>
      'PauloFlixProgressStats(total=$totalEpisodes, '
      'completed=$completedEpisodes, inProgress=$inProgressEpisodes)';
}
