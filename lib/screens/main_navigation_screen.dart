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
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 5; i++) {
      _focusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _navigateToHome() {
    setState(() => _currentIndex = 0);
  }

  void _onNavItemSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Lista de telas para o IndexedStack
    final List<Widget> screens = [
      const HomeScreen(),
      SearchScreen(onBackPressed: _navigateToHome),
      const WatchlistScreen(),
      const DownloadsScreen(),
      SettingsScreen(onBackPressed: _navigateToHome),
    ];

    final isTV = TVDetector.isTV;
    final bottomPadding = isTV
        ? 0.0
        : (MediaQuery.of(context).padding.bottom > 0 ? 8.0 : 12.0);
    final navHeight = isTV ? 80.0 : 64.0;
    final horizontalMargin = isTV ? 24.0 : 12.0;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: EdgeInsets.only(
              left: horizontalMargin,
              right: horizontalMargin,
              bottom: bottomPadding,
            ),
            height: navHeight,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(isTV ? 16 : 20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isTV ? 16 : 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Home',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.search_outlined,
                    activeIcon: Icons.search,
                    label: 'Search',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.bookmark_outline,
                    activeIcon: Icons.bookmark,
                    label: 'Watchlist',
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: Icons.download_outlined,
                    activeIcon: Icons.download,
                    label: 'Downloads',
                    index: 3,
                  ),
                  _buildNavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: 'Settings',
                    index: 4,
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
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final isTV = TVDetector.isTV;

    final iconSize = isTV ? 28.0 : 20.0;
    final fontSize = isSelected ? (isTV ? 14.0 : 10.0) : (isTV ? 12.0 : 9.0);
    final padding = isTV
        ? const EdgeInsets.symmetric(vertical: 12, horizontal: 8)
        : const EdgeInsets.symmetric(vertical: 6, horizontal: 2);

    Widget content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(isTV ? 10 : 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(isTV ? 14 : 10),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
              size: iconSize,
            ),
          ),
          SizedBox(height: isTV ? 6 : 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    // Se for TV, usa FocusableWidget para navegação com controle remoto
    if (isTV) {
      return Expanded(
        child: FocusableWidget(
          focusNode: _focusNodes[index],
          autoFocus: index == 0,
          onSelect: () => _onNavItemSelected(index),
          focusScale: 1.08,
          borderRadius: 16,
          child: content,
        ),
      );
    }

    // Mobile: usa InkWell normal
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNavItemSelected(index),
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      ),
    );
  }
}
