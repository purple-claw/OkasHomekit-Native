// lib/features/home/presentation/widgets/figma_load_sheets.dart
// Bottom sheets matching the Figma designs for loads control.
// Imports the relevant load types' controllers from LoungeScreen style API.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';

/// Generic Figma-style bottom sheet wrapper used by every load control sheet.
/// It draws the rounded container, the title + master toggle on the right,
/// the body content and the Cancel / Save button row at the bottom.
class FigmaLoadSheet extends StatelessWidget {
  const FigmaLoadSheet({
    required this.title,
    required this.isOn,
    required this.onToggle,
    required this.body,
    super.key,
  });

  final String title;
  final bool isOn;
  final ValueChanged<bool> onToggle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F4A55),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: isOn,
                  onChanged: onToggle,
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.white54,
                ),
              ],
            ),
            const SizedBox(height: 16),
            body,
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.white.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF2DBE6A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "BRIGHTNESS" / dimmer slider used by Dimmer, Tunable and RGB sheets.
class BrightnessSlider extends StatelessWidget {
  const BrightnessSlider({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${value.round()}%',
          style: const TextStyle(
            color: SHColors.primary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white10,
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Convenience to read the latest load state from MQTT service.
class LoadSnapshot {
  LoadSnapshot(this.isOn, this.brightness, this.colorTemp, this.red,
      this.green, this.blue, this.hvacMode, this.temperature, this.fanSpeed,
      this.curtainPos, this.name, this.type);

  final bool isOn;
  final double brightness;
  final double colorTemp;
  final double red;
  final double green;
  final double blue;
  final String hvacMode;
  final double temperature;
  final double fanSpeed;
  final double curtainPos;
  final String name;
  final String type;

  factory LoadSnapshot.from(Map<String, dynamic> m) {
    return LoadSnapshot(
      m['isOn'] ?? false,
      (m['brightness'] ?? 0).toDouble(),
      (m['cTp'] ?? 0).toDouble(),
      (m['red'] ?? 255).toDouble(),
      (m['green'] ?? 255).toDouble(),
      (m['blue'] ?? 255).toDouble(),
      m['hvacMode'] ?? 'Cool',
      (m['temp'] ?? 25).toDouble(),
      ((m['fanSpeed'] ?? m['fSp'] ?? 0)).toDouble(),
      (m['tPs'] ?? m['cPs'] ?? m['pos'] ?? 0).toDouble(),
      m['name'] ?? 'Device',
      m['type'] ?? 'swt',
    );
  }
}

LoadSnapshot snapshotFor(BuildContext context, Map<String, dynamic> load) {
  final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
  final id = load['id']?.toString() ?? '';
  final cur = mqtt.loads[id] ?? mqtt.devices[id] ?? load;
  return LoadSnapshot.from(cur);
}
