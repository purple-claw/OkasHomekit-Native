// lib/features/home/presentation/widgets/load_grid_card.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/core.dart';

/// Figma-style load card used on the Loads screen and the per-room
/// RoomLoadsScreen. The glass surface is IDENTICAL for every load and
/// every state — dark frosted glass, faint neutral rim, no shadows, no
/// colored fill, no halo. The ON state is carried by accent details
/// only (rim tint, icon, dot, name, power pill), so no load can ever
/// break the glassmorphism.
/// Rows: icon+dot, highlighted load name, load type label, power button.
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
      // RepaintBoundary: each card repaints on its own, so scrolling and
      // toggles don't repaint the whole grid (big scroll-lag win).
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SHColors.radiusLg),
          child: BackdropFilter(
            // Frosted glass: a light blur softens the backdrop. Kept at
            // sigma 6 — enough for the glass look, cheap enough to scroll.
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Stack(
              children: [
                // Glass rim: faint neutral outline, slightly brighter on
                // top, accent-tinted at the bottom when the load is ON.
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SHColors.radiusLg),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.16),
                        Colors.white.withOpacity(0.05),
                        color.withOpacity(isOn ? 0.22 : 0.10),
                      ],
                    ),
                  ),
                ),
                // Inner glass fill — a whisper of frost only, the same for
                // every card. The glass never changes with state.
                Container(
                  margin: const EdgeInsets.all(1.2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(
                      SHColors.radiusLg - 1.2,
                    ),
                  ),
                ),
                // Glass shading: the surface darkens toward the bottom-right
                // — a grey-black gradient giving the glass weight and depth.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SHColors.radiusLg),
                        gradient: LinearGradient(
                          begin: const Alignment(-0.9, -1.1),
                          end: const Alignment(0.85, 0.65),
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.05),
                            Colors.black.withOpacity(0.12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ON-state inner glow: a soft radial bloom that swells from
                // the center toward the card edges, fading to nothing at the
                // rim — fully contained inside the card, never overflowing.
                // Fades in progressively on toggle (one-shot, no breathing).
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: isOn ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            SHColors.radiusLg,
                          ),
                          gradient: RadialGradient(
                            center: const Alignment(0, 0),
                            radius: 1.1,
                            colors: [
                              color.withOpacity(0.16),
                              color.withOpacity(0.08),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
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
                              color: color.withOpacity(isOn ? 0.09 : 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: color.withOpacity(isOn ? 0.4 : 0.16),
                              ),
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
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Row 2: load name — highlighted.
                      Text(
                        deviceName,
                        style: TextStyle(
                          color: isOn ? color : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Row 3: load type label.
                      Text(
                        _typeLabel(deviceType),
                        style: const TextStyle(
                          color: SHColors.mutedText,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
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
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isOn
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.14),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'Switch':
        return 'LIGHT';
      case 'Dimmer':
        return 'DIMMING';
      case 'Tunable':
        return 'TUNABLE';
      case 'RGB':
        return 'RGB';
      case 'HVAC':
        return 'HVAC';
      case 'Fan':
        return 'FAN';
      case 'Curtain':
        return 'CURTAIN';
      case 'Scene':
        return 'SCENE';
      default:
        return 'LIGHT';
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
