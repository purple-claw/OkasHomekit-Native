// lib/core/shared/presentation/widgets/parallax_image_card.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/safe_image.dart';

class ParallaxImageCard extends StatelessWidget {
  final String imageUrl;
  final double parallaxValue;

  const ParallaxImageCard({
    super.key,
    required this.imageUrl,
    this.parallaxValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Transform.translate(
        offset: Offset(0, parallaxValue * 20),
        child: SafeImage(
          imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
