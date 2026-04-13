import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg       = Color(0xFF0A0A0A);
  static const surface  = Color(0xFF161616);
  static const surface2 = Color(0xFF1E1E1E);
  static const surface3 = Color(0xFF252525);
  static const red      = Color(0xFFE53935);
  static const redDark  = Color(0xFFC62828);
  static const redDim   = Color(0x1FE53935);
  static const redMid   = Color(0x40E53935);
  static const white    = Colors.white;
  static const white70  = Color(0xB3FFFFFF);
  static const white40  = Color(0x66FFFFFF);
  static const white15  = Color(0x26FFFFFF);
  static const white08  = Color(0x14FFFFFF);
  static const green    = Color(0xFF4CAF50);
  static const orange   = Color(0xFFFF9800);
}

class AppTextStyles {
  static TextStyle heading(double size, {Color color = AppColors.white}) =>
      GoogleFonts.rajdhani(fontSize: size, fontWeight: FontWeight.w700, color: color);

  static TextStyle label({Color color = AppColors.white40}) =>
      GoogleFonts.rajdhani(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: color);

  static TextStyle body({double size = 14, Color color = AppColors.white}) =>
      GoogleFonts.dmSans(fontSize: size, color: color);

  static TextStyle bodyMedium({double size = 14, Color color = AppColors.white}) =>
      GoogleFonts.dmSans(fontSize: size, fontWeight: FontWeight.w600, color: color);
}

class AppDecorations {
  static BoxDecoration card = BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18));
  static BoxDecoration cardSmall = BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.white08));
  static BoxDecoration alertBox = BoxDecoration(color: AppColors.redDim, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.redMid));
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    primaryColor: AppColors.red,
    colorScheme: const ColorScheme.dark(primary: AppColors.red, secondary: AppColors.red, surface: AppColors.surface),
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.rajdhani(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
      iconTheme: const IconThemeData(color: AppColors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: GoogleFonts.dmSans(color: AppColors.white40, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.white08)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.white08)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.red)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.white15),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.dmSans(fontSize: 14),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.red,
      unselectedItemColor: AppColors.white40,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: GoogleFonts.rajdhani(fontSize: 11, letterSpacing: 0.5),
      unselectedLabelStyle: GoogleFonts.rajdhani(fontSize: 11, letterSpacing: 0.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.red : AppColors.white15),
    ),
  );
}
