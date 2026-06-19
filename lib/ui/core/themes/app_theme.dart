import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'netflix_theme.dart';
import 'tv_theme.dart';

/// Unified App Theme for PauloFlix
/// Combines Netflix-inspired design with existing TV theme and PauloFlix colors
class AppTheme {
  AppTheme._();

  /// Unified dark theme - Netflix style with PauloFlix colors
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    final netflixBase = NetflixTheme.darkTheme;
    final tvBase = TVTheme.darkTheme;

    return netflixBase.copyWith(
      // Use PauloFlix brand colors instead of Netflix red
      primaryColor: AppColors.primary,
      colorScheme: netflixBase.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      // Keep TV-specific customizations
      appBarTheme: tvBase.appBarTheme,
      cardTheme: netflixBase.cardTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: NetflixTheme.lg,
            vertical: NetflixTheme.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NetflixTheme.radiusSm),
          ),
        ),
      ),
      // Keep text theme but ensure colors match
      textTheme: netflixBase.textTheme.copyWith(
        displayLarge: netflixBase.textTheme.displayLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        displayMedium: netflixBase.textTheme.displayMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        displaySmall: netflixBase.textTheme.displaySmall?.copyWith(
          color: AppColors.textPrimary,
        ),
        headlineMedium: netflixBase.textTheme.headlineMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        titleLarge: netflixBase.textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        titleMedium: netflixBase.textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        bodyLarge: netflixBase.textTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        bodyMedium: netflixBase.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  /// Unified light theme - Netflix style with PauloFlix colors
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final netflixBase = NetflixTheme.lightTheme;
    final tvBase = TVTheme.lightTheme;

    return netflixBase.copyWith(
      // Use PauloFlix brand colors
      primaryColor: AppColors.primary,
      colorScheme: netflixBase.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
      ),
      // Keep TV-specific customizations
      appBarTheme: tvBase.appBarTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: NetflixTheme.lg,
            vertical: NetflixTheme.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NetflixTheme.radiusSm),
          ),
        ),
      ),
      cardTheme: netflixBase.cardTheme,
      textTheme: netflixBase.textTheme.copyWith(
        displayLarge: netflixBase.textTheme.displayLarge?.copyWith(
          color: Colors.black87,
        ),
        displayMedium: netflixBase.textTheme.displayMedium?.copyWith(
          color: Colors.black87,
        ),
        displaySmall: netflixBase.textTheme.displaySmall?.copyWith(
          color: Colors.black87,
        ),
        headlineMedium: netflixBase.textTheme.headlineMedium?.copyWith(
          color: Colors.black87,
        ),
        titleLarge: netflixBase.textTheme.titleLarge?.copyWith(
          color: Colors.black87,
        ),
        titleMedium: netflixBase.textTheme.titleMedium?.copyWith(
          color: Colors.black87,
        ),
        bodyLarge: netflixBase.textTheme.bodyLarge?.copyWith(
          color: Colors.black87,
        ),
        bodyMedium: netflixBase.textTheme.bodyMedium?.copyWith(
          color: Colors.black54,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  /// Helper to get appropriate theme based on brightness
  static ThemeData getTheme({required bool isDark}) {
    return isDark ? darkTheme : lightTheme;
  }
}
