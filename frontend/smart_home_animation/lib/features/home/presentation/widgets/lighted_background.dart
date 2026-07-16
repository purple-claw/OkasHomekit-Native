// lib/features/home/presentation/widgets/lighted_background.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';

class LightedBackgound extends StatelessWidget {
  const LightedBackgound({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: SHColors.backgroundColor),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Light effect overlay
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.3, -0.2),
                  radius: 0.8,
                  colors: [Colors.white.withOpacity(0.08), Colors.transparent],
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
