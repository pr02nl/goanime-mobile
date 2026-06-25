/// Card de episódio no estilo Netflix com thumbnail e metadados.
///
/// Exibe thumbnail 16:9, número do episódio (S01E01), título,
/// duração e botão play proeminente.
///
/// **Fase N+7:**扩e schema NFO V2 — exibe 5 campos adicionais
/// quando disponíveis:
/// - `originalTitle` (idioma original, ex: japonês) — abaixo do título.
/// - `outline` (resumo curto 1-2 frases) — em vez de plot (que pode
///   ser longo).
/// - `aired` (data de estreia) — ícone calendário.
/// - `rating` (nota do episode) — ícone estrela + valor.
/// - `runtime` (duração em minutos do NFO) — ícone relógio.
///
/// Os 5 props são nullable; o card degrada gracioso se ausentes
/// (NFOs antigos não têm esses campos).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/pauloflix_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/focusable_widget.dart';

/// Card de episódio estilo Netflix.
///
/// [Uso]:
/// ```dart
/// PauloflixEpisodeCard(
///   episode: episode,
///   seasonNumber: 1,
///   thumbnailUrl: 'https://...',
///   onTap: () => playEpisode(episode),
/// )
/// ```
class PauloflixEpisodeCard extends StatelessWidget {
  final PauloFlixEpisode episode;
  final int seasonNumber;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final bool isTV;

  // ═══════════════════════════════════════════════════════════════════════
  // Fase 3 — Indicadores de progresso (PauloFlix)
  // ═══════════════════════════════════════════════════════════════════════

  /// Posição salva do episódio (segundos). `null` ou `0` = nunca
  /// assistido. Quando `> 0 && !isCompleted` → mostra barra de
  /// progresso.
  final int? positionSeconds;

  /// Duração total do vídeo (segundos). Usada para calcular o ratio
  /// da barra. `null` = sem info, mostra barra indeterminada ou 0.
  final int? durationSeconds;

  /// Flag `isCompleted` do banco. Quando `true` → mostra ícone ✓
  /// verde em vez da barra.
  final bool isCompleted;

  // ═══════════════════════════════════════════════════════════════════════
  // Fase N+7 — Metadados NFO V2 do episode (originalTitle, outline,
  // aired, rating, runtime). Vêm do `S\d+E\d+\.nfo`. Todos opcionais
  // — NFOs antigos não têm. Card degrada gracioso se ausentes.
  // ═══════════════════════════════════════════════════════════════════════

  /// Título original (idioma da produção, ex: japonês). Vem de
  /// `<originaltitle>`. Mostrado como subtítulo discreto abaixo
  /// do título principal (que pode estar localizado em PT-BR).
  final String? originalTitle;

  /// Resumo curto do episode (1-2 frases). Vem de `<outline>`.
  /// Quando presente, substitui a exibição de `description` (plot
  /// longo) na row de metadados. Usado em cards compactos onde
  /// o plot não cabe.
  final String? outline;

  /// Data de estreia do episode. Vem de `<aired>` (formato
  /// `YYYY-MM-DD`). Exibido como "5 dez 2021" (PT-BR) ou
  /// "5 Dec 2021" (EN).
  final DateTime? aired;

  /// Rating / nota do episode (0.0-10.0). Vem de `<rating>`.
  /// Exibido como "★ 7.3".
  final double? rating;

  /// Duração do episode em minutos (NFO usa minutos, não
  /// segundos). Vem de `<runtime>`. Exibido como "🕐 47 min".
  /// Complementa `durationSeconds` (que vem do player em runtime).
  final int? runtime;

  const PauloflixEpisodeCard({
    super.key,
    required this.episode,
    required this.seasonNumber,
    this.thumbnailUrl,
    required this.onTap,
    this.isTV = false,
    this.positionSeconds,
    this.durationSeconds,
    this.isCompleted = false,
    // Schema V2扩e (Fase N+7): 5 campos NFO扩idos. Todos
    // default `null` (NFOs antigos não têm).
    this.originalTitle,
    this.outline,
    this.aired,
    this.rating,
    this.runtime,
  });

  /// Computa o ratio de progresso (0.0 a 1.0) para a barra.
  /// Retorna `0.0` se `durationSeconds` for null/0 ou
  /// `positionSeconds` for null/0.
  double get _progressRatio {
    final dur = durationSeconds;
    final pos = positionSeconds;
    if (dur == null || dur <= 0 || pos == null || pos <= 0) return 0.0;
    final r = pos / dur;
    return r > 1.0 ? 1.0 : r;
  }

  /// `true` se deve mostrar a barra de progresso (em andamento).
  bool get _showProgressBar {
    if (isCompleted) return false;
    final pos = positionSeconds;
    return pos != null && pos > 0;
  }

