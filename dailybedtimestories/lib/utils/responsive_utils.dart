import 'package:flutter/material.dart';
import 'package:dailystory/providers/font_size_provider.dart';

class ResponsiveUtils {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 900;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  static double getCardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return width * 0.9;
    } else if (width < 900) {
      return width * 0.7;
    } else {
      return width * 0.5;
    }
  }

  static double getCardHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < 600) {
      return height * 0.4;
    } else if (height < 900) {
      return height * 0.3;
    } else {
      return height * 0.25;
    }
  }

  static EdgeInsets getPagePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.all(32.0);
    }
  }

  static double getFontSize(BuildContext context, FontSize size) {
    final width = MediaQuery.of(context).size.width;
    switch (size) {
      case FontSize.small:
        if (width < 360) return 14.0;
        if (width < 600) return 16.0;
        return 18.0;
      case FontSize.medium:
        if (width < 360) return 16.0;
        if (width < 600) return 18.0;
        return 20.0;
      case FontSize.large:
        if (width < 360) return 18.0;
        if (width < 600) return 20.0;
        return 22.0;
      default:
        return 16.0; // 默认返回中等大小
    }
  }

  static double getIconSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 20.0;
    if (width < 600) return 24.0;
    return 28.0;
  }

  static double getButtonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 40.0;
    if (width < 600) return 48.0;
    return 56.0;
  }

  static double getModalMaxHeight(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.7;
  }

  static double getSafeBottomPadding(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }

  static double getSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 8.0;
    if (width < 600) return 16.0;
    return 24.0;
  }
}
