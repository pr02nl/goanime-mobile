import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/jikan_models.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import 'anime_card.dart';
import 'focusable_widget.dart';
import 'netflix_carousel.dart';

class AnimeSection extends StatelessWidget {
  final String title;
  final List<JikanAnime> animes;
  final bool isLoading;
  final VoidCallback? onSeeAll;
  final Function(JikanAnime)? onAnimeTap;
  final bool showLargeCards;
  final bool useNetflixStyle; // NOVO: Flag para ativar estilo Netflix

  const AnimeSection({
    super.key,
    required this.title,
    required this.animes,
    this.isLoading = false,
    this.onSeeAll,
    this.onAnimeTap,
    this.showLargeCards = false,
    this.useNetflixStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    // Se estilo Netflix ativado, usar NetflixCarousel
    if (useNetflixStyle) {
      return NetflixCarousel(
        title: title,
        items: animes.map((anime) {
          return AnimeCard(
            anime: anime,
            width: Responsive.getHorizontalListItemWidth(context),
            height: Responsive.getCardHeightSync(context),
            useNetflixStyle: true,
            onTap: onAnimeTap != null ? () => onAnimeTap!(anime) : null,
          );
        }).toList(),
        height: Responsive.getSectionHeight(context),
        trailing: onSeeAll != null
            ? TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Text('Ver Todos'),
              )
            : null,
      );
    }

    // Manter implementação original se estilo Netflix desativado
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da seção
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text(
                    'Ver Todos',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Lista de animes
        if (isLoading)
          _buildLoadingState()
        else if (animes.isEmpty)
          _buildEmptyState()
        else if (showLargeCards)
          _buildLargeCardsList()
        else
          _buildHorizontalList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHorizontalList() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: animes.length,
        itemBuilder: (context, index) {
          final anime = animes[index];
          return AnimeCard(
            anime: anime,
            onTap: onAnimeTap != null ? () => onAnimeTap!(anime) : null,
          );
        },
      ),
    );
  }

  Widget _buildLargeCardsList() {
    return Column(
      children: animes.map((anime) {
        return AnimeCardLarge(
          anime: anime,
          onTap: onAnimeTap != null ? () => onAnimeTap!(anime) : null,
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 240,
      child: Center(
        child: Text(
          'Nenhum anime encontrado',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ),
    );
  }
}

// Manter AnimeCardLarge original para compatibilidade
class AnimeCardLarge extends StatelessWidget {
  final JikanAnime anime;
  final VoidCallback? onTap;

  const AnimeCardLarge({super.key, required this.anime, this.onTap});

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onSelect: onTap,
      borderRadius: 12,
      focusPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Imagem
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: anime.largImageUrl ?? anime.imageUrl,
                  width: 100,
                  height: 140,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  memCacheWidth: 200,
                  memCacheHeight: 280,
                  maxWidthDiskCache: 200,
                  maxHeightDiskCache: 280,
                  placeholder: (context, url) => Container(
                    width: 100,
                    height: 140,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 100,
                    height: 140,
                    color: Colors.grey[800],
                    child: const Icon(Icons.error, color: Colors.white54),
                  ),
                ),
              ),
              // Informações
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (anime.synopsis != null)
                        Text(
                          anime.synopsis!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (anime.score != null) ...[
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              anime.score!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (anime.episodes != null) ...[
                            Icon(
                              Icons.play_circle_outline,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${anime.episodes} eps',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
