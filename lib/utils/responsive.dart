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
  static Future<DeviceType> getDeviceType(BuildContext context) async {
    // Capture width before any async gap to avoid BuildContext-across-async-gap lint.
    final width = MediaQuery.of(context).size.width;

    // Verifica se e TV primeiro
    if (await TVDetector.isTV) {
      return DeviceType.tv;
    }

    if (width < phoneMaxWidth) return DeviceType.phone;
    if (width < tabletMaxWidth) return DeviceType.tablet;
    if (width < tvMaxWidth) return DeviceType.tv;
    return DeviceType.quest;
  }

  /// Retorna true se for phone
  static Future<bool> isPhone(BuildContext context) async =>
      (await getDeviceType(context)) == DeviceType.phone;

  /// Retorna true se for tablet
  static Future<bool> isTablet(BuildContext context) async =>
      (await getDeviceType(context)) == DeviceType.tablet;

  /// Retorna true se for TV
  static Future<bool> isTV(BuildContext context) async =>
      (await getDeviceType(context)) == DeviceType.tv;

  /// Retorna true se for Quest ou tela grande
  static Future<bool> isQuest(BuildContext context) async =>
      (await getDeviceType(context)) == DeviceType.quest;

  /// Retorna true se for tablet, TV ou maior
  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.of(context).size.width >= phoneMaxWidth;

  /// Retorna true se for TV ou maior
  static Future<bool> isTVOrLarger(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMaxWidth || await TVDetector.isTV;
  }

  /// Numero de colunas para grids baseado no dispositivo
  static Future<int> getGridColumns(BuildContext context) async {
    switch (await getDeviceType(context)) {
      case DeviceType.phone:
        return 2;
      case DeviceType.tablet:
        return 4;
      case DeviceType.tv:
        return 6;
      case DeviceType.quest:
        return 8;
    }
  }

  /// Tamanho do card baseado no dispositivo
  static Future<double> getCardWidth(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    final columns = await getGridColumns(context);
    final padding = columns * 8.0; // espacamento entre cards
    return (width - padding) / columns;
  }

  /// Espacamento baseado no dispositivo
  static Future<double> getSpacing(BuildContext context) async {
    switch (await getDeviceType(context)) {
      case DeviceType.phone:
        return 8.0;
      case DeviceType.tablet:
        return 12.0;
      case DeviceType.tv:
        return 16.0;
      case DeviceType.quest:
        return 20.0;
    }
  }

  /// Padding baseado no dispositivo
  static Future<EdgeInsets> getPadding(BuildContext context) async {
    switch (await getDeviceType(context)) {
      case DeviceType.phone:
        return const EdgeInsets.all(8.0);
      case DeviceType.tablet:
        return const EdgeInsets.all(16.0);
      case DeviceType.tv:
        return const EdgeInsets.all(24.0);
      case DeviceType.quest:
        return const EdgeInsets.all(32.0);
    }
  }

  /// Tamanho da fonte baseado no dispositivo
  static Future<double> getFontSize(
    BuildContext context,
    double baseSize,
  ) async {
    switch (await getDeviceType(context)) {
      case DeviceType.phone:
        return baseSize;
      case DeviceType.tablet:
        return baseSize * 1.2;
      case DeviceType.tv:
        return baseSize * 1.5;
      case DeviceType.quest:
        return baseSize * 1.3;
    }
  }

  /// Altura do card baseado no dispositivo
  static Future<double> getCardHeight(BuildContext context) async {
    switch (await getDeviceType(context)) {
      case DeviceType.phone:
        return 200.0;
      case DeviceType.tablet:
        return 250.0;
      case DeviceType.tv:
        return 300.0;
      case DeviceType.quest:
        return 280.0;
    }
  }

  /// Retorna o widget apropriado baseado no dispositivo
  static Future<Widget> buildResponsive(
    BuildContext context, {
    required Widget phone,
    Widget? tablet,
    Widget? tv,
    Widget? quest,
  }) async {
    switch (await getDeviceType(context)) {
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

  /// Builder assincrono para layouts responsivos
  static Widget responsiveBuilder(
    BuildContext context,
    Future<Widget> Function(DeviceType) builder,
  ) {
    return FutureBuilder<DeviceType>(
      future: getDeviceType(context),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return FutureBuilder<Widget>(
            future: builder(snapshot.data!),
            builder: (context, widgetSnapshot) {
              if (widgetSnapshot.hasData) {
                return widgetSnapshot.data!;
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Synchronous helpers — based solely on MediaQuery width (no async TV check).
  // Safe to call directly inside build() / widget methods.
  // ---------------------------------------------------------------------------

  /// Synchronous device-type approximation using screen width only.
  static DeviceType _deviceTypeSyncByWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < phoneMaxWidth) return DeviceType.phone;
    if (width < tabletMaxWidth) return DeviceType.tablet;
    if (width < tvMaxWidth) return DeviceType.tv;
    return DeviceType.quest;
  }

  /// Returns a value depending on screen-width-based device type.
  /// [phone] is required; [tablet], [tv], [quest] fall back to [phone] if omitted.
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? tv,
    T? quest,
  }) {
    switch (_deviceTypeSyncByWidth(context)) {
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

  /// Horizontal padding for page-level content.
  static double getHorizontalPadding(BuildContext context) =>
      value<double>(context, phone: 12.0, tablet: 20.0, tv: 32.0, quest: 40.0);

  /// Card spacing in horizontal lists / grids.
  static double getCardSpacing(BuildContext context) =>
      value<double>(context, phone: 8.0, tablet: 12.0, tv: 16.0, quest: 18.0);

  /// Width for items in a horizontal scrolling anime list.
  static double getHorizontalListItemWidth(BuildContext context) =>
      value<double>(
        context,
        phone: 120.0,
        tablet: 150.0,
        tv: 190.0,
        quest: 200.0,
      );

  /// Height for the hero/banner carousel.
  static double getBannerHeight(BuildContext context) => value<double>(
    context,
    phone: 260.0,
    tablet: 340.0,
    tv: 450.0,
    quest: 400.0,
  );

  /// Height for a horizontal anime section (card + title).
  static double getSectionHeight(BuildContext context) => value<double>(
    context,
    phone: 230.0,
    tablet: 290.0,
    tv: 360.0,
    quest: 330.0,
  );

  /// Font size for section titles.
  static double getSectionTitleSize(BuildContext context) =>
      value<double>(context, phone: 16.0, tablet: 18.0, tv: 22.0, quest: 20.0);

  /// Synchronous grid column count based on screen width only.
  static int getGridColumnCount(BuildContext context) {
    switch (_deviceTypeSyncByWidth(context)) {
      case DeviceType.phone:
        return 2;
      case DeviceType.tablet:
        return 4;
      case DeviceType.tv:
        return 6;
      case DeviceType.quest:
        return 8;
    }
  }

  /// Synchronous card height based on screen width only.
  static double getCardHeightSync(BuildContext context) {
    switch (_deviceTypeSyncByWidth(context)) {
      case DeviceType.phone:
        return 200.0;
      case DeviceType.tablet:
        return 250.0;
      case DeviceType.tv:
        return 300.0;
      case DeviceType.quest:
        return 280.0;
    }
  }
}
