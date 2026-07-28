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
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                  ],
                  stops: const [0, 0.34, 1],
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
