// lib/features/home/presentation/widgets/lighted_background.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/theme/aurora_background.dart';

class LightedBackgound extends StatelessWidget {
  const LightedBackgound({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle vertical wash — slightly brighter at top, dims to
          // black at bottom for contrast against the bottom nav.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.22),
                  ],
                  stops: const [0, 0.4, 1],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}