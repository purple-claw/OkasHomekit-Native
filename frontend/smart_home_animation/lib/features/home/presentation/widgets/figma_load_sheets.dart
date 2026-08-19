// lib/features/home/presentation/widgets/figma_load_sheets.dart
// Bottom sheets matching the Figma designs for loads control.
// Imports the relevant load types' controllers from LoungeScreen style API.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/glass_panel.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';

/// Confirmation dialog with Yes / No. If the user never answers, the
/// action runs automatically after [timeout] (5 seconds by default).
void showPowerConfirmDialog(
  BuildContext context, {
  required String message,
  required VoidCallback action,
  Duration timeout = const Duration(seconds: 5),
}) {
  showDialog(
    context: context,
    builder: (_) =>
        _PowerConfirmDialog(message: message, action: action, timeout: timeout),
  );
}

class _PowerConfirmDialog extends StatefulWidget {
  const _PowerConfirmDialog({
    required this.message,
    required this.action,
    required this.timeout,
  });

  final String message;
  final VoidCallback action;
  final Duration timeout;

  @override
  State<_PowerConfirmDialog> createState() => _PowerConfirmDialogState();
}

class _PowerConfirmDialogState extends State<_PowerConfirmDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.timeout, () {
      if (!mounted) return;
      Navigator.pop(context);
      widget.action();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _choose(bool yes) {
    _timer?.cancel();
    Navigator.pop(context);
    if (yes) widget.action();
  }

  @override
  Widget build(BuildContext context) {
    return FrostedAlertDialog(
      title: const Text('Are You Sure?', style: TextStyle(color: Colors.white)),
      content: Text(widget.message, style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => _choose(false),
          child: const Text('No', style: TextStyle(color: SHColors.rose)),
        ),
        TextButton(
          onPressed: () => _choose(true),
          child: const Text('Yes', style: TextStyle(color: SHColors.green)),
        ),
      ],
    );
  }
}

/// Generic Figma-style bottom sheet wrapper used by every load control sheet.
/// It draws the rounded container, the title + master toggle on the right,
/// the body content and the Cancel / Save button row at the bottom.
class FigmaLoadSheet extends StatelessWidget {
  const FigmaLoadSheet({
    required this.title,
    required this.isOn,
    required this.onToggle,
    required this.body,
    this.useRadialGradient = false,
    this.showToggle = true,
    super.key,
  });

  final String title;
  final bool isOn;
  final ValueChanged<bool> onToggle;
  final Widget body;

  /// When true, the sheet uses the Figma curtain radial gradient
  /// (cyan -> teal -> dark blue -> black) instead of the glass card gradient.
  final bool useRadialGradient;

  /// When false, the master toggle switch next to the title is hidden
  /// (curtain sheet: position is controlled by the slider / buttons only).
  final bool showToggle;

