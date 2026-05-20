// theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR PALETTE
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  static const bg = Color(0xFF0A0A0A);
  static const surface = Color(0xFF161616);
  static const surface2 = Color(0xFF1E1E1E);
  static const surface3 = Color(0xFF252525);

  /// Primary emergency red
  static const red = Color(0xFFE53935);
  static const redDark = Color(0xFFC62828);
  static const redDim = Color(0x1FE53935);
  static const redMid = Color(0x40E53935);

  /// Muted gold — secondary accent for info / pending states
  static const gold = Color(0xFFD4A017);
  static const goldDim = Color(0x1FD4A017);

  /// Info blue — secondary accent for informational banners
  static const blue = Color(0xFF2196F3);
  static const blueDim = Color(0x1F2196F3);

  static const white = Colors.white;
  static const white70 = Color(0xB3FFFFFF);
  static const white60 =
      Color(0x99FFFFFF); // raised from white40 for readability
  static const white40 = Color(0x66FFFFFF);
  static const white15 = Color(0x26FFFFFF);
  static const white08 = Color(0x14FFFFFF);

  static const green = Color(0xFF4CAF50);
  static const greenDim = Color(0x1F4CAF50);
  static const orange = Color(0xFFFF9800);
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADIENTS
// ─────────────────────────────────────────────────────────────────────────────
class AppGradients {
  /// Main card gradient — black top → dark-red tinted bottom
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1010), Color(0xFF0A0A0A)],
  );

  /// Hero / splash radial glow behind logo
  static const radialGlow = RadialGradient(
    center: Alignment.center,
    radius: 0.75,
    colors: [Color(0x30E53935), Color(0x000A0A0A)],
  );

  /// Subtle red-tinted surface for active / selected cards
  static const redCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1010), Color(0xFF161616)],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT STYLES
// ─────────────────────────────────────────────────────────────────────────────
class AppTextStyles {
  static TextStyle heading(double size, {Color color = AppColors.white}) =>
      GoogleFonts.rajdhani(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2, // improved line-height for large headings
      );

  static TextStyle label({Color color = AppColors.white60}) =>
      GoogleFonts.rajdhani(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
        color: color,
      );

  static TextStyle body({double size = 14, Color color = AppColors.white}) =>
      GoogleFonts.dmSans(fontSize: size, color: color);

  static TextStyle bodyMedium(
          {double size = 14, Color color = AppColors.white}) =>
      GoogleFonts.dmSans(
          fontSize: size, fontWeight: FontWeight.w600, color: color);
}

// ─────────────────────────────────────────────────────────────────────────────
// DECORATIONS
// ─────────────────────────────────────────────────────────────────────────────
class AppDecorations {
  /// Standard card with subtle drop-shadow
  static BoxDecoration get card => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      );

  /// Smaller card with border and shadow
  static BoxDecoration get cardSmall => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.white08),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      );

  static BoxDecoration get alertBox => BoxDecoration(
        color: AppColors.redDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.redMid),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    primaryColor: AppColors.red,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.red,
      secondary: AppColors.gold,
      surface: AppColors.surface,
    ),
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),

    // AppBar: slight elevation so it separates from content
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 2,
      shadowColor: Colors.black54,
      centerTitle: true,
      titleTextStyle: GoogleFonts.rajdhani(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.white),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: GoogleFonts.dmSans(color: AppColors.white40, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.white08),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.white08),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.red),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        shadowColor: AppColors.redDark,
        textStyle:
            GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
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
      elevation: 12,
      selectedLabelStyle:
          GoogleFonts.rajdhani(fontSize: 11, letterSpacing: 0.5),
      unselectedLabelStyle:
          GoogleFonts.rajdhani(fontSize: 11, letterSpacing: 0.5),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.red
            : AppColors.white15,
      ),
    ),

    // Ripple colours consistent with brand
    splashColor: AppColors.redDim,
    highlightColor: AppColors.redDim,
  );
}