  /// `true` se deve mostrar o ícone ✓ (completo).
  bool get _showCompletedIcon => isCompleted;

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 8,
      focusPadding: EdgeInsets.zero,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: isTV ? 120 : 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                _buildThumbnail(),
                _buildInfo(context),
                _buildPlayButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return SizedBox(
      width: isTV ? 160 : 140,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail ou placeholder
          if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: thumbnailUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.movie_outlined,
                    color: Colors.white24,
                    size: 32,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white24,
                    size: 32,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
              ),
              child: Center(
                child: Text(
                  'E${episode.number}',
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Gradiente overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    AppColors.surface.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),

          // Número do episódio (badge)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'E${episode.number.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Ícone de play centralizado
          const Positioned.fill(
            child: Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    // **Por que fallback inline:** `AppLocalizations.of(context)` lança
    // em testes widget que não configuram `localizationsDelegates`.
    // Aqui a classe AppLocalizations não tem `maybeOf` (helper
    // manual), então usamos um try/catch como fallback defensivo.
    // Em produção (app rodando) o `of` sempre retorna não-null —
    // o fallback é o caminho de teste, não o caminho comum.
    final runtimeLabel =
        () {
      try {
        return AppLocalizations.of(context).runtimeMinutesLabel;
      } catch (_) {
        return 'min';
      }
    }();
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Título do episódio
            Text(
              episode.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTV ? 16 : 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // **Fase N+7:** título original (idioma da produção) —
            // subtítulo discreto, só aparece se != title (evita
            // duplicação visual para NFOs PT-BR que têm o mesmo
            // texto em title e originalTitle).
            if (originalTitle != null &&
                originalTitle!.isNotEmpty &&
                originalTitle != episode.title) ...[
              const SizedBox(height: 2),
              Text(
                originalTitle!,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: isTV ? 13 : 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 4),

            // Metadados
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Número completo SxxExx
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'S${seasonNumber.toString().padLeft(2, '0')}'
                    'E${episode.number.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // **Fase N+7 — rating扩e:** ícone estrela + nota.
                if (rating != null) ...[
                  const Icon(
                    Icons.star,
                    color: Color(0xFFFBBF24),
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                // **Fase N+7 — runtime扩e:** ícone relógio + minutos.
                if (runtime != null) ...[
                  const Icon(
                    Icons.schedule_outlined,
                    color: Colors.white60,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$runtime $runtimeLabel',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],

                // **Fase N+7 — aired扩e:** ícone calendário + data.
                if (aired != null) ...[
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white60,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatAiredDate(aired!, context),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],

                // Tamanho do arquivo (se disponível) — legado V1.
                if (episode.fileSize != null) ...[
                  const Icon(
                    Icons.storage_outlined,
                    color: Colors.white38,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${episode.fileSize}MB',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),

            // **Fase N+7 — outline扩e:** resumo curto 1-2 frases.
            // Quando presente, exibe ANTES do plot (que pode
            // existir como `description` no record mas não é
            // exibido no card V1).
            if (outline != null && outline!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                outline!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Fase 3: barra de progresso (em andamento) OU ícone ✓
            // (completo). Renderizado por último (rodapé do card).
            if (_showProgressBar || _showCompletedIcon) ...[
              const SizedBox(height: 6),
              if (_showProgressBar)
                _ProgressBar(
                  ratio: _progressRatio,
                  isTV: isTV,
                )
              else
                _CompletedIndicator(isTV: isTV),
            ],
          ],
        ),
      ),
    );
  }

  /// Formata a data `aired` para exibição compacta no card.
  /// PT-BR: "5 dez 2021". EN: "5 Dec 2021".
  ///
  /// **Por que recebe `context`:** precisa do `Localizations` para
  /// detectar PT vs EN. `BuildContext` é passado explicitamente
  /// porque o widget é `StatelessWidget` (sem `context` direto nos
  /// métodos privados — a alternativa seria `Localizations.maybeOf`
  /// que silenciosamente falha se não tiver ancestor).
  ///
  /// **Por que helper inline:** evita chamar `intl` (pacote pesado)
  /// só pra formatar 1 data. Implementação inline cobre os 12 meses
  /// PT-BR e EN. `intl` pode ser introduzido depois se mais línguas
  /// forem necessárias.
  String _formatAiredDate(DateTime date, BuildContext context) {
    const ptMonths = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    const enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final isPt = Localizations.localeOf(context).languageCode == 'pt';
    final monthAbbr = isPt ? ptMonths : enMonths;
    return '${date.day} ${monthAbbr[date.month - 1]} ${date.year}';
  }

  Widget _buildPlayButton() {
    // Se completo, mostra ✓ verde no lugar do play vermelho.
    if (_showCompletedIcon) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Container(
          width: isTV ? 48 : 40,
          height: isTV ? 48 : 40,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.check_circle,
            color: Colors.white,
            size: isTV ? 28 : 24,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: isTV ? 48 : 40,
        height: isTV ? 48 : 40,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: isTV ? 28 : 24,
        ),
      ),
    );
  }
}

/// Barra de progresso horizontal usada pelo `PauloflixEpisodeCard` quando
/// o episódio está em andamento.
///
/// Renderiza um `LinearProgressIndicator` (Material) com a cor primária
/// do app. Width 100% do parent.
class _ProgressBar extends StatelessWidget {
  final double ratio;
  final bool isTV;

  const _ProgressBar({required this.ratio, required this.isTV});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 4,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}

/// Indicador "✓ Completo" usado pelo `PauloflixEpisodeCard` quando
/// `isCompleted = true`. Exibe um pequeno texto ao lado do ícone.
class _CompletedIndicator extends StatelessWidget {
  final bool isTV;
  const _CompletedIndicator({required this.isTV});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 12),
        const SizedBox(width: 4),
        Text(
          'Completo',
          style: TextStyle(
            color: Colors.green,
            fontSize: isTV ? 12 : 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
