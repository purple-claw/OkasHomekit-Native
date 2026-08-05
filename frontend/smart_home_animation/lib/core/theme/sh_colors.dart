// lib/core/theme/sh_colors.dart
import 'package:flutter/material.dart';

abstract class SHColors {
  // ---- Brand palette ----
  static const Color primary = Color(0xFF2AC0D1);
  static const Color primaryBright = Color(0xFF4FE8F7);
  static const Color secondary = Color(0xFF007380);
  static const Color tertiary = Color(0xFF00375A);
  static const Color black = Color(0xFF02070D);

  // ---- Brand depth ----
  static const Color navy950 = Color(0xFF06141E);
  static const Color navy900 = Color(0xFF082231);
  static const Color navy800 = Color(0xFF0B3543);
  static const Color teal700 = Color(0xFF0C6D75);
  static const Color teal500 = Color(0xFF1DB6C3);
  static const Color cyan300 = Color(0xFF75E8F0);

  // ---- Brand accents ----
  static const Color green = Color(0xFF2DBE6A);
  static const Color amber = Color(0xFFFFB84D);
  static const Color violet = Color(0xFFAF7DFF);
  static const Color blue = Color(0xFF4BA3FF);
  static const Color rose = Color(0xFFFF6685);

  // ---- Premium accent (Keus-inspired champagne for favorite rooms,
  // premium scenes, the house-name eyebrow). ----
  static const Color champagne = Color(0xFFE8C58A);

  // ---- Text scale ----
  static const Color textColor = Color(0xFFE8F6F8);
  static const Color mutedText = Color(0xFFA9C3C9);
  static const Color hintColor = Color(0xFF78949B);

  // ---- Surfaces ----
  static const Color cardColor = Color(0xFF12313B);
  static const Color elevatedCardColor = Color(0xFF173F4B);
  static const Color trackColor = Color(0xFF0B2731);
  static const Color selectedColor = Color(0xFFBDF8FF);

  // ---- Soft status variants (12% alpha) for subtle status pills/badges ----
  static Color successSoft(Color base) => base.withOpacity(0.16);
  static Color warningSoft(Color base) => base.withOpacity(0.16);
  static Color dangerSoft(Color base) => base.withOpacity(0.16);
  static Color primarySoft(Color base) => base.withOpacity(0.18);

  // ---- Background gradient (kept from Figma, slightly tuned) ----
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

  // ---- Radial highlight overlay used by LightedBackground ----
  static const Gradient brandRadialGlow = RadialGradient(
    center: Alignment(-0.4, -0.6),
    radius: 1.2,
    colors: [
      Color(0x222AC0D1),
      Color(0x112AC0D1),
      Color(0x00000000),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Figma-spec radial gradient for curtain/sheet artboards. Outer stop
  /// is fully transparent so the curtain picks up the canvas glow.
  static Gradient curtainRadialGradient = const RadialGradient(
    center: Alignment(-0.16, -0.55),
    radius: 1.4,
    colors: [
      Color(0xFF2AC0D1),
      Color(0xFF007380),
      Color(0xFF00375A),
      Color(0x00000000),
    ],
    stops: [0.0, 0.277, 0.548, 0.957],
  );

  /// Figma Frame1 splash background: radial teal-to-black glow centred at
  /// the top-right (350/414, 90/896), radius ~750px. The full-canvas
  /// wash that sets the dark teal "premium glass" tone before the home
  /// screen takes over.
  static const Gradient splashBackgroundGradient = RadialGradient(
    center: Alignment(0.69, -0.80),
    radius: 1.5,
    colors: [
      Color(0xFF0E8D91),
      Color(0xFF084D5D),
      Color(0xFF032136),
      Color(0xFF010A14),
    ],
    stops: [0.0, 0.35, 0.70, 1.0],
  );

  // ---- Card / surface gradients ----
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

  // Premium card gradient for favorite rooms and special highlights.
  static const Gradient premiumCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x44E8C58A), Color(0x182AC0D1), Color(0x1002070D)],
  );

  static const List<Color> cardColors = [
    Color(0xFF173F4B),
    Color(0xFF12313B),
    Color(0xFF0C2731),
  ];

  static const List<Color> dimmedLightColors = [
    Color(0x3375E8F0),
    Color(0x332AC0D1),
    Color(0x33007380),
  ];

  // ---- Radii (1-4-9 system; expanded with cardXl for premium cards) ----
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double cardXl = 24;
  static const double pillRadius = 999;

  // Figma slider geometry (frame_10000.xml: 280dp wide, 24dp tall).
  static const double figmaSliderWidth = 280;
  static const double figmaSliderHeight = 24;

  // ---- Elevation tiers (replaces single softShadow) ----
  static List<BoxShadow> get shadowSubtle => [
        BoxShadow(
          color: Colors.black.withOpacity(0.16),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: Colors.black.withOpacity(0.28),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get shadowRaised => [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 32,
          offset: const Offset(0, 18),
        ),
      ];

  static List<BoxShadow> get shadowSheet => [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 28,
          offset: const Offset(0, -12),
        ),
      ];

  /// Cyan glow used by active loads and selected rooms. Matches the
  /// 24px-blur, 30% opacity recipe from the design notes.
  static List<BoxShadow> glow(Color color, {double opacity = 0.30}) => [
        BoxShadow(
          color: color.withOpacity(opacity),
          blurRadius: 24,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
      ];

  /// Kept for back-compat with callers that previously referenced
  /// `softShadow`. Maps to the new shadowCard tier.
  static List<BoxShadow> get softShadow => shadowCard;

  static BoxDecoration glassDecoration({
    bool active = false,
    Color? accent,
    double radius = radiusLg,
    bool premium = false,
  }) {
    final borderColor = active
        ? (accent ?? primary).withOpacity(0.55)
        : premium
            ? champagne.withOpacity(0.4)
            : Colors.white.withOpacity(0.12);
    return BoxDecoration(
      color: elevatedCardColor.withOpacity(active ? 0.72 : 0.56),
      gradient: active
          ? activeCardGradient
          : premium
              ? premiumCardGradient
              : cardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: active && accent != null ? glow(accent, opacity: 0.18) : shadowCard,
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