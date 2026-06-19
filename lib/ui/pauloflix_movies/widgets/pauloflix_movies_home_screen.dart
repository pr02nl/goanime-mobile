import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/pauloflix_movie.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tv_detector.dart';
import '../../core/widgets/netflix_card.dart';
import '../../core/widgets/pauloflix_movies_badge.dart';
import '../view_models/pauloflix_movies_provider.dart';
import 'pauloflix_movie_detail_screen.dart';

class PauloFlixMoviesHomeScreen extends StatefulWidget {
  const PauloFlixMoviesHomeScreen({super.key});

  @override
  State<PauloFlixMoviesHomeScreen> createState() =>
      _PauloFlixMoviesHomeScreenState();
}

class _PauloFlixMoviesHomeScreenState extends State<PauloFlixMoviesHomeScreen> {
  bool _checkedInitialSync = false;
  bool _isTV = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<PauloFlixMoviesProvider>();
      await provider.loadContents();
      if (!mounted) return;
      // Primeira abertura: TMDB não configurado OU banco vazio → sincronizar.
      if (!_checkedInitialSync) {
        _checkedInitialSync = true;
        final isConfigured = await provider.isTmdbConfigured();
        if (!isConfigured) {
          if (mounted) {
            _showTmdbMissingBanner();
          }
          return;
        }
        if (provider.contents.isEmpty) {
          provider.syncContent();
        }
      }
      final screenWidth =
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .physicalSize
              .width /
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio;
      final isTvBuild = await TVDetector.isTV;
      if (mounted) {
        setState(
          () => _isTV = isTvBuild || screenWidth >= Responsive.tabletMaxWidth,
        );
      }
    });
  }

  void _showTmdbMissingBanner() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.15),
        content: Text(
          l10n.tmdbNotConfigured,
          style: const TextStyle(color: Colors.white),
        ),
        leading: const Icon(Icons.key_off, color: Color(0xFFDC2626)),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }

  void _syncContent() {
    context.read<PauloFlixMoviesProvider>().syncContent();
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Responsive.phoneMaxWidth) return 2;
    if (width < Responsive.tabletMaxWidth) return 4;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<PauloFlixMoviesProvider>();
    final contents = provider.contents;
    final crossAxisCount = _getCrossAxisCount(context);
    final isSyncing = provider.isSyncing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: AppColors.background,
            actions: [
              if (isSyncing)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: l10n.sync,
                  onPressed: _syncContent,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 16,
                bottom: 14,
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PauloFlixMoviesBadge(
                    fontSize: 13,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.movies,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Banner de progresso de sync
          if (isSyncing && provider.syncProgress.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.syncProgress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Contador
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.movieCount(contents.length),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          if (contents.isEmpty && !isSyncing)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.movie_outlined,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noMoviesAvailable,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verifique se o TMDB está configurado nas Configurações',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _syncContent,
                      icon: const Icon(Icons.sync),
                      label: Text(l10n.syncMovies),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (contents.isEmpty && isSyncing)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final content = contents[index];
                  return _buildCard(context, content);
                }, childCount: contents.length),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, PauloFlixMovie content) {
    return NetflixCard(
      imageUrl: content.imageUrl ?? '',
      title: content.displayName,
      rating: content.score,
      width: double.infinity,
      height: double.infinity,
      isTV: _isTV,
      showTitle: true,
      showRating: content.score != null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PauloFlixMovieDetailScreen(content: content),
          ),
        );
      },
      overlayWidget: content.isCollection
          ? const CollectionBadge()
          : const PauloFlixMoviesBadge(),
    );
  }
}
