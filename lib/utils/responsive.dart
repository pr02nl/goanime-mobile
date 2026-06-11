import 'package:flutter/material.dart';

import 'tv_detector.dart';

/// Tipos de dispositivo baseados no tamanho da tela
enum DeviceType { phone, tablet, tv, quest }

/// Classe utilitária para layouts responsivos
/// Suporta: Phone, Tablet, TV (Android TV), Meta Quest (VR)
class Responsive {
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth = 1200;
  static const double tvMaxWidth = 1920;

  /// Detecta o tipo de dispositivo considerando TV
  static DeviceType getDeviceType(BuildContext context) {
    // Verifica se é TV primeiro
    if (TVDetector.isTV) {
      return DeviceType.tv;
    }

    final width = MediaQuery.of(context).size.width;
    if (width < phoneMaxWidth) return DeviceType.phone;
    if (width < tabletMaxWidth) return DeviceType.tablet;
    if (width < tvMaxWidth) return DeviceType.tv;
    return DeviceType.quest;
  }

  /// Retorna true se for phone
  static bool isPhone(BuildContext context) =>
      getDeviceType(context) == DeviceType.phone;

  /// Retorna true se for tablet
  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceType.tablet;

  /// Retorna true se for TV
  static bool isTV(BuildContext context) =>
      getDeviceType(context) == DeviceType.tv;

  /// Retorna true se for Quest ou tela grande
  static bool isQuest(BuildContext context) =>
      getDeviceType(context) == DeviceType.quest;

  /// Retorna true se for tablet, TV ou maior
  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.of(context).size.width >= phoneMaxWidth;

  /// Retorna true se for TV ou maior
  static bool isTVOrLarger(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMaxWidth || TVDetector.isTV;

  /// Número de colunas para grids baseado no dispositivo
  static int getGridColumns(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 2;
      case DeviceType.tablet:
        return 4;
      case DeviceType.tv:
        return 6;
      case DeviceType.quest:
        return 6;
    }
  }

  /// Número de colunas para grids de categorias na TV
  static int getTVGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1920) return 8; // 4K
    if (width >= 1440) return 7; // 1440p
    if (width >= 1200) return 6; // 1080p
    return 5; // 720p
  }

  /// Número de itens visíveis em listas horizontais
  static double getHorizontalListItemWidth(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 140;
      case DeviceType.tablet:
        return 160;
      case DeviceType.tv:
        return 200;
      case DeviceType.quest:
        return 180;
    }
  }

  /// Altura do card baseada no dispositivo
  static double getCardHeight(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 200;
      case DeviceType.tablet:
        return 240;
      case DeviceType.tv:
        return 300;
      case DeviceType.quest:
        return 280;
    }
  }

  /// Altura da seção (lista horizontal)
  static double getSectionHeight(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 260;
      case DeviceType.tablet:
        return 300;
      case DeviceType.tv:
        return 380;
      case DeviceType.quest:
        return 340;
    }
  }

  /// Altura do banner hero
  static double getBannerHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return (width * 0.6).clamp(200.0, 280.0);
      case DeviceType.tablet:
        return (width * 0.4).clamp(280.0, 400.0);
      case DeviceType.tv:
        return (width * 0.35).clamp(350.0, 600.0);
      case DeviceType.quest:
        return (width * 0.35).clamp(350.0, 500.0);
    }
  }

  /// Padding horizontal baseado no dispositivo
  static double getHorizontalPadding(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 16;
      case DeviceType.tablet:
        return 32;
      case DeviceType.tv:
        return 48;
      case DeviceType.quest:
        return 48;
    }
  }

  /// Tamanho da fonte para títulos de seção
  static double getSectionTitleSize(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 18;
      case DeviceType.tablet:
        return 22;
      case DeviceType.tv:
        return 28;
      case DeviceType.quest:
        return 26;
    }
  }

  /// Espaçamento entre cards
  static double getCardSpacing(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 12;
      case DeviceType.tablet:
        return 16;
      case DeviceType.tv:
        return 24;
      case DeviceType.quest:
        return 20;
    }
  }

  /// Valor responsivo genérico
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? tv,
    T? quest,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return phone;
      case DeviceType.tablet:
        return tablet ?? phone;
      case DeviceType.tv:
        return tv ?? tablet ?? phone;
      case DeviceType.quest:
        return quest ?? tv ?? tablet ?? phone;
    }
  }

  /// Retorna o tamanho de fonte escalado para TV
  static double getScaledFontSize(BuildContext context, double baseSize) {
    if (isTV(context)) {
      return baseSize * 1.3;
    }
    return baseSize;
  }

  /// Retorna o tamanho do touch target adequado (min 48dp para acessibilidade)
  static double getTouchTargetSize(BuildContext context) {
    if (isTV(context)) {
      return 64.0; // Maior para facilitar navegação com controle remoto
    }
    return 48.0;
  }
}

/// Widget que reconstrói baseado no tamanho da tela
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, Responsive.getDeviceType(context));
      },
    );
  }
}

/// Widget que mostra diferentes layouts baseado no dispositivo
class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? tv;
  final Widget? quest;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.tv,
    this.quest,
  });

  @override
  Widget build(BuildContext context) {
    switch (Responsive.getDeviceType(context)) {
      case DeviceType.phone:
        return phone;
      case DeviceType.tablet:
        return tablet ?? phone;
      case DeviceType.tv:
        return tv ?? tablet ?? phone;
      case DeviceType.quest:
        return quest ?? tv ?? tablet ?? phone;
    }
  }
}

/// Widget que aplica padding responsivo baseado no dispositivo
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? phonePadding;
  final EdgeInsets? tabletPadding;
  final EdgeInsets? tvPadding;
  final EdgeInsets? questPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.phonePadding,
    this.tabletPadding,
    this.tvPadding,
    this.questPadding,
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsets padding;
    switch (Responsive.getDeviceType(context)) {
      case DeviceType.phone:
        padding = phonePadding ?? const EdgeInsets.all(16);
      case DeviceType.tablet:
        padding = tabletPadding ?? phonePadding ?? const EdgeInsets.all(32);
      case DeviceType.tv:
        padding =
            tvPadding ??
            tabletPadding ??
            phonePadding ??
            const EdgeInsets.all(48);
      case DeviceType.quest:
        padding =
            questPadding ??
            tvPadding ??
            tabletPadding ??
            phonePadding ??
            const EdgeInsets.all(48);
    }

    return Padding(padding: padding, child: child);
  }
}
