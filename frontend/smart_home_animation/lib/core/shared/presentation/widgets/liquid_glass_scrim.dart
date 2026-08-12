// lib/core/shared/presentation/widgets/liquid_glass_scrim.dart
//
// A reusable "liquid glass" backdrop used by modal sheets and popups.
//
// Goal: replace the heavy opaque-sheet look with the original translucent
// Figma glass aesthetic, but blur + dim the screen underneath so the user
// can't actually see the cards / text behind the sheet. The result reads
// as "focus is on this sheet, everything else is in soft glass" — the
// iOS-style liquid-glass pattern.
//
// Implementation note — why we use `showDialog` instead of
// `showModalBottomSheet`:
//   `showModalBottomSheet` always wraps the child in a full-screen
//   Material route. That route, combined with a `Stack(fit: StackFit.expand)`
//   scrim, forces the sheet (and the scrim) to fill the entire screen —
//   which made the cards under the sheet appear to slide up to the top.
//   `showDialog` with `barrierColor: Colors.transparent` gives us a
//   fullscreen overlay without the route's intrinsic child sizing, so the
//   sheet can render at the bottom of the screen at its natural height
//   while the scrim blurs the rest in place.
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/sh_colors.dart';

/// Full-screen blurred + dimmed backdrop. The blur hides the cards and
/// text underneath while keeping the Figma glass colour palette; the dim
/// layer adds a subtle dark wash so the focused sheet stands out.
///
/// Renders as a [Stack] (not a [Positioned.fill]) so callers control the
/// size. When wrapped in `Align(alignment: Alignment.bottomCenter, ...)`,
/// the scrim still covers the whole screen but the sheet on top of it
/// only takes its natural height — cards beneath stay put.
class LiquidGlassScrim extends StatelessWidget {
  const LiquidGlassScrim({
    this.blurSigma = 18,
    this.dimOpacity = 0.32,
    this.gradient,
    super.key,
  });

  /// Strength of the Gaussian blur applied to the underlayer. Higher =
  /// more "out of focus" content underneath.
  final double blurSigma;

  /// Opacity of the dark wash drawn on top of the blurred layer. Kept
  /// low so the Figma palette stays readable through the blur.
  final double dimOpacity;

  /// Optional tint applied on top of the dim wash. When null, the scrim
  /// is plain blur + dim.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blur whatever is behind this scrim so the cards underneath
        // become a soft glass texture instead of crisp text and shapes.
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: const SizedBox.expand(),
        ),
        // Subtle dim wash so the focused sheet sits clearly on top.
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(dimOpacity),
          ),
        ),
        // Faint gradient tint tying the scrim to the Figma palette.
        if (gradient != null)
          DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
          ),
      ],
    );
  }
}

/// Wraps a sheet body with the liquid-glass scrim in a way that does not
/// force the body to fill the screen. The body sits at the bottom of the
/// scrim via [Align], so a `FigmaLoadSheet` sized to its content stays
/// at its content height — it no longer expands to fill the screen.
class LiquidGlassSheet extends StatelessWidget {
  const LiquidGlassSheet({
    required this.body,
    this.blurSigma = 18,
    this.dimOpacity = 0.32,
    this.gradient,
    super.key,
  });

  final Widget body;
  final double blurSigma;
  final double dimOpacity;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen scrim — fills the overlay so the blur covers every
        // card on the screen, not just the area behind the sheet.
        LiquidGlassScrim(
          blurSigma: blurSigma,
          dimOpacity: dimOpacity,
          gradient: gradient ??
              const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x5502070D),
                ],
              ),
        ),
        // Tap-outside-to-dismiss catcher. The sheet body (below) sits on
        // top of this and absorbs its own taps; taps anywhere else land
        // here and pop the overlay. Without it the full-screen Stack
        // covers the whole route, leaving the dialog barrier zero area
        // to receive taps, so tap-outside could never dismiss the sheet.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        // Sheet body pinned to the bottom of the screen. SizedToBox
        // (the default for Align when the child is finite) lets the body
        // take its natural height — this is what stops the sheet from
        // expanding to fill the screen.
        Align(
          alignment: Alignment.bottomCenter,
          child: body,
        ),
      ],
    );
  }
}

/// Stronger scrim variant for full-screen modal popups (e.g. the load
/// control sheet). More blur + dim so the focused controls feel truly
/// isolated from the rest of the app.
class LiquidGlassModalScrim extends StatelessWidget {
  const LiquidGlassModalScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return const LiquidGlassScrim(
      blurSigma: 24,
      dimOpacity: 0.42,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x330D5965),
          Color(0x6602070D),
        ],
      ),
    );
  }
}

/// Drop-in replacement for `showModalBottomSheet` that opens a transparent
/// overlay route with the liquid-glass scrim behind the sheet. Use this
/// in place of the raw `showModalBottomSheet` for every load control
/// sheet, room detail sheet, and image picker sheet so the focused
/// surface stays glassy while the rest of the screen is blurred out.
///
/// `builder` should return just the sheet body (typically a
/// [FigmaLoadSheet] or a [DraggableScrollableSheet]); the scrim and the
/// modal wrapper are added by this helper.
Future<T?> showLiquidGlassModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  ShapeBorder? shape,
  String? barrierLabel,
  // Kept for source-compatibility with the previous `showModalBottomSheet`
  // call sites; ignored by `showDialog` (which always fills the route).
  bool isScrollControlled = true,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    barrierLabel: barrierLabel,
    barrierDismissible: true,
    useSafeArea: false,
    useRootNavigator: true,
    builder: (ctx) => LiquidGlassSheet(
      body: Builder(builder: builder),
    ),
  );
}

/// Re-export the Figma sheet-border / corner-radius tokens so callers can
/// stay consistent without importing the theme directly.
const double liquidGlassSheetRadius = SHColors.radiusXl;
