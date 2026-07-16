// lib/core/theme/sh_colors.dart
import 'package:flutter/material.dart';

abstract class SHColors {
  // Existing colors
  static const Color textColor = Color(0xFFD0D7E1);
  static const Color hintColor = Color(0xFF717578);
  static const Color cardColor = Color(0xff4D565F);
  static const Color trackColor = Color(0xff2C3037);
  static const Color selectedColor = Color(0xffE3D0B2);

  // New custom colors
  static const Color primary = Color(0xFF2AC0D1); // #2AC0D1 - Teal/Cyan
  static const Color secondary = Color(0xFF007380); // #007380 - Dark Teal
  static const Color tertiary = Color(0xFF00375A); // #00375A - Navy Blue
  static const Color black = Color(0xFF000000); // #000000 - Black

  // Background gradient using all four colors - Fixed for better visibility
  static const Gradient backgroundColor = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF2AC0D1), // #2AC0D1 - Teal/Cyan at top
      Color(0xFF007380), // #007380 - Dark Teal in middle
      Color(0xFF00375A), // #00375A - Navy Blue
      Color(0xFF1A1A2E), // Dark blue-black at bottom (instead of pure black)
    ],
    stops: [0.0, 0.3, 0.6, 1.0],
  );

  static const List<Color> cardColors = [
    Color(0xff60656D),
    Color(0xff4D565F),
    Color(0xff464D57),
  ];

  static const List<Color> dimmedLightColors = [
    Color(0x3380E0F0),
    Color(0x3300A0B0),
    Color(0x33005580),
  ];
}
