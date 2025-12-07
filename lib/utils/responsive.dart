import 'package:flutter/material.dart';

/// Tipos de dispositivo baseados no tamanho da tela
enum DeviceType { phone, tablet, quest }

/// Classe utilitária para layouts responsivos
/// Suporta: Phone, Tablet, Meta Quest (VR)
class Responsive {
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth = 1200;
  
  /// Detecta o tipo de dispositivo
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < phoneMaxWidth) return DeviceType.phone;
    if (width < tabletMaxWidth) return DeviceType.tablet;
    return DeviceType.quest; // Quest ou telas grandes
  }

  /// Retorna true se for phone
  static bool isPhone(BuildContext context) => 
      getDeviceType(context) == DeviceType.phone;

  /// Retorna true se for tablet
  static bool isTablet(BuildContext context) => 
      getDeviceType(context) == DeviceType.tablet;

  /// Retorna true se for Quest ou tela grande
  static bool isQuest(BuildContext context) => 
      getDeviceType(context) == DeviceType.quest;

  /// Retorna true se for tablet ou maior
  static bool isTabletOrLarger(BuildContext context) => 
      MediaQuery.of(context).size.width >= phoneMaxWidth;

  /// Número de colunas para grids baseado no dispositivo
  static int getGridColumns(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 2;
      case DeviceType.tablet:
        return 4;
      case DeviceType.quest:
        return 6;
    }
  }

  /// Número de itens visíveis em listas horizontais
  static double getHorizontalListItemWidth(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 140;
      case DeviceType.tablet:
        return 160;
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
      case DeviceType.quest:
        return 20;
    }
  }

  /// Valor responsivo genérico
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? quest,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return phone;
      case DeviceType.tablet:
        return tablet ?? phone;
      case DeviceType.quest:
        return quest ?? tablet ?? phone;
    }
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
  final Widget? quest;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.quest,
  });

  @override
  Widget build(BuildContext context) {
    switch (Responsive.getDeviceType(context)) {
      case DeviceType.phone:
        return phone;
      case DeviceType.tablet:
        return tablet ?? phone;
      case DeviceType.quest:
        return quest ?? tablet ?? phone;
    }
  }
}
