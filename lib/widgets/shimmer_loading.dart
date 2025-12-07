import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Widget de loading com efeito shimmer
/// Substitui CircularProgressIndicator por uma animação mais elegante
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: const [
                AppColors.surface,
                AppColors.surfaceLight,
                AppColors.surface,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Card de loading com shimmer para listas de animes
class ShimmerAnimeCard extends StatelessWidget {
  final double width;
  final double height;

  const ShimmerAnimeCard({
    super.key,
    this.width = 140,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerLoading(
          width: width,
          height: height,
          borderRadius: BorderRadius.circular(16),
        ),
        const SizedBox(height: 8),
        ShimmerLoading(
          width: width * 0.8,
          height: 12,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 4),
        ShimmerLoading(
          width: width * 0.5,
          height: 10,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }
}

/// Lista horizontal de shimmer cards
class ShimmerAnimeList extends StatelessWidget {
  final double itemWidth;
  final double itemHeight;
  final int itemCount;
  final double spacing;
  final EdgeInsets padding;

  const ShimmerAnimeList({
    super.key,
    this.itemWidth = 140,
    this.itemHeight = 200,
    this.itemCount = 5,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemHeight + 40, // Extra space for title
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: spacing),
            child: ShimmerAnimeCard(
              width: itemWidth,
              height: itemHeight,
            ),
          );
        },
      ),
    );
  }
}

/// Grid de shimmer cards
class ShimmerAnimeGrid extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final int itemCount;
  final EdgeInsets padding;

  const ShimmerAnimeGrid({
    super.key,
    this.crossAxisCount = 3,
    this.childAspectRatio = 0.6,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ShimmerLoading(
                width: double.infinity,
                height: double.infinity,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 6),
            ShimmerLoading(
              width: double.infinity,
              height: 11,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        );
      },
    );
  }
}
