// lib/features/home/presentation/widgets/load_grid_card.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/core.dart';

/// Figma-style load card used on the Loads screen and the per-room
/// RoomLoadsScreen. 3-column grid: icon, label, type, round power button.
class LoadGridCard extends StatelessWidget {
  const LoadGridCard({
    required this.load,
    required this.onTap,
    required this.onToggle,
    super.key,
  });

  final Map<String, dynamic> load;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final deviceType = _deviceType(load['type'] ?? 'swt');
    final isOn = load['isOn'] ?? false;
    final deviceName = load['name'] ?? 'Device';
    final color = _color(deviceType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOn ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: _icon(deviceType, color),
            ),
            const SizedBox(height: 8),
            Text(
              _label(deviceType),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              deviceName,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => onToggle(!isOn),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isOn ? Colors.green : Colors.red.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.power_settings_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(String type) {
    switch (type) {
      case 'Dimmer':
        return 'BRIGHTNESS';
      case 'Tunable':
        return 'TUNNING';
      case 'RGB':
        return 'COLOR';
      case 'HVAC':
        return 'TEMP';
      case 'Fan':
        return 'SPEED';
      case 'Curtain':
        return 'MOVEMENT';
      case 'Scene':
        return 'SCENE';
      case 'Switch':
      default:
        return 'ON/OFF';
    }
  }

  String _deviceType(String type) {
    switch (type) {
      case 'swt':
        return 'Switch';
      case 'dim':
        return 'Dimmer';
      case 'tun':
        return 'Tunable';
      case 'rgb':
        return 'RGB';
      case 'hvc':
        return 'HVAC';
      case 'scn':
        return 'Scene';
      case 'fan':
        return 'Fan';
      case 'cur':
        return 'Curtain';
      default:
        return 'Switch';
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'Switch':
        return Colors.green;
      case 'Dimmer':
        return Colors.orange;
      case 'Tunable':
        return Colors.purple;
      case 'RGB':
        return Colors.blue;
      case 'HVAC':
        return Colors.cyan;
      case 'Scene':
        return Colors.pink;
      case 'Fan':
        return Colors.teal;
      case 'Curtain':
        return Colors.brown;
      default:
        return SHColors.primary;
    }
  }

  Widget _icon(String type, Color color) {
    String asset;
    switch (type) {
      case 'Switch':
        asset = 'assets/icons/switch.png';
        break;
      case 'Dimmer':
        asset = 'assets/icons/dimmer.png';
        break;
      case 'Tunable':
        asset = 'assets/icons/tunable.png';
        break;
      case 'RGB':
        asset = 'assets/icons/rgb.png';
        break;
      case 'HVAC':
        asset = 'assets/icons/hvac.png';
        break;
      case 'Scene':
        asset = 'assets/icons/scene.png';
        break;
      case 'Fan':
        asset = 'assets/icons/fan.png';
        break;
      case 'Curtain':
        asset = 'assets/icons/curtain.png';
        break;
      default:
        asset = 'assets/icons/light.png';
    }
    return Image.asset(
      asset,
      width: 32,
      height: 32,
      color: color,
      errorBuilder: (_, __, ___) => Icon(
        Icons.lightbulb_outline,
        color: color,
        size: 28,
      ),
    );
  }
}
