// lib/core/shared/presentation/widgets/glass_panel.dart
//
// The app's frosted-glass card recipe (rim + inner fill + specular bloom)
// as a reusable surface. Same visual language as LoadGridCard and the
// scene cards: dark frosted glass, faint neutral rim, no shadows.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../theme/sh_colors.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = SHColors.radiusLg,
    this.blur = 12,
    this.accent,
    this.fillColor,
    this.onTap,
  });

  final Widget child;

  /// Corner radius of the panel.
  final double radius;

  /// Gaussian blur sigma applied to whatever sits behind the panel.
  final double blur;

  /// When set, the rim and bloom take on this color instead of neutral
  /// white — used for tinted states (active, premium, danger).
  final Color? accent;

  /// Opaque fill for surfaces that must stay readable over busy
  /// backgrounds (dialogs/popups). Defaults to translucent white.
  final Color? fillColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rimColor = accent != null
        ? accent!.withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.13);

    final surface = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter.grouped(
          // ponytail: .grouped isolates the blur to this panel; plain
          // BackdropFilter here blurred the whole screen (IndexedStack).
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Stack(
            children: [
              // ponytail: decoration layers are Positioned.fill so the panel
              // sizes to its content; plain Containers here expanded to the
              // full screen inside the Add-guest dialog.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: rimColor, width: 1),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(1.1),
                  decoration: BoxDecoration(
                    color: fillColor ?? Colors.white.withValues(alpha: 0.018),
                    borderRadius: BorderRadius.circular(radius - 1.1),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: RadialGradient(
                        center: const Alignment(-0.85, -1.05),
                        radius: 1.25,
                        colors: [
                          (accent ?? Colors.white).withValues(
                            alpha: accent != null ? 0.14 : 0.055,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return surface;
    return GestureDetector(onTap: onTap, child: surface);
  }
}

/// Small round glass icon button used for row-level actions.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.color,
    this.tooltip,
    this.onPressed,
    this.size = 34,
    this.iconSize = 18,
  });

  final IconData icon;
  final Color color;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Frosted-glass pill chip (status, role, inline action).
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    this.color = SHColors.green,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(SHColors.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon!, size: 12, color: color),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
