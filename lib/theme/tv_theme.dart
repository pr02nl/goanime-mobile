import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema otimizado para Android TV com textos maiores e melhor contraste
class TVTheme {
  TVTheme._();

  /// Tamanhos de fonte escalados para TV (30-40% maiores que mobile)
  static const double fontSizeSmall = 16.0;
  static const double fontSizeRegular = 20.0;
  static const double fontSizeMedium = 24.0;
  static const double fontSizeLarge = 28.0;
  static const double fontSizeXLarge = 32.0;
  static const double fontSizeTitle = 40.0;
  static const double fontSizeHeadline = 48.0;

  /// Espaçamentos otimizados para TV
  static const double spacingSmall = 12.0;
  static const double spacingRegular = 20.0;
  static const double spacingMedium = 28.0;
  static const double spacingLarge = 36.0;
  static const double spacingXLarge = 48.0;

  /// Tamanhos de componentes para TV
  static const double buttonHeight = 56.0;
  static const double buttonMinWidth = 160.0;
  static const double cardBorderRadius = 16.0;
  static const double iconSizeSmall = 28.0;
  static const double iconSizeRegular = 32.0;
  static const double iconSizeLarge = 40.0;

  /// Cores de foco para navegação com controle remoto
  static const Color focusColor = AppColors.primary;
  static const Color focusBorderColor = AppColors.primaryGlow;
  static const double focusBorderWidth = 4.0;
  static const double focusElevation = 8.0;

  /// Tema claro para TV (pode ser usado em TVs com fundo claro)
  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light);
  }

  /// Tema escuro para TV (recomendado para TVs - melhor para viewing distance)
  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseTheme = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return baseTheme.copyWith(
      scaffoldBackgroundColor: isDark ? AppColors.background : Colors.white,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: isDark ? AppColors.surface : Colors.white,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: isDark ? AppColors.textPrimary : Colors.black87,
        onError: Colors.white,
      ),
      // TextTheme escalado para TV
      textTheme: _buildTVTextTheme(baseTheme.textTheme, isDark),
      // Component themes
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      cardTheme: _buildCardTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(isDark),
      appBarTheme: _buildAppBarTheme(isDark),
      bottomNavigationBarTheme: _buildBottomNavTheme(isDark),
      dialogTheme: _buildDialogTheme(),
      snackBarTheme: _buildSnackBarTheme(isDark),
      chipTheme: _buildChipTheme(isDark),
      sliderTheme: _buildSliderTheme(),
      // Foco
      focusColor: focusColor.withValues(alpha: 0.3),
    );
  }

  static TextTheme _buildTVTextTheme(TextTheme base, bool isDark) {
    final color = isDark ? AppColors.textPrimary : Colors.black87;
    final secondaryColor = isDark ? AppColors.textSecondary : Colors.black54;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: fontSizeHeadline,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: -0.5,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: fontSizeTitle,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: -0.5,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: fontSizeXLarge,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: fontSizeTitle,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: fontSizeXLarge,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: fontSizeLarge,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: fontSizeLarge,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: fontSizeMedium,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: fontSizeRegular,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: fontSizeMedium,
        fontWeight: FontWeight.normal,
        color: color,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: fontSizeRegular,
        fontWeight: FontWeight.normal,
        color: color,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: fontSizeSmall,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: fontSizeRegular,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.5,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: fontSizeSmall,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style:
          ElevatedButton.styleFrom(
            minimumSize: const Size(buttonMinWidth, buttonHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: spacingMedium,
              vertical: spacingRegular,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardBorderRadius),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: fontSizeRegular,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return AppColors.primary;
              }
              return null;
            }),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return AppColors.primaryLight.withValues(alpha: 0.2);
              }
              return null;
            }),
          ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(buttonMinWidth, buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingMedium,
          vertical: spacingRegular,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
        ),
        side: const BorderSide(color: AppColors.primary, width: 2),
        textStyle: const TextStyle(
          fontSize: fontSizeRegular,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: spacingRegular,
          vertical: spacingSmall,
        ),
        textStyle: const TextStyle(
          fontSize: fontSizeRegular,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static CardThemeData _buildCardTheme() {
    return CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(spacingSmall),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(bool isDark) {
    final borderColor = isDark ? AppColors.textTertiary : Colors.black38;
    final focusedBorderColor = AppColors.primary;

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.surface : Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingRegular,
        vertical: spacingRegular,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        borderSide: BorderSide(color: focusedBorderColor, width: 3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: const TextStyle(fontSize: fontSizeRegular),
      hintStyle: TextStyle(
        fontSize: fontSizeRegular,
        color: isDark ? AppColors.textTertiary : Colors.black38,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme(bool isDark) {
    return AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: isDark ? AppColors.background : Colors.white,
      foregroundColor: isDark ? AppColors.textPrimary : Colors.black87,
      titleTextStyle: const TextStyle(
        fontSize: fontSizeLarge,
        fontWeight: FontWeight.w600,
      ),
      toolbarHeight: 64,
    );
  }

  static BottomNavigationBarThemeData _buildBottomNavTheme(bool isDark) {
    return BottomNavigationBarThemeData(
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: isDark ? AppColors.textSecondary : Colors.black54,
      selectedLabelStyle: const TextStyle(
        fontSize: fontSizeSmall,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: fontSizeSmall,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    );
  }

  static DialogThemeData _buildDialogTheme() {
    return DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
      ),
      elevation: 24,
      titleTextStyle: const TextStyle(
        fontSize: fontSizeLarge,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: const TextStyle(fontSize: fontSizeRegular),
    );
  }

  static SnackBarThemeData _buildSnackBarTheme(bool isDark) {
    return SnackBarThemeData(
      backgroundColor: isDark ? AppColors.surfaceLight : Colors.grey.shade800,
      contentTextStyle: const TextStyle(fontSize: fontSizeRegular),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
    );
  }

  static ChipThemeData _buildChipTheme(bool isDark) {
    return ChipThemeData(
      backgroundColor: isDark ? AppColors.surface : Colors.grey.shade200,
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontSize: fontSizeSmall),
      padding: const EdgeInsets.symmetric(
        horizontal: spacingRegular,
        vertical: spacingSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(spacingRegular),
      ),
    );
  }

  static SliderThemeData _buildSliderTheme() {
    return SliderThemeData(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.textTertiary,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withValues(alpha: 0.2),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
    );
  }
}

/// Extensões para facilitar o uso do tema TV
extension TVThemeContext on BuildContext {
  /// Retorna se está em modo TV
  bool get isTVMode => false; // Substituído pelo TVDetector real (utils/tv_detector.dart)

  /// Retorna o tema TV apropriado
  ThemeData get tvTheme => TVTheme.darkTheme;

  /// Retorna o tamanho de fonte adaptativo
  double get adaptiveFontSize {
    return isTVMode ? TVTheme.fontSizeRegular : 16.0;
  }

  /// Retorna o espaçamento adaptativo
  double get adaptiveSpacing {
    return isTVMode ? TVTheme.spacingRegular : 16.0;
  }
}
