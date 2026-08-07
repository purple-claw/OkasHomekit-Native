import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/liquid_glass_scrim.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/room_service.dart';
import 'package:smart_home_animation/services/token_auth_service.dart';
import '../widgets/load_grid_card.dart';
import '../widgets/figma_load_sheets.dart';
import 'add_room_screen.dart';

class RoomLoadsScreen extends StatefulWidget {
  const RoomLoadsScreen({required this.room, super.key});
  final Room room;

  @override
  State<RoomLoadsScreen> createState() => _RoomLoadsScreenState();
}

class _RoomLoadsScreenState extends State<RoomLoadsScreen> {
  String _selectedCategory = 'All';
  String _loadStructureSignature = '';

  // "Lights" combines every lighting type (on/off switches, dimmers,
  // tunable whites, RGB) into one section with All ON/OFF controls.
  static const _categories = [
    'All',
    'Lights',
    'Dimmers',
    'Tunable',
    'RGB',
    'Fans',
    'Curtains',
    'Scenes',
  ];
  static const _categoryTypeCodes = {
    'All': <String>[],
    'Lights': ['swt', 'dim', 'tun', 'rgb'],
    'Dimmers': ['dim'],
    'Tunable': ['tun'],
    'RGB': ['rgb'],
    'Fans': ['fan'],
    'Curtains': ['cur'],
    'Scenes': ['scn'],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
      _loadStructureSignature = _structureSignature(mqtt);
      mqtt.addListener(_onDataChanged);
    });
  }

  void _onDataChanged() {
    if (!mounted) return;
    final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
    final nextSignature = _structureSignature(mqtt);
    if (nextSignature == _loadStructureSignature) return;
    _loadStructureSignature = nextSignature;
    setState(() {});
  }

  String _structureSignature(DirectMQTTService mqtt) {
    return widget.room.loadIds
        .map((id) {
          final load = mqtt.loads[id];
          return '$id:${load?['type']}:${load?['name']}';
        })
        .join('|');
  }

  @override
  void dispose() {
    final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
    mqtt.removeListener(_onDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
    final allLoads = mqtt.loads.values.toList();
    final roomLoadIds = widget.room.loadIds;
    final roomLoads = allLoads
        .where((l) => roomLoadIds.contains(l['id']?.toString()))
        .toList();

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.room.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          actions: [
            if (context.watch<TokenAuthService>().isAdmin)
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () => _showRoomEditMenu(context),
              ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final sel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? SHColors.primary.withOpacity(0.95)
                              : SHColors.cardColor.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? SHColors.primary
                                : Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.white70,
                              fontWeight: sel
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                children: [
                  // All ON / All OFF control — shown for the combined
                  // Lights section based on the room's lighting config.
                  if (_selectedCategory == 'Lights')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _buildAllLightsBar(roomLoads),
                    ),
                  Expanded(child: BackdropGroup(child: _buildGrid(roomLoads))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Combined "All Lights" control: turns every lighting load in the room
  /// on or off with one tap. Buttons only appear when the room actually
  /// has lighting loads.
  Widget _buildAllLightsBar(List<Map<String, dynamic>> roomLoads) {
    final lightLoads = roomLoads
        .where((l) => const ['swt', 'dim', 'tun', 'rgb'].contains(l['type']))
        .toList();
    if (lightLoads.isEmpty) return const SizedBox.shrink();

    final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
    final allOn = lightLoads.every((l) => l['isOn'] == true);
    final someOn = lightLoads.any((l) => l['isOn'] == true);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              for (final l in lightLoads) {
                mqtt.sendCommand(l['id'].toString(), 'ON');
              }
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: allOn
                    ? SHColors.primary.withOpacity(0.9)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(SHColors.radiusMd),
                border: Border.all(
                  color: allOn
                      ? SHColors.primary
                      : Colors.white.withOpacity(0.14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb,
                    size: 18,
                    color: allOn ? Colors.white : SHColors.mutedText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'All ON',
                    style: TextStyle(
                      color: allOn ? Colors.white : SHColors.mutedText,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              for (final l in lightLoads) {
                mqtt.sendCommand(l['id'].toString(), 'OFF');
              }
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: !someOn
                    ? SHColors.rose.withOpacity(0.9)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(SHColors.radiusMd),
                border: Border.all(
                  color: !someOn
                      ? SHColors.rose
                      : Colors.white.withOpacity(0.14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: !someOn ? Colors.white : SHColors.mutedText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'All OFF',
                    style: TextStyle(
                      color: !someOn ? Colors.white : SHColors.mutedText,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> allLoads) {
    List<Map<String, dynamic>> filtered = allLoads;
    if (_selectedCategory != 'All') {
      final codes = _categoryTypeCodes[_selectedCategory] ?? [];
      filtered = allLoads
          .where((l) => codes.contains(l['type'] ?? 'swt'))
          .toList();
    }
    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'No loads in this room',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      scrollCacheExtent: ScrollCacheExtent.pixels(720),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) => _makeCard(filtered[i]),
    );
  }

  Widget _makeCard(Map<String, dynamic> load) {
    final id = load['id']?.toString() ?? '';
    return Selector<DirectMQTTService, bool>(
      selector: (context, mqtt) => (mqtt.loads[id] ?? load)['isOn'] == true,
      builder: (context, isOn, child) {
        final mqtt = Provider.of<DirectMQTTService>(context, listen: false);
        final cur = Map<String, dynamic>.from(mqtt.loads[id] ?? load)
          ..['isOn'] = isOn;
        return LoadGridCard(
          load: cur,
          onTap: () => _showSheet(context, cur, cur['type'] ?? 'swt'),
          onToggle: (v) => mqtt.sendCommand(id, v ? 'ON' : 'OFF'),
        );
      },
    );
  }

  void _showSheet(BuildContext ctx, Map<String, dynamic> load, String type) {
    if (type == 'dim' || type == 'tun') {
      _showDimSheet(ctx, load, type);
    } else if (type == 'rgb') {
      _showRGBSheet(ctx, load);
    } else if (type == 'fan') {
      _showFanSheet(ctx, load);
    } else if (type == 'cur') {
      _showCurtainSheet(ctx, load);
    } else if (type == 'hvc') {
      _showHVACSheet(ctx, load);
    }
  }

  void _showDimSheet(BuildContext ctx, Map<String, dynamic> load, String type) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    double fallbackBrightness = ((mqtt.loads[id]?['brightness'] ?? 50) as num)
        .toDouble();
    if (fallbackBrightness <= 0 && (mqtt.loads[id]?['isOn'] ?? false) == true) {
      fallbackBrightness = 50;
    }

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final cur = mqtt.loads[id] ?? load;
          final curBrightness = ((cur['brightness'] ?? 0) as num).toDouble();
          final curIsOn =
              curBrightness > 0 || (cur['isOn'] == true && curBrightness > 0);
          final sliderPct = curBrightness > 0
              ? curBrightness.clamp(0, 100).toDouble()
              : fallbackBrightness.clamp(0, 100).toDouble();
          return FigmaLoadSheet(
            title: type == 'tun' ? 'TUNING' : 'BRIGHTNESS',
            isOn: curIsOn,
            onToggle: (v) {
              mqtt.sendCommand(id, v ? 'ON' : 'OFF');
              setSt(() {});
            },
            body: type == 'tun'
                ? _buildTunableBody(ctx, load, setSt)
                : BrightnessSlider(
                    value: sliderPct,
                    label: curIsOn ? 'BRIGHTNESS' : 'TAP OR SLIDE TO TURN ON',
                    onChanged: (v) {
                      mqtt.sendBrightnessCommand(id, v.round());
                      setSt(() {});
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildTunableBody(
    BuildContext ctx,
    Map<String, dynamic> load,
    StateSetter setSt,
  ) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    final mqttLoad = mqtt.loads[id] ?? load;
    // Board publishes cTp as Mired (1_000_000 / Kelvin) on Tuv feedback.
    // Convert back to Kelvin for the slider; clamp to the UI range.
    final rawCtpDynamic = mqttLoad['cTp'];
    final int rawCtp = rawCtpDynamic is int
        ? rawCtpDynamic
        : int.tryParse('$rawCtpDynamic') ?? 370;
    final int mired = rawCtp < 154
        ? 154
        : rawCtp > 500
        ? 500
        : rawCtp;
    double kelvin = (1000000 / mired).clamp(2700, 6500).toDouble();
    final previewColor = _kelvinPreview(kelvin);

    return Column(
      children: [
        Text(
          '${kelvin.round()}K',
          style: const TextStyle(
            color: SHColors.primary,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                Color(0xFFFFB84D),
                Color(0xFFFFE7B5),
                Color(0xFFE8F6F8),
                Color(0xFFAFD6FF),
                Color(0xFFAF7DFF),
              ],
              stops: const [0, 0.28, 0.5, 0.75, 1],
            ),
            borderRadius: BorderRadius.circular(SHColors.radiusMd),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 24,
          decoration: BoxDecoration(
            color: previewColor,
            borderRadius: BorderRadius.circular(SHColors.radiusSm),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
        ),
        const SizedBox(height: 12),
        FigmaSlider(
          value: kelvin,
          min: 2700,
          max: 6500,
          divisions: 100,
          onChanged: (v) {
            kelvin = v;
            // Board expects Kelvin directly (it converts to Mired for the
            // bus write). The previous byte conversion was wrong and the
            // Tun action rejected the value as out-of-range.
            mqtt.sendColorTempCommand(id, v.round());
            setSt(() {});
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Warm',
              style: TextStyle(color: SHColors.mutedText, fontSize: 12),
            ),
            Text(
              'Cool',
              style: TextStyle(color: SHColors.mutedText, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Color _kelvinPreview(double kelvin) {
    final t = ((kelvin - 2700) / (6500 - 2700)).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFFFFB36B), const Color(0xFFB5D6FF), t) ??
        const Color(0xFFFFE7B5);
  }

  void _showRGBSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    final cur = mqtt.loads[id] ?? load;
    int r = ((cur['red'] ?? 255) as num).round().clamp(0, 255);
    int g = ((cur['green'] ?? 255) as num).round().clamp(0, 255);
    int b = ((cur['blue'] ?? 255) as num).round().clamp(0, 255);

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FigmaLoadSheet(
          title: 'COLOR',
          isOn: (mqtt.loads[id]?['isOn'] ?? false),
          onToggle: (v) {
            mqtt.sendCommand(id, v ? 'ON' : 'OFF');
            setSt(() {});
          },
          body: RgbGamutPicker(
            red: r.toDouble(),
            green: g.toDouble(),
            blue: b.toDouble(),
            onChanged: (nr, ng, nb) {
              r = nr;
              g = ng;
              b = nb;
              mqtt.sendRGBCommand(id, nr, ng, nb);
              setSt(() {});
            },
          ),
        ),
      ),
    );
  }

  void _showFanSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    // The fan's "on" state is derived from speed > 0 so the slider position
    // and the master toggle stay perfectly in sync (0% -> OFF, >0% -> ON).
    double rawSpeed =
        ((mqtt.loads[id]?['fanSpeed'] ?? mqtt.loads[id]?['fSp'] ?? 0) as num)
            .toDouble();
    if (rawSpeed <= 0 && (mqtt.loads[id]?['isOn'] ?? false) == true) {
      rawSpeed =
          50; // fallback so a stale ON without a speed still shows a slider
    }

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final liveLoad = mqtt.loads[id] ?? load;
          final liveSpeed =
              ((liveLoad['fanSpeed'] ?? liveLoad['fSp'] ?? 0) as num)
                  .toDouble();
          final liveIsOn =
              (liveSpeed > 0) || (liveLoad['isOn'] == true && liveSpeed > 0);
          final sliderPct = (liveSpeed > 0 ? liveSpeed : rawSpeed) / 250 * 100;
          return FigmaLoadSheet(
            title: 'FAN SPEED',
            isOn: liveIsOn,
            onToggle: (v) {
              // Toggling the master switch drives the bus command but the
              // underlying on/off is mirrored to fSp=0 (off) or fSp=128 (on)
              // so the slider remains the source of truth for the speed.
              mqtt.sendCommand(id, v ? 'ON' : 'OFF');
              setSt(() {});
            },
            body: BrightnessSlider(
              value: sliderPct.clamp(0, 100).toDouble(),
              label: liveIsOn ? 'SPEED' : 'TAP OR SLIDE TO TURN ON',
              onChanged: (v) {
                final newSpeed = v * 2.5;
                mqtt.sendFanSpeedCommand(id, newSpeed.round().clamp(0, 250));
                setSt(() {});
              },
            ),
          );
        },
      ),
    );
  }

  void _showCurtainSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    double pos =
        ((mqtt.loads[id]?['tPs'] ?? mqtt.loads[id]?['cPs'] ?? 0) as num)
            .toDouble();

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => FigmaLoadSheet(
          title: 'MOVEMENT',
          isOn: pos > 0,
          useRadialGradient: true,
          onToggle: (v) {
            pos = v ? 0 : 100;
            mqtt.sendCurtainPositionCommand(id, pos.round());
            setSt(() {});
          },
          body: Column(
            children: [
              CurtainVisualization(position: pos.clamp(0, 100) / 100),
              const SizedBox(height: 14),
              Text(
                pos == 0
                    ? 'Fully Open'
                    : pos == 100
                    ? 'Fully Closed'
                    : '${pos.round()}%',
                style: const TextStyle(
                  color: SHColors.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'CURTAIN MOVEMENT',
                style: TextStyle(
                  color: SHColors.mutedText,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              FigmaSlider(
                value: pos.clamp(0, 100),
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (v) {
                  pos = v;
                  mqtt.sendCurtainPositionCommand(id, v.round());
                  setSt(() {});
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _curtainBtn('Open', 0, pos, (v) {
                    pos = v.toDouble();
                    mqtt.sendCurtainPositionCommand(id, v);
                    setSt(() {});
                  }),
                  _curtainBtn('Stop', -1, pos, (v) {
                    mqtt.sendCurtainPositionCommand(id, 50);
                    setSt(() {});
                  }),
                  _curtainBtn('Close', 100, pos, (v) {
                    pos = v.toDouble();
                    mqtt.sendCurtainPositionCommand(id, v);
                    setSt(() {});
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _curtainBtn(
    String label,
    int target,
    double cur,
    ValueChanged<int> onTap,
  ) {
    final active = target != -1 && cur == target;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(target),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? SHColors.primary : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(SHColors.radiusMd),
            border: Border.all(
              color: active ? SHColors.primary : Colors.white.withOpacity(0.16),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : SHColors.mutedText,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHVACSheet(BuildContext ctx, Map<String, dynamic> load) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';
    final cur = mqtt.loads[id] ?? load;
    double temp = ((cur['temp'] ?? 25) as num).toDouble();
    String mode = (cur['hvacMode'] ?? 'Cool').toString();
    final modes = const ['Cool', 'Heat', 'Auto', 'Dry'];
    // HVAC fan speed range. Defaults match the Figma spec (5 speeds);
    // overloads via Smx / Fst on the load config adapt the slider.
    final double fanMax = ((cur['fanSpeedMax'] ?? cur['Smx'] ?? 5) as num)
        .toDouble()
        .clamp(1, 5)
        .toDouble();
    final double fanStep = ((cur['fanSpeedStep'] ?? cur['Fst'] ?? 1) as num)
        .toDouble()
        .clamp(1, fanMax)
        .toDouble();

    showLiquidGlassModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final live = mqtt.loads[id] ?? cur;
          final liveTemp = ((live['temp'] ?? temp) as num).toDouble();
          final liveMode = (live['hvacMode'] ?? mode).toString();
          final liveFan = ((live['fanSpeed'] ?? live['fSp'] ?? 0) as num)
              .toDouble();
          // Bus fan speed is 0..255; the Figma slider works in
          // 0..fanMax scale so users can pick discrete steps instead of
          // dragging across a 255-step range.
          final fanPct = fanMax > 0
              ? (liveFan * fanMax / 255).clamp(0, fanMax).toDouble()
              : 0.0;
          return FigmaLoadSheet(
            title: 'TEMPERATURE',
            isOn: (live['isOn'] ?? false),
            onToggle: (v) {
              mqtt.sendCommand(id, v ? 'ON' : 'OFF');
              setSt(() {});
            },
            body: Column(
              children: [
                Text(
                  '${liveTemp.round()}°C',
                  style: const TextStyle(
                    color: SHColors.primary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ROOM TEMPERATURE',
                  style: TextStyle(
                    color: SHColors.mutedText,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                FigmaSegmentedOptions<String>(
                  options: modes,
                  selected: liveMode,
                  labelBuilder: (m) => m.toUpperCase(),
                  onSelected: (m) {
                    mqtt.sendHVACModeCommand(id, m);
                    setSt(() {});
                  },
                ),
                const SizedBox(height: 20),
                FigmaSlider(
                  value: liveTemp.clamp(16, 32),
                  min: 16,
                  max: 32,
                  divisions: 32,
                  onChanged: (v) {
                    mqtt.sendTemperatureCommand(id, v.round());
                    setSt(() {});
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  fanPct <= 0 ? 'TAP OR SLIDE TO TURN ON FAN' : 'FAN SPEED',
                  style: const TextStyle(
                    color: SHColors.mutedText,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${fanPct.round()} / ${fanMax.round()}',
                  style: const TextStyle(
                    color: SHColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                FigmaSlider(
                  value: fanPct,
                  min: 0,
                  max: fanMax,
                  divisions: (fanMax / fanStep).round(),
                  onChanged: (v) {
                    // Scale UI step (0..fanMax) to bus speed (0..255).
                    final busSpeed = fanMax > 0
                        ? (v / fanMax * 255).round().clamp(0, 255)
                        : 0;
                    mqtt.sendFanSpeedCommand(id, busSpeed);
                    setSt(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRoomEditMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SHColors.elevatedCardColor,
        title: Text(
          widget.room.name,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text(
                'Edit Room',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddRoomScreen(
                      roomToEdit: {
                        'id': widget.room.id,
                        'name': widget.room.name,
                        'imagePath': widget.room.imagePath,
                        'loads': widget.room.loadIds,
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Room',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteRoom();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRoom() {
    final mqttService = Provider.of<DirectMQTTService>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SHColors.elevatedCardColor,
        title: const Text(
          'Delete Room?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.room.name}"?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              RoomService.instance.deleteRoom(widget.room.id);
              mqttService.deleteRoom(widget.room.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
