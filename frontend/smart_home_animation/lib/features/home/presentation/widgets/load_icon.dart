import 'package:flutter/material.dart';

/// Resolves load icon assets, including state-specific switch and fan icons.
String loadIconAssetPath(String type, {bool isOn = false}) {
  switch (type.toLowerCase()) {
    case 'swt':
    case 'switch':
      return isOn ? 'assets/icons/switchon.png' : 'assets/icons/switchoff.png';
    case 'light':
      return 'assets/icons/light.png';
    case 'dim':
    case 'dimmer':
      return 'assets/icons/dimmer.png';
    case 'tun':
    case 'tunable':
      return 'assets/icons/tunable.png';
    case 'rgb':
      return 'assets/icons/rgb.png';
    case 'hvc':
    case 'hvac':
      return 'assets/icons/hvac.png';
    case 'scn':
    case 'scene':
      return 'assets/icons/scene.png';
    case 'fan':
      return isOn ? 'assets/icons/fanon.png' : 'assets/icons/fanoff.png';
    case 'cur':
    case 'curtain':
      return 'assets/icons/curtain.png';
    default:
      return 'assets/icons/light.png';
  }
}

class LoadIcon extends StatelessWidget {
  const LoadIcon({
    required this.type,
    this.isOn = false,
    this.color,
    this.size = 24,
    super.key,
  });

  final String type;
  final bool isOn;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      loadIconAssetPath(type, isOn: isOn),
      width: size,
      height: size,
      color: color,
      errorBuilder: (_, __, ___) => Icon(
        Icons.lightbulb_outline,
        color: color ?? Colors.white54,
        size: size,
      ),
    );
  }
}
