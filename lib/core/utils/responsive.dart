import 'package:flutter/material.dart';
import 'dart:math' as math;

class Responsive {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double _textScaleFactor;
  static late double _pixelRatio;
  
  // Design resolution (e.g., standard desktop/tablet hybrid)
  static const double _designWidth = 1440.0;
  static const double _designHeight = 900.0;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    _textScaleFactor = _mediaQueryData.textScaleFactor;
    _pixelRatio = _mediaQueryData.devicePixelRatio;
  }

  // Scale based on width
  static double w(double width) => (width / _designWidth) * screenWidth;

  // Scale based on height
  static double h(double height) => (height / _designHeight) * screenHeight;

  // Scale based on the smaller dimension (good for font sizes)
  static double sp(double fontSize) {
    double scaleW = screenWidth / _designWidth;
    double scaleH = screenHeight / _designHeight;
    double scale = math.min(scaleW, scaleH);
    
    // On 1024x768, scale would be min(1024/1440, 768/900) = min(0.71, 0.85) = 0.71
    // We might want to cap the minimum scale to avoid tiny fonts
    double finalScale = math.max(scale, 0.85); // Increased floor to 85% for better readability
    return fontSize * finalScale;
  }

  // Common padding/spacing scaling
  static double get padding => sp(16.0);
  static double get paddingLarge => sp(24.0);
  static double get borderRadius => sp(12.0);

  // Checks for different screen types
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1200;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1200;

  // Specific check for the target 1024x768 or 1024x640 compact displays
  static bool isCompact(BuildContext context) => MediaQuery.of(context).size.width < 1100;
  
  // Height specific check
  static bool isShort(BuildContext context) => MediaQuery.of(context).size.height < 700;
}

extension ResponsiveDouble on num {
  double get w => Responsive.w(this.toDouble());
  double get h => Responsive.h(this.toDouble());
  double get sp => Responsive.sp(this.toDouble());
}
