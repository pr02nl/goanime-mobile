import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/themes/app_colors.dart';
import '../core/widgets/content_type_selector.dart';

class MainNavigationScreen extends StatelessWidget {
  final Widget child;

  const MainNavigationScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return PopScope(
      canPop: location == '/',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context, location),
        body: child,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String location) {
    final isAnimeSection = !location.contains('pauloflix-movies');

    return AppBar(
      backgroundColor: AppColors.background.withValues(alpha: 0.97),
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      title: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.play_circle_filled, color: Colors.white),
      ),
      centerTitle: false,
      actions: [
        ContentTypeSelector(
          selected: isAnimeSection ? ContentType.anime : ContentType.movie,
          onChanged: (type) {
            context.go(type == ContentType.movie ? '/pauloflix-movies' : '/');
          },
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
          tooltip: 'Search',
          onPressed: () => context.push(
            isAnimeSection ? '/search' : '/pauloflix-movies/search',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.bookmark, color: Colors.white, size: 24),
          tooltip: 'Bookmarks',
          onPressed: () => context.push('/watchlist'),
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
            size: 24,
          ),
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
