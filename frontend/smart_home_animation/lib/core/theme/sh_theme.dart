import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sh_colors.dart';

abstract class SHTheme {
  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: SHColors.primary,
      secondary: SHColors.secondary,
      tertiary: SHColors.tertiary,
      surface: SHColors.cardColor,
      background: SHColors.black,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: SHColors.textColor,
      onBackground: SHColors.textColor,
      error: SHColors.rose,
    ),
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          color: SHColors.textColor,
          height: 1.05,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: SHColors.textColor,
          height: 1.1,
        ),
        displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: SHColors.textColor,
          height: 1.14,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: SHColors.textColor,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: SHColors.textColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: SHColors.textColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: SHColors.textColor,
          height: 1.35,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: SHColors.textColor,
          height: 1.35,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: SHColors.mutedText,
          height: 1.25,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: SHColors.textColor,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: SHColors.mutedText,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: SHColors.textColor,
      centerTitle: false,
    ),
    iconTheme: const IconThemeData(color: SHColors.textColor),
    dialogTheme: DialogThemeData(
      backgroundColor: SHColors.elevatedCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SHColors.radiusLg),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SHColors.textColor,
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SHColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SHColors.radiusMd),
        ),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SHColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SHColors.radiusMd),
        ),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: SHColors.primary,
      inactiveTrackColor: SHColors.trackColor,
      thumbColor: Colors.white,
      overlayColor: Color(0x222AC0D1),
      trackHeight: 4,
    ),
    cardTheme: CardThemeData(
      color: SHColors.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SHColors.radiusLg),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: SHColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedIconTheme: const IconThemeData(size: 26),
      unselectedIconTheme: const IconThemeData(size: 24),
      selectedItemColor: SHColors.primary,
      unselectedItemColor: SHColors.hintColor,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
