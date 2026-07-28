// lib/core/theme/sh_colors.dart
import 'package:flutter/material.dart';

abstract class SHColors {
  static const Color primary = Color(0xFF2AC0D1);
  static const Color secondary = Color(0xFF007380);
  static const Color tertiary = Color(0xFF00375A);
  static const Color black = Color(0xFF02070D);

  static const Color navy950 = Color(0xFF06141E);
  static const Color navy900 = Color(0xFF082231);
  static const Color navy800 = Color(0xFF0B3543);
  static const Color teal700 = Color(0xFF0C6D75);
  static const Color teal500 = Color(0xFF1DB6C3);
  static const Color cyan300 = Color(0xFF75E8F0);
  static const Color green = Color(0xFF2DBE6A);
  static const Color amber = Color(0xFFFFB84D);
  static const Color violet = Color(0xFFAF7DFF);
  static const Color blue = Color(0xFF4BA3FF);
  static const Color rose = Color(0xFFFF6685);

  static const Color textColor = Color(0xFFE8F6F8);
  static const Color mutedText = Color(0xFFA9C3C9);
  static const Color hintColor = Color(0xFF78949B);
  static const Color cardColor = Color(0xFF12313B);
  static const Color elevatedCardColor = Color(0xFF173F4B);
  static const Color trackColor = Color(0xFF0B2731);
  static const Color selectedColor = Color(0xFFBDF8FF);

  static const Gradient backgroundColor = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0D5965),
      Color(0xFF072E42),
      Color(0xFF031827),
      Color(0xFF02070D),
    ],
    stops: [0.0, 0.28, 0.67, 1.0],
  );

  static const Gradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x3DFFFFFF), Color(0x171DB6C3), Color(0x1002070D)],
    stops: [0, 0.52, 1],
  );

  static const Gradient activeCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x552AC0D1), Color(0x221DBEAE), Color(0x1402070D)],
  );

  static const List<Color> cardColors = [
    Color(0xFF173F4B),
    Color(0xFF12313B),
    Color(0xFF0C2732),
  ];

  static const List<Color> dimmedLightColors = [
    Color(0x3375E8F0),
    Color(0x332AC0D1),
    Color(0x33007380),
  ];

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.28),
      blurRadius: 22,
      offset: const Offset(0, 12),
    ),
  ];

  static BoxDecoration glassDecoration({
    bool active = false,
    Color? accent,
    double radius = radiusLg,
  }) {
    final borderColor = active
        ? (accent ?? primary).withOpacity(0.55)
        : Colors.white.withOpacity(0.12);
    return BoxDecoration(
      color: elevatedCardColor.withOpacity(active ? 0.72 : 0.56),
      gradient: active ? activeCardGradient : cardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: softShadow,
    );
  }

  static Color deviceAccent(String type) {
    switch (type) {
      case 'Switch':
      case 'swt':
        return green;
      case 'Dimmer':
      case 'dim':
        return amber;
      case 'Tunable':
      case 'tun':
        return violet;
      case 'RGB':
      case 'rgb':
        return blue;
      case 'HVAC':
      case 'hvc':
        return cyan300;
      case 'Scene':
      case 'scn':
        return rose;
      case 'Fan':
      case 'fan':
        return teal500;
      case 'Curtain':
      case 'cur':
        return green;
      default:
        return primary;
    }
  }
}
