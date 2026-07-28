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
    final color = SHColors.deviceAccent(deviceType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: SHColors.glassDecoration(
          active: isOn,
          accent: color,
          radius: SHColors.radiusLg,
        ),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isOn ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: _icon(deviceType, color)),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOn ? color : SHColors.hintColor,
                    shape: BoxShape.circle,
                    boxShadow: isOn
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.55),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              _label(deviceType),
              style: const TextStyle(
                color: SHColors.mutedText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              deviceName,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => onToggle(!isOn),
              child: Container(
                width: double.infinity,
                height: 34,
                decoration: BoxDecoration(
                  color: isOn
                      ? color.withOpacity(0.95)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isOn
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Icon(
                  Icons.power_settings_new,
                  color: isOn ? Colors.white : SHColors.hintColor,
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
      width: 24,
      height: 24,
      color: color,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.lightbulb_outline, color: color, size: 24),
    );
  }
}
