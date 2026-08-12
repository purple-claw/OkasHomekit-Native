// lib/core/shared/presentation/widgets/skeleton.dart
//
// Shimmering skeleton loader used while the app is connecting to the
// OKAS board / MQTT broker. Replaces the old spinner + "Connecting..."
// fallback so the UI reads as "content is loading" instead of "the app
// disconnected". The shimmer is driven by a single animation controller
// and respects the user's reduced-motion preference (static bones).
import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';

/// A single shimmering placeholder "bone".
class SkeletonBone extends StatelessWidget {
  const SkeletonBone({
    super.key,
    this.width,
    required this.height,
    this.radius = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final double radius;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SHColors.cardColor,
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
    );
  }
}

/// Wraps a subtree of [SkeletonBone]s with a shimmer sweep. Pass
/// [child] = the column/row of bones.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) return;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Sweep the highlight across the bones by shifting the gradient
        // stops. No GradientTransform dependency — works on all Flutter
        // versions.
        final start = (t - 0.5).clamp(-0.5, 0.5).toDouble();
        final mid = (start + 0.25).clamp(0.0, 1.0).toDouble();
        final end = (start + 0.5).clamp(0.0, 1.0).toDouble();
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                SHColors.cardColor,
                Colors.white.withValues(alpha: 0.14),
                SHColors.cardColor,
              ],
              stops: [start, mid, end],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Loads-grid skeleton: a header + category chips + a 3-column grid of
/// tile bones. Matches the Figma Loads screen layout.
class LoadsGridSkeleton extends StatelessWidget {
  const LoadsGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBone(width: 132, height: 24, radius: 8),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) =>
                    const SkeletonBone(width: 88, height: 46, radius: 23),
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 9,
              itemBuilder: (_, __) => const AspectRatio(
                aspectRatio: 0.75,
                child: SkeletonBone(height: double.infinity, radius: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
