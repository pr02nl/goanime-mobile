import 'package:flutter/material.dart';

import '../theme/netflix_theme.dart';
import '../utils/responsive.dart';

/// Netflix-inspired horizontal carousel with smooth scrolling
/// Supports responsive sizing and TV navigation
class NetflixCarousel extends StatefulWidget {
  final String title;
  final List<Widget> items;
  final double? height;
  final bool showTitle;
  final bool isTV;
  final Widget? trailing;

  const NetflixCarousel({
    super.key,
    required this.title,
    required this.items,
    this.height,
    this.showTitle = true,
    this.isTV = false,
    this.trailing,
  });

  @override
  State<NetflixCarousel> createState() => _NetflixCarouselState();
}

class _NetflixCarouselState extends State<NetflixCarousel> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftGradient = false;
  bool _showRightGradient = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateGradientVisibility);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateGradientVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateGradientVisibility() {
    if (!mounted) return;

    setState(() {
      _showLeftGradient = _scrollController.offset > 0;
      _showRightGradient =
          _scrollController.offset <
          _scrollController.position.maxScrollExtent - 10;
    });
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - MediaQuery.of(context).size.width * 0.7,
      duration: NetflixTheme.mediumDuration,
      curve: NetflixTheme.defaultCurve,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + MediaQuery.of(context).size.width * 0.7,
      duration: NetflixTheme.mediumDuration,
      curve: NetflixTheme.defaultCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultHeight = widget.height ?? (widget.isTV ? 360.0 : 280.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title row
        if (widget.showTitle)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: NetflixTheme.horizontalPadding(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: NetflixTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        SizedBox(height: widget.showTitle ? NetflixTheme.sm : 0),
        // Carousel
        SizedBox(
          height: defaultHeight,
          child: Stack(
            children: [
              // Left gradient fade
              if (_showLeftGradient)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [NetflixTheme.background, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              // Right gradient fade
              if (_showRightGradient)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.transparent, NetflixTheme.background],
                      ),
                    ),
                  ),
                ),
              // Scrollable content
              ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: NetflixTheme.horizontalPadding(context),
                ),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: NetflixTheme.cardSpacing(context),
                    ),
                    child: widget.items[index],
                  );
                },
              ),
              // Navigation buttons (desktop/TV only)
              if (!widget.isTV && MediaQuery.of(context).size.width > 600) ...[
                // Left button
                if (_showLeftGradient)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: NetflixTheme.background.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left),
                          color: NetflixTheme.textPrimary,
                          onPressed: _scrollLeft,
                        ),
                      ),
                    ),
                  ),
                // Right button
                if (_showRightGradient)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: NetflixTheme.background.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right),
                          color: NetflixTheme.textPrimary,
                          onPressed: _scrollRight,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Shimmer loading placeholder for carousel
class NetflixCarouselShimmer extends StatelessWidget {
  final String title;
  final int itemCount;
  final double? height;
  final bool showTitle;

  const NetflixCarouselShimmer({
    super.key,
    required this.title,
    this.itemCount = 6,
    this.height,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final defaultHeight = height ?? 280.0;
    final cardWidth = Responsive.getHorizontalListItemWidth(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title shimmer
        if (showTitle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NetflixTheme.md),
            child: Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(
                color: NetflixTheme.surfaceLight,
                borderRadius: BorderRadius.circular(NetflixTheme.radiusSm),
              ),
            ),
          ),
        SizedBox(height: showTitle ? NetflixTheme.sm : 0),
        // Cards shimmer
        SizedBox(
          height: defaultHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: NetflixTheme.md),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: NetflixTheme.sm),
                child: Container(
                  width: cardWidth,
                  height: defaultHeight - NetflixTheme.sm,
                  decoration: BoxDecoration(
                    color: NetflixTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(NetflixTheme.radiusMd),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
