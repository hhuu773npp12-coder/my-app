// lib/utils/responsive_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// مساعد التصميم المتجاوب لجميع أحجام الشاشات
class ResponsiveHelper {
  
  /// أنواع الأجهزة
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 600) {
      return DeviceType.mobile;
    } else if (width < 1200) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  /// التحقق من نوع الجهاز
  static bool isMobile(BuildContext context) => getDeviceType(context) == DeviceType.mobile;
  static bool isTablet(BuildContext context) => getDeviceType(context) == DeviceType.tablet;
  static bool isDesktop(BuildContext context) => getDeviceType(context) == DeviceType.desktop;
  
  /// الحصول على عدد الأعمدة حسب حجم الشاشة
  static int getGridColumns(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return 2;
      case DeviceType.tablet:
        return 3;
      case DeviceType.desktop:
        return 4;
    }
  }
  
  /// الحصول على حجم الخط المناسب
  static double getFontSize(BuildContext context, double baseSize) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return baseSize.sp;
      case DeviceType.tablet:
        return (baseSize * 1.1).sp;
      case DeviceType.desktop:
        return (baseSize * 1.2).sp;
    }
  }
  
  /// الحصول على المسافات المناسبة
  static double getSpacing(BuildContext context, double baseSpacing) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return baseSpacing.w;
      case DeviceType.tablet:
        return (baseSpacing * 1.2).w;
      case DeviceType.desktop:
        return (baseSpacing * 1.5).w;
    }
  }
  
  /// الحصول على ارتفاع الأزرار المناسب
  static double getButtonHeight(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return 48.h;
      case DeviceType.tablet:
        return 56.h;
      case DeviceType.desktop:
        return 64.h;
    }
  }
  
  /// الحصول على حجم الأيقونات المناسب
  static double getIconSize(BuildContext context, double baseSize) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return baseSize.r;
      case DeviceType.tablet:
        return (baseSize * 1.2).r;
      case DeviceType.desktop:
        return (baseSize * 1.4).r;
    }
  }
  
  /// الحصول على عرض الحاوية المناسب
  static double getContainerWidth(BuildContext context, double percentage) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth * percentage;
  }
  
  /// الحصول على ارتفاع الحاوية المناسب
  static double getContainerHeight(BuildContext context, double percentage) {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight * percentage;
  }
  
  /// التحقق من الاتجاه (عمودي أم أفقي)
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }
  
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
  
  /// الحصول على معلومات الشاشة
  static ScreenInfo getScreenInfo(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return ScreenInfo(
      width: mediaQuery.size.width,
      height: mediaQuery.size.height,
      devicePixelRatio: mediaQuery.devicePixelRatio,
      orientation: mediaQuery.orientation,
      deviceType: getDeviceType(context),
    );
  }
  
  /// تخطيط متجاوب للقوائم
  static Widget responsiveGrid({
    required BuildContext context,
    required List<Widget> children,
    double? childAspectRatio,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
  }) {
    final columns = getGridColumns(context);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: childAspectRatio ?? 1.0,
        mainAxisSpacing: mainAxisSpacing ?? getSpacing(context, 16),
        crossAxisSpacing: crossAxisSpacing ?? getSpacing(context, 16),
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
  
  /// تخطيط متجاوب للصفوف والأعمدة
  static Widget responsiveLayout({
    required BuildContext context,
    required Widget mobileLayout,
    Widget? tabletLayout,
    Widget? desktopLayout,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return mobileLayout;
      case DeviceType.tablet:
        return tabletLayout ?? mobileLayout;
      case DeviceType.desktop:
        return desktopLayout ?? tabletLayout ?? mobileLayout;
    }
  }
  
  /// حاوية متجاوبة
  static Widget responsiveContainer({
    required BuildContext context,
    required Widget child,
    double? widthPercentage,
    double? heightPercentage,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Decoration? decoration,
  }) {
    return Container(
      width: widthPercentage != null ? getContainerWidth(context, widthPercentage) : null,
      height: heightPercentage != null ? getContainerHeight(context, heightPercentage) : null,
      padding: padding ?? EdgeInsets.all(getSpacing(context, 16)),
      margin: margin ?? EdgeInsets.all(getSpacing(context, 8)),
      decoration: decoration,
      child: child,
    );
  }
  
  /// نص متجاوب
  static Widget responsiveText(
    String text, {
    required BuildContext context,
    double baseFontSize = 16,
    FontWeight? fontWeight,
    Color? color,
    TextAlign? textAlign,
    int? maxLines,
  }) {
    return Text(
      text,
      style: TextStyle(
        fontSize: getFontSize(context, baseFontSize),
        fontWeight: fontWeight,
        color: color,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
  
  /// زر متجاوب
  static Widget responsiveButton({
    required BuildContext context,
    required String text,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? textColor,
    double baseFontSize = 16,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: getButtonHeight(context),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(getSpacing(context, 12)),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: getIconSize(context, 20),
                height: getIconSize(context, 20),
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: getFontSize(context, baseFontSize),
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// أنواع الأجهزة
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// معلومات الشاشة
class ScreenInfo {
  final double width;
  final double height;
  final double devicePixelRatio;
  final Orientation orientation;
  final DeviceType deviceType;
  
  const ScreenInfo({
    required this.width,
    required this.height,
    required this.devicePixelRatio,
    required this.orientation,
    required this.deviceType,
  });
  
  @override
  String toString() {
    return 'ScreenInfo(width: $width, height: $height, ratio: $devicePixelRatio, orientation: $orientation, type: $deviceType)';
  }
}
