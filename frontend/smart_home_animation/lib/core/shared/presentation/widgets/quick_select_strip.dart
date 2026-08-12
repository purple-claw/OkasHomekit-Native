// lib/core/shared/presentation/widgets/quick_select_strip.dart
//
// "Quick Select" strip — pinned loads for a room (or the global Loads
// tab) shown as compact shortcuts at the bottom of the screen.
//
// Layout:
//   - elevated section with bottom padding (floats above the grid)
//   - header row: "Quick Select" title + "n/4" counter
//   - a fixed-height Row of 4 equal-width tiles that replicate the
//     load-card design (frosted glass, icon, name, type label, power
//     pill) at a reduced size
//   - empty tile = green plus icon (add a load via long-press in the grid)
//   - tap a tile -> opens that load's existing control sheet (shortcut)
//   - long-press a tile -> remove from Quick Select
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/theme/sh_colors.dart';
import 'package:smart_home_animation/features/home/presentation/widgets/load_icon.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/quick_select_service.dart';

class QuickSelectStrip extends StatelessWidget {
  const QuickSelectStrip({
    super.key,
    required this.loads,
    this.onTapLoad,
    this.onLongPressLoad,
    this.title = 'Quick Select',
  });

  final List<QuickSelectLoad> loads;
  final ValueChanged<QuickSelectLoad>? onTapLoad;
  final ValueChanged<QuickSelectLoad>? onLongPressLoad;
  final String title;

  @override
  Widget build(BuildContext context) {
    final items = loads.take(4).toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${items.length}/4',
                  style: const TextStyle(
                    color: SHColors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: Row(
                children: List.generate(4, (index) {
                  final load = index < items.length ? items[index] : null;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 3 ? 0 : 8),
                      child: _QuickSelectTile(
                        load: load,
                        onTap: load == null
                            ? null
                            : () => onTapLoad?.call(load),
                        onLongPress: load == null
                            ? null
                            : () => onLongPressLoad?.call(load),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSelectTile extends StatelessWidget {
  const _QuickSelectTile({
    required this.load,
    this.onTap,
    this.onLongPress,
  });

  final QuickSelectLoad? load;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        key: ValueKey(load?.id ?? 'empty'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: _GlassTile(
          load: load,
          child: load == null
              ? const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: SHColors.green,
                    size: 30,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Quick Select tile built from the same glass layers as [LoadGridCard]
/// (rim, inner fill, bottom-right shading, top-left specular bloom,
/// ON-state radial glow, icon + name + type label + power pill) at a
/// reduced scale. The live ON state resolves straight from the MQTT
/// service so the tile always mirrors the load card state.
class _GlassTile extends StatelessWidget {
  const _GlassTile({required this.load, this.child});

  final QuickSelectLoad? load;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Selector<DirectMQTTService, bool>(
      selector: (_, mqtt) => load == null
          ? false
          : (mqtt.loads[load!.id]?['isOn'] == true),
      builder: (_, isOn, __) {
        final accent = load?.color ?? SHColors.green;
        final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter.grouped(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOn
                          ? accent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.13),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(1.1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.018),
                    borderRadius: BorderRadius.circular(16 - 1.1),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: const Alignment(-0.9, -1.1),
                          end: const Alignment(0.85, 0.65),
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.025),
                            Colors.black.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: RadialGradient(
                          center: const Alignment(-0.85, -1.05),
                          radius: 1.25,
                          colors: [
                            Colors.white.withValues(alpha: 0.055),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: isOn ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: RadialGradient(
                            center: const Alignment(0, 0),
                            radius: 1.1,
                            colors: [
                              accent.withValues(alpha: 0.25),
                              accent.withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (child != null)
                  child!
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 34,
                          child: Center(
                            child: LoadIcon(
                              type: load!.type,
                              isOn: isOn,
                              color: accent,
                              size: 28,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          load!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _typeLabel(load!.type),
                          style: const TextStyle(
                            color: SHColors.mutedText,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 7),
                        GestureDetector(
                          onTap: () => mqtt.sendCommand(
                            load!.id,
                            isOn ? 'OFF' : 'ON',
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isOn
                                  ? accent.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: isOn
                                    ? accent.withValues(alpha: 0.42)
                                    : Colors.white.withValues(alpha: 0.14),
                              ),
                              boxShadow: isOn
                                  ? [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.20),
                                        blurRadius: 12,
                                        spreadRadius: -3,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.power_settings_new,
                              color: isOn
                                  ? Colors.white
                                  : SHColors.hintColor,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'swt':
        return 'LIGHT';
      case 'dim':
        return 'DIMMING';
      case 'rgb':
        return 'RGB';
      case 'tun':
        return 'TUNABLE';
      case 'hvc':
        return 'HVAC';
      case 'fan':
        return 'FAN';
      case 'cur':
        return 'CURTAIN';
      case 'scn':
        return 'SCENE';
      default:
        return 'LOAD';
    }
  }
}
