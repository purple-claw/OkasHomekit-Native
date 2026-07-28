// lib/features/home/presentation/widgets/figma_load_sheets.dart
// Bottom sheets matching the Figma designs for loads control.
// Imports the relevant load types' controllers from LoungeScreen style API.
import 'dart:math' as math;

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
        color: SHColors.elevatedCardColor,
        gradient: SHColors.cardGradient,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SHColors.radiusXl),
        ),
        border: Border(top: BorderSide(color: Colors.white24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 28,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.34),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Switch(
                  value: isOn,
                  onChanged: onToggle,
                  activeColor: SHColors.green,
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
                      side: BorderSide(color: Colors.white.withOpacity(0.22)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SHColors.radiusMd),
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
                      backgroundColor: SHColors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SHColors.radiusMd),
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
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: SHColors.trackColor,
            thumbColor: Colors.white,
            overlayColor: SHColors.primary.withOpacity(0.16),
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

class RgbGamutPicker extends StatelessWidget {
  const RgbGamutPicker({
    required this.red,
    required this.green,
    required this.blue,
    required this.onChanged,
    super.key,
  });

  final double red;
  final double green;
  final double blue;
  final void Function(int red, int green, int blue) onChanged;

  @override
  Widget build(BuildContext context) {
    final currentColor = Color.fromRGBO(
      red.round().clamp(0, 255),
      green.round().clamp(0, 255),
      blue.round().clamp(0, 255),
      1,
    );

    return Column(
      children: [
        const Text(
          'COLOR',
          style: TextStyle(
            color: SHColors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest.shortestSide;
              final hsv = HSVColor.fromColor(currentColor);
              final radius = size / 2;
              final markerRadius = hsv.saturation * radius;
              final markerAngle = hsv.hue * math.pi / 180;
              final marker = Offset(
                radius + math.cos(markerAngle) * markerRadius,
                radius + math.sin(markerAngle) * markerRadius,
              );

              void handle(Offset localPosition) {
                final center = Offset(radius, radius);
                final vector = localPosition - center;
                final saturation = (vector.distance / radius).clamp(0.0, 1.0);
                final hue =
                    ((math.atan2(vector.dy, vector.dx) * 180 / math.pi) + 360) %
                    360;
                final color = HSVColor.fromAHSV(
                  1,
                  hue,
                  saturation,
                  1,
                ).toColor();
                onChanged(color.red, color.green, color.blue);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) => handle(details.localPosition),
                onPanUpdate: (details) => handle(details.localPosition),
                onTapDown: (details) => handle(details.localPosition),
                child: Center(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/figma_rgb_gamut.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          left: marker.dx - 12,
                          top: marker.dy - 12,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: currentColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: currentColor,
            borderRadius: BorderRadius.circular(SHColors.radiusMd),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
        ),
      ],
    );
  }
}

class FigmaSegmentedOptions<T> extends StatelessWidget {
  const FigmaSegmentedOptions({
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    super.key,
  });

  final List<T> options;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((option) {
        final active = option == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onSelected(option),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: active
                      ? SHColors.primary
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(SHColors.radiusMd),
                  border: Border.all(
                    color: active
                        ? SHColors.primary
                        : Colors.white.withOpacity(0.12),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  labelBuilder(option),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : SHColors.mutedText,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Convenience to read the latest load state from MQTT service.
class LoadSnapshot {
  LoadSnapshot(
    this.isOn,
    this.brightness,
    this.colorTemp,
    this.red,
    this.green,
    this.blue,
    this.hvacMode,
    this.temperature,
    this.fanSpeed,
    this.curtainPos,
    this.name,
    this.type,
  );

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
