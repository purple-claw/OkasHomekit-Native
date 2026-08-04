// lib/core/theme/sh_motion.dart
//
// Centralised motion tokens for the OKAS app rebrand. Anything that
// animates a duration, a curve, or a stagger reads from here so the
// whole app feels like one product. Honours `prefers-reduced-motion`
// automatically — animations collapse to 0ms when the user has it set.
import 'package:flutter/material.dart';

abstract class SHMotion {
  static const Duration _kFast = Duration(milliseconds: 180);
  static const Duration _kMedium = Duration(milliseconds: 240);
  static const Duration _kSheet = Duration(milliseconds: 360);
  static const Duration _kStagger = Duration(milliseconds: 24);

  /// Quick state transitions: hover, press, toggle.
  static const Curve curve = Curves.easeOutCubic;
  static const Curve curveEnter = Curves.easeOutQuart;
  static const Curve curveExit = Curves.easeInCubic;

  /// Respects the user's accessibility preference. Use this wherever
  /// you would normally pass a raw [Duration].
  static Duration duration(BuildContext context, Duration fallback) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return reduce ? Duration.zero : fallback;
  }

  /// Returns true when the user has opted out of motion.
  static bool isReduced(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;

  /// Stagger delay for the n-th item in a list (24ms cap). Disabled
  /// when motion is reduced.
  static Duration stagger(BuildContext context, int index) {
    if (isReduced(context)) return Duration.zero;
    return Duration(milliseconds: index * _kStagger.inMilliseconds);
  }

  /// The "stardard" interaction duration used for cards, switches, etc.
  static Duration fast(BuildContext context) => duration(context, _kFast);

  /// Slightly slower duration used for sheets / page transitions.
  static Duration medium(BuildContext context) => duration(context, _kMedium);

  /// Slowest standard duration used for modal sheet entrances.
  static Duration sheet(BuildContext context) => duration(context, _kSheet);
}

/// Shared transition builders used by routes / sheets.
abstract class SHTransitions {
  static Widget fadeSlide({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
    Duration duration = const Duration(milliseconds: 240),
  }) {
    final curved = CurvedAnimation(parent: animation, curve: SHMotion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Reusable motion wrappers. Use these instead of building your own
/// FadeTransition / SlideTransition so every animation respects the
/// reduced-motion preference and uses the brand duration tokens.
abstract class SHAnimated {
  /// Fade-in entrance. Pair with [SHAnimated.scaleIn] for a Keus-style
  /// 3-beat reveal.
  static Widget fadeIn({
    required BuildContext context,
    required Widget child,
    Duration delay = Duration.zero,
    Duration duration = const Duration(milliseconds: 280),
  }) {
    if (SHMotion.isReduced(context)) return child;
    return TweenAnimationBuilder<double>(
      duration: duration + delay,
      tween: Tween(begin: 0, end: 1),
      curve: SHMotion.curveEnter,
      builder: (context, value, c) => Opacity(opacity: value, child: c),
      child: child,
    );
  }

  /// Scale-in entrance. Always paired with [SHAnimated.fadeIn] for
  /// the 3-beat reveal (opacity 0→1, scale 0.96→1, translateY 8→0).
  static Widget scaleIn({
    required BuildContext context,
    required Widget child,
    Duration delay = Duration.zero,
    Duration duration = const Duration(milliseconds: 280),
  }) {
    if (SHMotion.isReduced(context)) return child;
    return TweenAnimationBuilder<double>(
      duration: duration + delay,
      tween: Tween(begin: 0, end: 1),
      curve: SHMotion.curveEnter,
      builder: (context, value, c) {
        final scale = 0.96 + 0.04 * value;
        final ty = (1 - value) * 8.0;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, ty),
            child: Transform.scale(scale: scale, child: c),
          ),
        );
      },
      child: child,
    );
  }
}

/// Subtle shimmer animation used by [StatusPill] when reconnecting.
class SHShimmer extends StatefulWidget {
  const SHShimmer({
    required this.child,
    this.base = Colors.white24,
    this.highlight = Colors.white70,
    super.key,
  });

  final Widget child;
  final Color base;
  final Color highlight;

  @override
  State<SHShimmer> createState() => _SHShimmerState();
}

/// Translates a gradient by [dx] along the x-axis. Flutter ships
/// [GradientRotation] but no translation helper, so this tiny transform
/// fills that gap for the shimmer sweep.
class _GradientShift extends GradientTransform {
  const _GradientShift(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

class _SHShimmerState extends State<SHShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SHMotion.isReduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final dx = (rect.width * 1.4) * (t - 0.5);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [widget.base, widget.highlight, widget.base],
              stops: const [0.35, 0.5, 0.65],
              transform: _GradientShift(dx),
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}