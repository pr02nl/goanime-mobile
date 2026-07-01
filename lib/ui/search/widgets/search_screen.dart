import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/widgets/tv_safe_text_field.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const SearchScreen({super.key, this.onBackPressed});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    context.pushNamed('anime-search');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.background, AppColors.backgroundLight],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: TVSafeTextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: _performSearch,
                              decoration: InputDecoration(
                                hintText: l10n.searchAnime,
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.primary,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Search options
              Expanded(
                child: ListView(
                  children: [
                    _buildSearchOption(
                      icon: Icons.search,
                      title: l10n.searchAnime,
                      subtitle: l10n.searchPrompt,
                      color: AppColors.primary,
                      onTap: () => context.pushNamed('anime-search'),
                    ),
                    const SizedBox(height: 16),
                    _buildSearchOption(
                      icon: Icons.live_tv,
                      title: l10n.pauloFlix,
                      subtitle: l10n.sectionAllAnimes,
                      color: const Color(0xFF00BCD4),
                      onTap: () => context.pushNamed('pauloflix-search'),
                    ),
                    const SizedBox(height: 16),
                    _buildSearchOption(
                      icon: Icons.movie,
                      title: l10n.movies,
                      subtitle: l10n.moviesAvailable,
                      color: const Color(0xFFE53935),
                      onTap: () =>
                          context.pushNamed('pauloflix-movies-search'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.1),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
