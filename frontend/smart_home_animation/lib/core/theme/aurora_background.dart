// lib/core/theme/aurora_background.dart
//
// Full-screen background for all non-auth/non-splash screens.
// Default variant replicates the approved reference image: a smooth
// vertical teal-to-black gradient with a single soft atmospheric glow
// in the top-right. Static (zero-animation) so scrolling stays smooth.
import 'package:flutter/material.dart';

import 'sh_colors.dart';

enum OkasBackground { reference, ocean, spotlight }

/// Flip while testing candidates; the winner becomes the default.
abstract class OkasBackgroundConfig {
  static OkasBackground active = OkasBackground.reference;
}

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, this.child, this.variant});

  final Widget? child;
  final OkasBackground? variant;

  @override
  Widget build(BuildContext context) {
    final v = variant ?? OkasBackgroundConfig.active;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _base(v)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final glow in _glows(v))
            IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(gradient: glow)),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }

  static Gradient _base(OkasBackground v) {
    switch (v) {
      // Exact gradient of the approved reference image: deep teal fading
      // through dark teal to absolute black, top to bottom.
      case OkasBackground.reference:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B4D4F),
            Color(0xFF0D2628),
            Color(0xFF040C0D),
            Color(0xFF000000),
          ],
          stops: [0.0, 0.25, 0.6, 1.0],
        );
      case OkasBackground.ocean:
        return SHColors.backgroundColor;
      case OkasBackground.spotlight:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF06141E), Color(0xFF02070D)],
        );
    }
  }

  static List<RadialGradient> _glows(OkasBackground v) {
    switch (v) {
      // Single atmospheric glow upper-center-right, matching the
      // reference image. Wide radius + gentle stops = soft, blur-like
      // falloff with no visible edge.
      case OkasBackground.reference:
        return const [
          RadialGradient(
            center: Alignment(0.55, -0.85),
            radius: 1.6,
            colors: [Color(0x402A6F72), Color(0x1F2A6F72), Color(0x00000000)],
            stops: [0.0, 0.45, 1.0],
          ),
          RadialGradient(
            center: Alignment(0.55, -0.85),
            radius: 0.9,
            colors: [Color(0x242A6F72), Color(0x00000000)],
            stops: [0.0, 1.0],
          ),
        ];

      // Current brand teal ramp kept as base, deepened with a top
      // spotlight and two corner depth glows.
      case OkasBackground.ocean:
        return const [
          RadialGradient(
            center: Alignment(0.0, -0.75),
            radius: 1.0,
            colors: [Color(0x401DB6C3), Color(0x00000000)],
            stops: [0.0, 1.0],
          ),
          RadialGradient(
            center: Alignment(0.95, 0.9),
            radius: 1.2,
            colors: [Color(0x59007380), Color(0x00000000)],
            stops: [0.0, 1.0],
          ),
          RadialGradient(
            center: Alignment(-0.8, 0.3),
            radius: 1.0,
            colors: [Color(0x302AC0D1), Color(0x00000000)],
            stops: [0.0, 1.0],
          ),
        ];

      // Darkest base; one large soft cyan aurora behind the content area
      // so the cards sit in a stage of light, corners fall to black.
      case OkasBackground.spotlight:
        return const [
          RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 1.35,
            colors: [Color(0x302AC0D1), Color(0x102AC0D1), Color(0x00000000)],
            stops: [0.0, 0.55, 1.0],
          ),
          RadialGradient(
            center: Alignment(-0.85, 0.85),
            radius: 1.15,
            colors: [Color(0x4D007380), Color(0x00000000)],
            stops: [0.0, 1.0],
          ),
          RadialGradient(
            center: Alignment(0.85, -0.85),
            radius: 1.1,
            colors: [Color(0x3D00375A), Color(0x00000000)],
            stops: [0.0, 1.0],
          ),
        ];
    }
  }
}
