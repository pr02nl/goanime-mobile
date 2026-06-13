import 'package:flutter/material.dart';

import '../models/pauloflix_content.dart';
import '../theme/app_colors.dart';
import 'pauloflix_card.dart';

class PauloFlixSection extends StatelessWidget {
  final String title;
  final List<PauloFlixContent> contents;
  final VoidCallback? onSeeAll;
  final Function(PauloFlixContent)? onItemTap;

  const PauloFlixSection({
    super.key,
    required this.title,
    required this.contents,
    this.onSeeAll,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.dns,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(
                    'Ver Todos',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: contents.length,
            itemBuilder: (context, index) {
              final content = contents[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: PauloFlixCard(
                  content: content,
                  onTap: () => onItemTap?.call(content),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
