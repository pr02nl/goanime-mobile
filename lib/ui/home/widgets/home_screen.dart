import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../pauloflix/view_models/pauloflix_provider.dart';
import '../../pauloflix/widgets/pauloflix_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () =>
            context.read<PauloFlixProvider>().syncContent(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: const CustomScrollView(
          slivers: [
            _PauloFlixHomeSection(),
            SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }
}

/// Seção PauloFlix na home.
class _PauloFlixHomeSection extends StatelessWidget {
  const _PauloFlixHomeSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<PauloFlixProvider>(
      builder: (context, pauloflix, _) {
        if (pauloflix.contents.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(                  child: Text(
                    l10n.noAnimeFound,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
              ),
            ),
          );
        }
        return SliverToBoxAdapter(
          child: PauloFlixSection(
            title: l10n.pauloFlix,
            contents: pauloflix.contents.take(15).toList(),
            isTV: false,
            onSeeAll: () => context.pushNamed('pauloflix-see-all'),
            onItemTap: (content) =>
                context.pushNamed('pauloflix-episodes', extra: content),
          ),
        );
      },
    );
  }
}
