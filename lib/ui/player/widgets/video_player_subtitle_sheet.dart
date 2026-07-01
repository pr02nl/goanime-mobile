/// Seletor de legendas do player de vídeo.
///
/// Extraído de `video_player_screen.dart` para reduzir o tamanho do
/// arquivo orquestrador. Responsabilidades:
/// - Tag clicável que mostra a legenda ativa
/// - Bottom sheet com opções de legendas (embutidas + externas)
/// - Seleção de legenda via `media_kit` Player
library;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/logger/app_logger.dart';

import '../../../domain/models/episode.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';

/// Widget que exibe uma tag clicável de legenda e abre o seletor.
///
///[Uso]:
/// ```dart
/// SubtitleSelectorTag(
///   player: _player,
///   currentEpisode: _currentEpisode,
///   embeddedSubtitleTracks: _embeddedSubtitleTracks,
///   onSubtitleChanged: () => setState(() {}),
/// )
/// ```
class SubtitleSelectorTag extends StatelessWidget {
  final Player? player;
  final Episode currentEpisode;
  final List<SubtitleTrack> embeddedSubtitleTracks;
  final VoidCallback onSubtitleChanged;

  const SubtitleSelectorTag({
    super.key,
    required this.player,
    required this.currentEpisode,
    required this.embeddedSubtitleTracks,
    required this.onSubtitleChanged,
  });

  /// Retorna `true` se o player tem pelo menos uma legenda disponível —
  /// seja embutida no MKV ou externa (.srt) do PauloFlix.
  bool hasAnySubtitleTrack() {
    return embeddedSubtitleTracks.isNotEmpty ||
        currentEpisode.subtitleTracks.any((s) => s.url != null);
  }

  /// Devolve o rótulo da faixa ativa, ou null se está em "Auto"/desconhecido.
  String? _effectiveActiveSubtitleLabel(BuildContext context) {
    final current = player?.state.track.subtitle;
    if (current == null) return null;
    if (current.id == 'no') return AppLocalizations.of(context).noSubtitle;
    if (current.id == 'auto') return AppLocalizations.of(context).auto;
    for (final ext in currentEpisode.subtitleTracks) {
      if (ext.url != null && current.id == ext.url) return ext.displayName;
    }
    for (final embed in embeddedSubtitleTracks) {
      if (current.id == embed.id) {
        return embed.title ??
            embed.language ??
            AppLocalizations.of(context).subtitleEmbedded;
      }
    }
    return current.title ?? current.language;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasAnySubtitleTrack()) return const SizedBox.shrink();

    final active = _effectiveActiveSubtitleLabel(context);
    return FocusableWidget(
      onSelect: () => _showSubtitleSheet(context),
      borderRadius: 6,
      focusPadding: EdgeInsets.zero,
      focusScale: 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.closed_caption_rounded,
              color: Color(0xFFEF4444),
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              active ?? AppLocalizations.of(context).subtitles,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: Color(0xFFEF4444),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubtitleSheet(BuildContext context) async {
    final external = currentEpisode.subtitleTracks
        .where((s) => s.url != null)
        .toList();
    final embedded = embeddedSubtitleTracks;
    if (external.isEmpty && embedded.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.closed_caption_rounded,
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.subtitles,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                _buildSubtitleSheetOption(
                  context: sheetContext,
                  icon: Icons.auto_awesome_rounded,
                  label: l10n.autoRecommended,
                  subtitle: l10n.autoDescription,
                  isActive: _isCurrentSubtitleAuto(),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _selectSubtitle(
                      SubtitleTrack.auto(),
                      label: l10n.auto,
                    );
                  },
                ),
                _buildSubtitleSheetOption(
                  context: sheetContext,
                  icon: Icons.subtitles_off_rounded,
                  label: l10n.subtitlesOff,
                  subtitle: l10n.subtitlesOffDescription,
                  isActive: _isCurrentSubtitleNone(),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _selectSubtitle(
                      SubtitleTrack.no(),
                      label: l10n.subtitlesOff,
                    );
                  },
                ),
                if (embedded.isNotEmpty) ...[
                  _buildSectionHeader(l10n.embeddedSubtitles),
                  for (final t in embedded)
                    _buildSubtitleSheetOption(
                      context: sheetContext,
                      icon: Icons.movie_outlined,
                      label: t.title ?? t.language ?? 'Track ${t.id}',
                      subtitle: t.language ?? l10n.unknownLanguage,
                      isActive: _isCurrentSubtitleTrack(t),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _selectSubtitle(
                          t,
                          label:
                              t.title ?? t.language ?? l10n.subtitleEmbedded,
                        );
                      },
                    ),
                ],
                if (external.isNotEmpty) ...[
                  _buildSectionHeader(l10n.externalSubtitles),
                  for (final s in external)
                    _buildSubtitleSheetOption(
                      context: sheetContext,
                      icon: Icons.subtitles_rounded,
                      label: s.displayName,
                      subtitle: '${s.language} • .srt',
                      isActive: _isCurrentExternalSubtitle(s),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _selectSubtitle(
                          SubtitleTrack.uri(
                            s.url!,
                            title: s.displayName,
                            language: s.language,
                          ),
                          label: s.displayName,
                        );
                      },
                    ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitleSheetOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 8,
      focusPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      focusScale: 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFEF4444) : Colors.white60,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  bool _isCurrentSubtitleAuto() {
    final cur = player?.state.track.subtitle;
    if (cur == null) return true;
    return cur.id == 'auto';
  }

  bool _isCurrentSubtitleNone() {
    final cur = player?.state.track.subtitle;
    return cur?.id == 'no';
  }

  bool _isCurrentSubtitleTrack(SubtitleTrack t) {
    final cur = player?.state.track.subtitle;
    return cur != null && cur.id == t.id;
  }

  bool _isCurrentExternalSubtitle(EpisodeSubtitleTrack ext) {
    final cur = player?.state.track.subtitle;
    if (cur == null || ext.url == null) return false;
    return cur.id == ext.url;
  }

  Future<void> _selectSubtitle(SubtitleTrack track, {String? label}) async {
    try {
      await player?.setSubtitleTrack(track);
      const AppLogger('VideoPlayer').debug('Subtitle changed to: ${label ?? track.id}');
    } catch (e, st) {
      const AppLogger('VideoPlayer').warning('Failed to change subtitle', e, st);
    }
    onSubtitleChanged();
  }
}
