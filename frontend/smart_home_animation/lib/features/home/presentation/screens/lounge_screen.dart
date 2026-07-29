// lib/features/home/presentation/screens/lounge_screen.dart
// ignore_for_file: unused_local_variable, unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import '../widgets/figma_load_sheets.dart';
import '../widgets/load_grid_card.dart';

class LoungeScreen extends StatefulWidget {
  const LoungeScreen({super.key});

  @override
  State<LoungeScreen> createState() => _LoungeScreenState();
}

class _LoungeScreenState extends State<LoungeScreen> {
  String _selectedCategory = 'All';
  Map<String, dynamic>? _selectedLoad;
  String? _expandedLoadId;

  final List<String> _categories = [
    'All',
    'Lights',
    'Dimmers',
    'Tunable',
    'RGB',
    'HVAC',
    'Scene',
    'Fan',
    'Curtain',
  ];

  /// Maps display-friendly category names to the internal type codes
  /// used by _getDeviceType / load['type'].
  static const Map<String, List<String>> _categoryTypeCodes = {
    'All': <String>[],
    'Lights': ['swt'],
    'Dimmers': ['dim'],
    'Tunable': ['tun'],
    'RGB': ['rgb'],
    'HVAC': ['hvc'],
    'Scene': ['scn'],
    'Fan': ['fan'],
    'Curtain': ['cur'],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final okasService = Provider.of<DirectMQTTService>(
        context,
        listen: false,
      );
      okasService.addListener(_onDataChanged);
    });
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _refreshLoads() {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.refreshLoads();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final okasService = Provider.of<DirectMQTTService>(context);

    if (!okasService.isConnected) {
      return Container(
        decoration: const BoxDecoration(gradient: SHColors.backgroundColor),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Connecting to OKAS device...'),
              SizedBox(height: 8),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    final allDevices = okasService.devices.values.toList();
    final allLoads = okasService.loads.values.toList();

    print('Devices from service: ${allDevices.length}');
    print('Loads from service: ${allLoads.length}');

    final devicesToShow = allDevices.isNotEmpty ? allDevices : allLoads;

    return Container(
      decoration: const BoxDecoration(gradient: SHColors.backgroundColor),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            SizedBox(
              height: 46,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? SHColors.primary.withOpacity(0.95)
                            : SHColors.cardColor.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isSelected
                              ? SHColors.primary
                              : Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            Expanded(child: _buildLoadsGrid(devicesToShow)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadsGrid(List<Map<String, dynamic>> allDevices) {
    List<Map<String, dynamic>> filteredLoads = allDevices;

    if (_selectedCategory != 'All') {
      final matchingCodes = _categoryTypeCodes[_selectedCategory] ?? <String>[];
      filteredLoads = allDevices.where((load) {
        return matchingCodes.contains(load['type'] ?? 'swt');
      }).toList();
    }

    if (filteredLoads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No loads found', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              'Total devices: ${allDevices.length}',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filteredLoads.length,
      itemBuilder: (context, index) {
        final load = filteredLoads[index];
        return _buildLoadCard(load);
      },
    );
  }

  Widget _buildLoadCard(Map<String, dynamic> load) {
    final loadId = load['id']?.toString() ?? '';
    final deviceType = _getDeviceType(load['type'] ?? 'swt');

    return LoadGridCard(
      load: load,
      onTap: () {
        if (deviceType == 'Dimmer' ||
            deviceType == 'Tunable' ||
            deviceType == 'Curtain' ||
            deviceType == 'RGB' ||
            deviceType == 'Fan' ||
            deviceType == 'HVAC') {
          _showControlBottomSheet(load, deviceType);
        }
      },
      onToggle: (value) {
        _sendCommand(load['id'], value ? 'ON' : 'OFF');
      },
    );
  }

  void _showControlBottomSheet(Map<String, dynamic> load, String deviceType) {
    final deviceName = load['name'] ?? 'Device';
    final typeCode = _getDeviceTypeCode(deviceType);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildLoadSheet(ctx, load, deviceName, typeCode),
    );
  }

  Widget _buildLoadSheet(
    BuildContext ctx,
    Map<String, dynamic> load,
    String deviceName,
    String typeCode,
  ) {
    final mqtt = Provider.of<DirectMQTTService>(ctx, listen: false);
    final id = load['id']?.toString() ?? '';

    switch (typeCode) {
      case 'dim':
        return _buildDimmerSheet(ctx, mqtt, id, deviceName);
      case 'tun':
        return _buildTunableSheet(ctx, mqtt, id, deviceName);
      case 'rgb':
        return _buildRGBSheet(ctx, mqtt, id, deviceName);
      case 'fan':
        return _buildFanSheet(ctx, mqtt, id, deviceName);
      case 'cur':
        return _buildCurtainSheet(ctx, mqtt, id, deviceName);
      case 'hvc':
        return _buildHVACSheet(ctx, mqtt, id, deviceName);
      default:
        return _buildDimmerSheet(ctx, mqtt, id, deviceName);
    }
  }

  Widget _buildDimmerSheet(
    BuildContext ctx,
    DirectMQTTService mqtt,
    String id,
    String deviceName,
  ) {
    // The dimmer's "on" state is derived from brightness > 0 so the slider
    // position and the master toggle stay in lock-step.
    final liveLoad = mqtt.loads[id] ?? <String, dynamic>{};
    double liveBrightness =
        ((liveLoad['brightness'] ?? 50) as num).toDouble();
    if (liveBrightness <= 0 && (liveLoad['isOn'] ?? false) == true) {
      liveBrightness = 50; // avoid a blank slider when on but no value yet
    }
    final liveIsOn = liveBrightness > 0;

    return StatefulBuilder(
      builder: (ctx, setSt) {
        final cur = mqtt.loads[id] ?? <String, dynamic>{};
        final curBrightness = ((cur['brightness'] ?? 0) as num).toDouble();
        final curIsOn = curBrightness > 0 || (cur['isOn'] == true && curBrightness > 0);
        final sliderPct = curBrightness > 0
            ? curBrightness.clamp(0, 100).toDouble()
            : liveBrightness.clamp(0, 100).toDouble();
        return FigmaLoadSheet(
          title: 'BRIGHTNESS',
          isOn: curIsOn,
          onToggle: (v) {
            mqtt.sendCommand(id, v ? 'ON' : 'OFF');
            setSt(() {});
          },
          body: BrightnessSlider(
            value: sliderPct,
            label: curIsOn ? 'BRIGHTNESS' : 'TAP OR SLIDE TO TURN ON',
            onChanged: (v) {
              mqtt.sendBrightnessCommand(id, v.round());
              setSt(() {});
            },
          ),
        );
      },
    );
  }

  Widget _buildTunableSheet(
    BuildContext ctx,
    DirectMQTTService mqtt,
    String id,
    String deviceName,
  ) {
    // Board publishes cTp as Mired (1_000_000 / Kelvin) on Tuv feedback.
    // Convert to Kelvin for the UI; clamp to the supported range.
    final rawCtpDynamic = mqtt.loads[id]?['cTp'];
    final int rawCtp = rawCtpDynamic is int
        ? rawCtpDynamic
        : int.tryParse('$rawCtpDynamic') ?? 370;
    final int mired = rawCtp < 154
        ? 154
        : rawCtp > 500
            ? 500
            : rawCtp;
    double kelvin = (1000000 / mired).clamp(2700, 6500).toDouble();

    return StatefulBuilder(
      builder: (ctx, setSt) => FigmaLoadSheet(
        title: 'TUNING',
        isOn: mqtt.loads[id]?['isOn'] ?? false,
        onToggle: (v) {
          mqtt.sendCommand(id, v ? 'ON' : 'OFF');
          setSt(() {});
        },
        body: Column(
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
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFB84D),
                    Color(0xFFFFE7B5),
                    Color(0xFFE8F6F8),
                    Color(0xFFAFD6FF),
                    Color(0xFFAF7DFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(SHColors.radiusMd),
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
                // The board's Tun action expects Kelvin directly (it
                // converts to Mired internally for the bus write).
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
        ),
      ),
    );
  }

  Widget _buildRGBSheet(
    BuildContext ctx,
    DirectMQTTService mqtt,
    String id,
    String deviceName,
  ) {
    final cur = mqtt.loads[id] ?? {};
    int r = ((cur['red'] ?? 255) as num).round().clamp(0, 255);
    int g = ((cur['green'] ?? 255) as num).round().clamp(0, 255);
    int b = ((cur['blue'] ?? 255) as num).round().clamp(0, 255);

    return StatefulBuilder(
      builder: (ctx, setSt) => FigmaLoadSheet(
        title: 'COLOR',
        isOn: mqtt.loads[id]?['isOn'] ?? false,
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
    );
  }

  Widget _buildFanSheet(
    BuildContext ctx,
    DirectMQTTService mqtt,
    String id,
    String deviceName,
  ) {
    // Fan on/off is derived from the speed (0 = off, >0 = on) so the slider
    // position stays in lock-step with the master toggle.
    double rawSpeed =
        ((mqtt.loads[id]?['fanSpeed'] ?? mqtt.loads[id]?['fSp'] ?? 0) as num)
            .toDouble();
    if (rawSpeed <= 0 && (mqtt.loads[id]?['isOn'] ?? false) == true) {
      rawSpeed = 50; // avoid a blank slider when the relay is on but speed is unknown
    }

    return StatefulBuilder(
      builder: (ctx, setSt) {
        final liveLoad = mqtt.loads[id] ?? <String, dynamic>{};
        final liveSpeed =
            ((liveLoad['fanSpeed'] ?? liveLoad['fSp'] ?? 0) as num)
                .toDouble();
        final liveIsOn = liveSpeed > 0;
        final sliderPct =
            (liveSpeed > 0 ? liveSpeed : rawSpeed) / 250 * 100;
        return FigmaLoadSheet(
          title: 'FAN SPEED',
          isOn: liveIsOn,
          onToggle: (v) {
            // Toggling the master switch flips the bus relay; sendFanSpeedCommand
            // already pairs speed changes with swt so the slider remains the
            // source of truth for "on".
            mqtt.sendCommand(id, v ? 'ON' : 'OFF');
            setSt(() {});
          },
          body: BrightnessSlider(
            value: sliderPct.clamp(0, 100).toDouble(),
            label: liveIsOn ? 'SPEED' : 'TAP OR SLIDE TO TURN ON',
            onChanged: (v) {
              final newSpeed = v * 2.5;
              mqtt.sendFanSpeedCommand(
                id,
                newSpeed.round().clamp(0, 250),
              );
              setSt(() {});
            },
          ),
        );
      },
    );
  }

  Widget _buildCurtainSheet(
    BuildContext ctx,
    DirectMQTTService mqtt,
    String id,
    String deviceName,
  ) {
    double pos =
        ((mqtt.loads[id]?['tPs'] ?? mqtt.loads[id]?['cPs'] ?? 0) as num)
            .toDouble();

    return StatefulBuilder(
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
    );
  }

  Widget _buildHVACSheet(
    BuildContext ctx,
    DirectMQTTService mqtt,
    String id,
    String deviceName,
  ) {
    final cur = mqtt.loads[id] ?? {};
    double temp = ((cur['temp'] ?? 25) as num).toDouble();
    String mode = (cur['hvacMode'] ?? 'Cool').toString();
    const modes = ['Cool', 'Heat', 'Auto', 'Dry'];

    return StatefulBuilder(
      builder: (ctx, setSt) => FigmaLoadSheet(
        title: 'TEMPERATURE',
        isOn: cur['isOn'] ?? false,
        onToggle: (v) {
          mqtt.sendCommand(id, v ? 'ON' : 'OFF');
          setSt(() {});
        },
        body: Column(
          children: [
            Text(
              '${temp.round()}°C',
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
              selected: mode,
              labelBuilder: (m) => m.toUpperCase(),
              onSelected: (m) {
                mode = m;
                mqtt.sendHVACModeCommand(id, m);
                setSt(() {});
              },
            ),
            const SizedBox(height: 20),
            FigmaSlider(
              value: temp.clamp(16, 32),
              min: 16,
              max: 32,
              divisions: 32,
              onChanged: (v) {
                temp = v;
                mqtt.sendTemperatureCommand(id, v.round());
                setSt(() {});
              },
            ),
          ],
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

  String _getDeviceTypeCode(String deviceType) {
    switch (deviceType) {
      case 'Dimmer':
        return 'dim';
      case 'Tunable':
        return 'tun';
      case 'RGB':
        return 'rgb';
      case 'HVAC':
        return 'hvc';
      case 'Fan':
        return 'fan';
      case 'Curtain':
        return 'cur';
      default:
        return 'swt';
    }
  }

  // Command sending methods
  void _sendCommand(String deviceId, String command) {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.sendCommand(deviceId, command);
    setState(() {});
  }

  void _sendBrightnessCommand(String deviceId, int brightness) {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.sendBrightnessCommand(deviceId, brightness);
    setState(() {});
  }

  void _sendColorTempCommand(String deviceId, int colorTemp) {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.sendColorTempCommand(deviceId, colorTemp);
    setState(() {});
  }

  void _sendRGBCommand(String deviceId, int r, int g, int b) {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.sendRGBCommand(deviceId, r, g, b);
    setState(() {});
  }

  void _sendHVACModeCommand(String deviceId, String mode) {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.sendHVACModeCommand(deviceId, mode);
    setState(() {});
  }

  void _sendTemperatureCommand(String deviceId, int temperature) {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.sendTemperatureCommand(deviceId, temperature);
    setState(() {});
  }

  void _sendFanSpeedCommand(String deviceId, int speed) {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.sendFanSpeedCommand(deviceId, speed);
    setState(() {});
  }

  void _sendCurtainCommand(String deviceId, int position) {
    final okasService = Provider.of<DirectMQTTService>(context, listen: false);
    okasService.sendCurtainPositionCommand(deviceId, position);
    setState(() {});
  }

  String _getDeviceType(String type) {
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

  // Get load icon as Widget with fixed size
  Widget _getLoadIcon(String type, Color color) {
    switch (type) {
      case 'Switch':
        return _buildIcon('assets/icons/switch.png', 28, color: color);
      case 'Dimmer':
        return _buildIcon('assets/icons/dimmer.png', 28, color: color);
      case 'Tunable':
        return _buildIcon('assets/icons/tunable.png', 28, color: color);
      case 'RGB':
        return _buildIcon('assets/icons/rgb.png', 28, color: color);
      case 'HVAC':
        return _buildIcon('assets/icons/hvac.png', 28, color: color);
      case 'Scene':
        return _buildIcon('assets/icons/scene.png', 28, color: color);
      case 'Fan':
        return _buildIcon('assets/icons/fan.png', 28, color: color);
      case 'Curtain':
        return _buildIcon('assets/icons/curtain.png', 28, color: color);
      default:
        return _buildIcon('assets/icons/light.png', 28, color: color);
    }
  }

  Color _getLoadColor(String type) {
    return SHColors.deviceAccent(type);
  }

  // For PNG/JPG images - Fixed size
  Widget _buildIcon(String path, double size, {Color? color}) {
    return Image.asset(
      path,
      width: size,
      height: size,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.image_not_supported,
          color: Colors.white54,
          size: size,
        );
      },
    );
  }

  // For SVG images (if using flutter_svg)
  Widget _buildSvgIcon(String path, double size, {Color? color}) {
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color, BlendMode.srcIn)
          : null,
    );
  }
}
