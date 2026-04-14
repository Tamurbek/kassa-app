import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../utils/responsive.dart';

class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color secondary = Color(0xFF10B981);
  static const Color accent = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  
  // Aliases for backward compatibility
  static const Color primaryColor = primary;
  static const Color secondaryColor = secondary;
  static const Color slateGrey = Color(0xFF64748B);

  // Light Mode Colors
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF262626); 
  static const Color darkSurface = Color(0xFF333333); 
  static const Color darkBorder = Color(0xFF404040); 
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}

class AppShadows {
  static List<BoxShadow> subtle = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> premium = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppTheme {
  // Backward compatibility static constants
  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.secondary;
  static const Color accentColor = AppColors.accent;
  static const Color errorColor = AppColors.error;
  static const Color lightBg = AppColors.lightBg;
  static const Color darkBg = AppColors.darkBg;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color lightBorder = AppColors.lightBorder;
  static const Color darkBorder = AppColors.darkBorder;

  static ThemeData getTheme(BuildContext context, Brightness brightness) {
    Responsive.init(context);
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return base.copyWith(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      cardColor: surface,
      dividerColor: border,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: surface,
        onSurface: textPrimary,
        error: AppColors.error,
        outline: border,
        surfaceContainerHighest: isDark ? const Color(0xFF404040) : const Color(0xFFF1F5F9),
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: textPrimary, fontSize: 32.sp),
        headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: textPrimary, fontSize: 28.sp),
        headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 24.sp),
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20.sp, color: textPrimary),
        titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18.sp, color: textPrimary),
        titleSmall: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16.sp, color: textPrimary),
        bodyLarge: GoogleFonts.outfit(color: textPrimary, fontSize: 16.sp),
        bodyMedium: GoogleFonts.outfit(color: textPrimary, fontSize: 14.sp),
        bodySmall: GoogleFonts.outfit(color: textPrimary, fontSize: 12.sp),
        labelLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14.sp),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        toolbarHeight: 64.h,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.all(8.sp),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius.sp),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface.withOpacity(0.5) : Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 20.sp, vertical: 16.sp),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius.sp),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius.sp),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius.sp),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: GoogleFonts.outfit(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          fontSize: 14.sp,
        ),
        floatingLabelStyle: GoogleFonts.outfit(
          color: AppColors.primary, 
          fontWeight: FontWeight.bold,
          fontSize: 14.sp,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: Size(0, 52.h),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius.sp),
          ),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16.sp),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: border),
          minimumSize: Size(0, 52.h),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius.sp),
          ),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16.sp),
        ),
      ),
    );
  }
}
