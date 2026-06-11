import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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

  void _navigateToHome() {
    setState(() => _currentIndex = 0);
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
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom > 0 ? 8 : 12,
            ),
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(20),
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

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade600,
                    fontSize: isSelected ? 10 : 9,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
