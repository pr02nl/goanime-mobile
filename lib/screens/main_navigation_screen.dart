import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/tv_detector.dart';
import '../widgets/focusable_widget.dart';
import 'downloads_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'watchlist_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isTV = false;

  late final List<Widget> _screens;

  // FocusNodes for each nav item so TV d-pad can move between them.
  final List<FocusNode> _navFocusNodes = List.generate(5, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const SearchScreen(),
      const WatchlistScreen(),
      const DownloadsScreen(),
      SettingsScreen(onBackPressed: _navigateToHome),
    ];
    _detectTVMode();
  }

  @override
  void dispose() {
    for (final node in _navFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _detectTVMode() async {
    final isTV = await TVDetector.isTV;
    if (mounted) {
      setState(() {
        _isTV = isTV;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToHome() {
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = _isTV
        ? 0.0
        : (MediaQuery.of(context).padding.bottom > 0 ? 8.0 : 12.0);
    final navHeight = _isTV ? 80.0 : 64.0;
    final horizontalMargin = _isTV ? 24.0 : 12.0;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: FocusTraversalGroup(
          child: IndexedStack(index: _currentIndex, children: _screens),
        ),
        bottomNavigationBar: SafeArea(
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Container(
              margin: EdgeInsets.only(
                left: horizontalMargin,
                right: horizontalMargin,
                bottom: bottomPadding,
              ),
              height: navHeight,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Início',
                    index: 0,
                    navHeight: navHeight,
                  ),
                  _buildNavItem(
                    icon: Icons.search_outlined,
                    selectedIcon: Icons.search,
                    label: 'Buscar',
                    index: 1,
                    navHeight: navHeight,
                  ),
                  _buildNavItem(
                    icon: Icons.bookmark_outline,
                    selectedIcon: Icons.bookmark,
                    label: 'Lista',
                    index: 2,
                    navHeight: navHeight,
                  ),
                  _buildNavItem(
                    icon: Icons.download_outlined,
                    selectedIcon: Icons.download,
                    label: 'Downloads',
                    index: 3,
                    navHeight: navHeight,
                  ),
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Config',
                    index: 4,
                    navHeight: navHeight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required double navHeight,
  }) {
    final isSelected = _currentIndex == index;

    return FocusTraversalOrder(
      order: NumericFocusOrder(index.toDouble()),
      child: FocusableWidget(
        onSelect: () => _onItemTapped(index),
        focusNode: _navFocusNodes[index],
        autoFocus: isSelected,
        focusPadding: EdgeInsets.zero,
        focusScale: 1.0,
        borderRadius: 12,
        child: SizedBox(
          width: _isTV ? 100 : 80,
          height: navHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.6),
                  size: _isTV ? 28 : 24,
                ),
                child: Icon(isSelected ? selectedIcon : icon),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: _isTV ? 12 : 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