  @override
  Widget build(BuildContext context) {
    // This sheet is used inside a custom fullscreen overlay (liquid glass
    // scrim) that provides no Material ancestor, yet the title Switch and
    // every body control (Slider etc.) require one. A single transparent
    // Material at the root covers the whole sheet.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          // Restore the translucent Figma glass / curtain gradient. The
          // caller is expected to wrap this sheet in a LiquidGlassSheet so
          // the load grid behind the sheet is blurred and the controls stay
          // legible without needing a heavy opaque backdrop.
          color: SHColors.elevatedCardColor.withValues(alpha: 0.45),
          gradient: useRadialGradient
              ? SHColors.curtainRadialGradient
              : SHColors.cardGradient,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SHColors.radiusXl),
          ),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
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
                  color: Colors.white.withValues(alpha: 0.34),
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
                  if (showToggle)
                    Switch(
                      value: isOn,
                      onChanged: onToggle,
                      activeThumbColor: SHColors.green,
                      inactiveThumbColor: Colors.white54,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // The body is wrapped in a scroll view with a max height so a
              // tall body (curtain sheet with visualization + slider + 3
              // buttons) never overflows the screen and misaligns the
              // bottom button row.
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: body,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
        FigmaSlider(
          value: value,
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Figma-spec slider (frame_10000.xml): 280dp wide, 24dp tall.
/// Renders the active progress on the right with a cyan-white fill and
/// an inactive track in SHColors.trackColor.
class FigmaSlider extends StatelessWidget {
  const FigmaSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.activeColor = SHColors.primary,
    this.inactiveColor,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final Color activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: SHColors.figmaSliderWidth,
      height: SHColors.figmaSliderHeight,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 6,
          activeTrackColor: Colors.white,
          inactiveTrackColor: inactiveColor ?? SHColors.trackColor,
          thumbColor: Colors.white,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          overlayColor: activeColor.withValues(alpha: 0.16),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Figma-style curtain visualization: two panels that slide toward the
/// centre as the curtain closes. position 0 = fully open, 1 = fully closed.
class CurtainVisualization extends StatelessWidget {
  const CurtainVisualization({
    required this.position,
    this.height = 96,
    super.key,
  });

  final double position;
  final double height;

  @override
  Widget build(BuildContext context) {
    final closeFactor = position.clamp(0.0, 1.0);
    return SizedBox(
      width: SHColors.figmaSliderWidth,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SHColors.radiusMd),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFAFD6FF),
                    Color(0xFF75E8F0),
                    Color(0xFF2AC0D1),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5 + closeFactor * 0.5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    border: Border(
                      right: BorderSide(
                        color: SHColors.primary.withValues(alpha: 0.7),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5 + closeFactor * 0.5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    border: Border(
                      left: BorderSide(
                        color: SHColors.primary.withValues(alpha: 0.7),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    closeFactor == 0
                        ? 'OPEN'
                        : closeFactor == 1
                        ? 'CLOSED'
                        : '${(100 - closeFactor * 100).round()}%',
                    key: ValueKey(closeFactor.round()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RgbGamutPicker extends StatelessWidget {
  const RgbGamutPicker({
    required this.red,
    required this.green,
    required this.blue,
    required this.onChanged,
    this.brightness,
    this.onBrightnessChanged,
    super.key,
  });

  final double red;
  final double green;
  final double blue;
  final void Function(int red, int green, int blue) onChanged;

  /// Current brightness 0-100, kept as its own channel so the slider never
  /// disturbs the chosen hue/sat. Falls back to the color's value when unset.
  final double? brightness;
  final void Function(double brightness)? onBrightnessChanged;

  @override
  Widget build(BuildContext context) {
    final currentColor = Color.fromRGBO(
      red.round().clamp(0, 255),
      green.round().clamp(0, 255),
      blue.round().clamp(0, 255),
      1,
    );
    final hsv = HSVColor.fromColor(currentColor);

    return Column(
      children: [
        // Gamut wheel kept moderate (~55% of sheet width) per the Figma
        // frame — the oversized full-width wheel is what made the sheet
        // feel bloated.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest.shortestSide;
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
                    final saturation = (vector.distance / radius).clamp(
                      0.0,
                      1.0,
                    );
                    final hue =
                        ((math.atan2(vector.dy, vector.dx) * 180 / math.pi) +
                            360) %
                        360;
                    final color = HSVColor.fromAHSV(
                      1,
                      hue,
                      saturation,
                      1,
                    ).toColor();
                    onChanged((color.r * 255).round(), (color.g * 255).round(), (color.b * 255).round());
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (details) => handle(details.localPosition),
                    onPanUpdate: (details) => handle(details.localPosition),
                    onTapDown: (details) => handle(details.localPosition),
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
                          // Map-pin selector handle from the Figma frame:
                          // the pin tip points exactly at the chosen color.
                          Positioned(
                            left: marker.dx - 17,
                            top: marker.dy - 34,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 36,
                                  color: Colors.white,
                                ),
                                Icon(
                                  Icons.location_on,
                                  size: 30,
                                  color: currentColor,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BRIGHTNESS',
              style: TextStyle(
                color: SHColors.mutedText,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(brightness ?? hsv.value * 100).round()}%',
              style: const TextStyle(
                color: SHColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FigmaSlider(
          value: brightness ?? hsv.value * 100,
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: (v) {
            onBrightnessChanged?.call(v);
          },
        ),
      ],
    );
  }
}

/// Figma reference (ColorTun.png): vertical warm->cool pill gradient with a
/// capsule handle for color temperature, plus a separate BRIGHTNESS slider.
class TunablePicker extends StatelessWidget {
  const TunablePicker({
    required this.kelvin,
    required this.brightness,
    required this.onKelvinChanged,
    required this.onBrightnessChanged,
    super.key,
  });

  final double kelvin;
  final double brightness;
  final ValueChanged<double> onKelvinChanged;
  final ValueChanged<double> onBrightnessChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: SizedBox(
            height: 220,
            width: 64,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barHeight = constraints.maxHeight;
                final t = ((kelvin - 2700) / (6500 - 2700)).clamp(0.0, 1.0);
                // Warm (2700K) sits at the bottom, cool (6500K) at the top.
                final handleY = barHeight * (1 - t);

                void handle(Offset localPosition) {
                  final nt = (1 - localPosition.dy / barHeight).clamp(0.0, 1.0);
                  onKelvinChanged(2700 + nt * 3800);
                }

                // Raw pointer events instead of pan gestures: the dialog can
                // host competing recognizers, and Listener is not part of the
                // gesture arena, so vertical drags always reach the picker.
                return Listener(
                  onPointerDown: (e) => handle(e.localPosition),
                  onPointerMove: (e) => handle(e.localPosition),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: barHeight,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xFFFFB84D),
                              Color(0xFFFFE7B5),
                              Color(0xFFE8F6F8),
                              Color(0xFFD6E6EE),
                              Color(0xFFF4F7F9),
                            ],
                            stops: [0, 0.28, 0.5, 0.75, 1],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      Positioned(
                        top: handleY - 12,
                        child: Container(
                          width: 64,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'BRIGHTNESS',
            style: TextStyle(
              color: SHColors.mutedText,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        FigmaSlider(
          value: brightness,
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: onBrightnessChanged,
        ),
        const SizedBox(height: 4),
        Text(
          '${brightness.round()}%',
          style: const TextStyle(
            color: SHColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
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
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(SHColors.radiusMd),
                  border: Border.all(
                    color: active
                        ? SHColors.primary
                        : Colors.white.withValues(alpha: 0.12),
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
