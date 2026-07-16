// lib/features/home/presentation/screens/lounge_screen.dart
// ignore_for_file: unused_local_variable, unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/core.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';

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
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Loads',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 50,
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
                            ? SHColors.primary
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isSelected
                              ? SHColors.primary
                              : Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            Expanded(child: _buildLoadsGrid(devicesToShow)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadsGrid(List<Map<String, dynamic>> allDevices) {
    List<Map<String, dynamic>> filteredLoads = allDevices;

    if (_selectedCategory != 'All') {
      filteredLoads = allDevices.where((load) {
        final type = _getDeviceType(load['type'] ?? 'swt');
        return type == _selectedCategory;
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
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
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
    final isOn = load['isOn'] ?? false;
    final deviceName = load['name'] ?? 'Device';
    final deviceType = _getDeviceType(load['type'] ?? 'swt');
    final loadId = load['id']?.toString() ?? '';
    final color = _getLoadColor(deviceType);

    return GestureDetector(
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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isOn
                ? [color.withOpacity(0.3), color.withOpacity(0.1)]
                : [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.03),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOn
                ? color.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon - Fixed size
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _getLoadIcon(
                    deviceType,
                    isOn ? color : Colors.white54,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Name - Fixed text size
              Text(
                deviceName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Type - Fixed text size
              Text(
                deviceType,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const SizedBox(height: 6),

              // ON/OFF Switch
              Switch(
                value: isOn,
                onChanged: (value) {
                  _sendCommand(load['id'], value ? 'ON' : 'OFF');
                },
                activeColor: color,
                inactiveThumbColor: Colors.grey,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),

              // Quick Control Preview - Only shown when ON
              if (isOn &&
                  (deviceType == 'Dimmer' ||
                      deviceType == 'Tunable' ||
                      deviceType == 'Curtain'))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              deviceType == 'Tunable'
                                  ? 'Tunning'
                                  : deviceType == 'Dimmer'
                                  ? 'Brightness'
                                  : 'Movement',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              deviceType == 'Tunable'
                                  ? '${_convertToKelvin(load['cTp'] ?? 166).toInt()}K'
                                  : deviceType == 'Dimmer'
                                  ? '${(load['brightness'] ?? 0).toInt()}%'
                                  : '${(load['cPs'] ?? load['pos'] ?? 0).toInt()}%',
                              style: const TextStyle(
                                color: SHColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showControlBottomSheet(Map<String, dynamic> load, String deviceType) {
    final deviceName = load['name'] ?? 'Device';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  deviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  deviceType,
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 30),

                if (deviceType == 'RGB') _buildRGBBottomSheet(load, setState),
                if (deviceType == 'Dimmer')
                  _buildDimmerBottomSheet(load, setState),
                if (deviceType == 'Fan') _buildFanBottomSheet(load, setState),
                if (deviceType == 'Curtain')
                  _buildCurtainBottomSheet(load, setState),
                if (deviceType == 'HVAC') _buildHVACBottomSheet(load, setState),
                if (deviceType == 'Tunable')
                  _buildTunableBottomSheet(load, setState),

                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$deviceName settings saved'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: SHColors.primary,
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
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  // RGB Bottom Sheet
  Widget _buildRGBBottomSheet(Map<String, dynamic> load, StateSetter setState) {
    double red = (load['red'] ?? 255).toDouble();
    double green = (load['green'] ?? 255).toDouble();
    double blue = (load['blue'] ?? 255).toDouble();

    return Column(
      children: [
        const Text(
          'RGB',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),

        Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color.fromRGBO(red.toInt(), green.toInt(), blue.toInt(), 1),
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        const SizedBox(height: 20),

        _buildColorSlider('R', red, Colors.red, (value) {
          setState(() => red = value);
          _sendRGBCommand(
            load['id'],
            value.toInt(),
            green.toInt(),
            blue.toInt(),
          );
        }),
        const SizedBox(height: 8),
        _buildColorSlider('G', green, Colors.green, (value) {
          setState(() => green = value);
          _sendRGBCommand(load['id'], red.toInt(), value.toInt(), blue.toInt());
        }),
        const SizedBox(height: 8),
        _buildColorSlider('B', blue, Colors.blue, (value) {
          setState(() => blue = value);
          _sendRGBCommand(
            load['id'],
            red.toInt(),
            green.toInt(),
            value.toInt(),
          );
        }),
      ],
    );
  }

  Widget _buildColorSlider(
    String label,
    double value,
    Color color,
    Function(double) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            divisions: 255,
            onChanged: onChanged,
            activeColor: color,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${value.toInt()}',
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  // Dimmer Bottom Sheet
  Widget _buildDimmerBottomSheet(
    Map<String, dynamic> load,
    StateSetter setState,
  ) {
    double brightness = (load['brightness'] ?? 0).toDouble();

    return Column(
      children: [
        const Text(
          'BRIGHTNESS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${brightness.toInt()}%',
            style: const TextStyle(
              color: SHColors.primary,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Slider(
          value: brightness,
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: (value) {
            setState(() => brightness = value);
            _sendBrightnessCommand(load['id'], value.toInt());
          },
          activeColor: SHColors.primary,
        ),
      ],
    );
  }

  // Fan Bottom Sheet
  Widget _buildFanBottomSheet(Map<String, dynamic> load, StateSetter setState) {
    double speed = (load['fanSpeed'] ?? load['fSp'] ?? 0).toDouble();
    double speedPercent = (speed / 250 * 100);

    return Column(
      children: [
        const Text(
          'FAN SPEED',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${speedPercent.round()}%',
            style: const TextStyle(
              color: SHColors.primary,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Slider(
          value: speed,
          min: 0,
          max: 250,
          divisions: 10,
          onChanged: (value) {
            setState(() => speed = value);
            _sendFanSpeedCommand(load['id'], value.toInt());
          },
          activeColor: SHColors.primary,
        ),
      ],
    );
  }

  // Curtain Bottom Sheet
  Widget _buildCurtainBottomSheet(
    Map<String, dynamic> load,
    StateSetter setState,
  ) {
    double position = (load['cPs'] ?? load['pos'] ?? 0).toDouble();

    return Column(
      children: [
        const Text(
          'CURTAIN MOVEMENT',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCurtainButtonSheet('Open', 0, position.toInt(), (value) {
              setState(() => position = value.toDouble());
              _sendCurtainCommand(load['id'], value);
            }),
            _buildCurtainButtonSheet('Stop', -1, position.toInt(), (value) {
              _sendCurtainCommand(load['id'], value);
            }),
            _buildCurtainButtonSheet('Close', 100, position.toInt(), (value) {
              setState(() => position = value.toDouble());
              _sendCurtainCommand(load['id'], value);
            }),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            position.toInt() == 0
                ? 'Fully Open'
                : position.toInt() == 100
                ? 'Fully Closed'
                : '${position.toInt()}%',
            style: const TextStyle(
              color: SHColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Slider(
          value: position,
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: (value) {
            setState(() => position = value);
            _sendCurtainCommand(load['id'], value.toInt());
          },
          activeColor: SHColors.primary,
        ),
      ],
    );
  }

  // HVAC Bottom Sheet
  Widget _buildHVACBottomSheet(
    Map<String, dynamic> load,
    StateSetter setState,
  ) {
    double temperature = (load['temp'] ?? 25).toDouble();
    String mode = load['hvacMode'] ?? 'Cool';
    List<String> modes = ['Cool', 'Heat', 'Auto', 'Dry'];

    return Column(
      children: [
        const Text(
          'ROOM TEMPERATURE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${temperature.toInt()} °C',
          style: const TextStyle(
            color: SHColors.primary,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: modes.map((m) {
            final isSelected = mode == m;
            return GestureDetector(
              onTap: () {
                setState(() => mode = m);
                _sendHVACModeCommand(load['id'], m);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SHColors.primary
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  m,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'TEMPERATURE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '${temperature.toInt()}°C',
            style: const TextStyle(
              color: SHColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Slider(
          value: temperature,
          min: 16,
          max: 32,
          divisions: 16,
          onChanged: (value) {
            setState(() => temperature = value);
            _sendTemperatureCommand(load['id'], value.toInt());
          },
          activeColor: SHColors.primary,
        ),
      ],
    );
  }

  // Tunable Bottom Sheet
  Widget _buildTunableBottomSheet(
    Map<String, dynamic> load,
    StateSetter setState,
  ) {
    double colorTempKelvin = _convertToKelvin(load['cTp'] ?? 166).toDouble();

    return Column(
      children: [
        const Text(
          'TUNNING',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${colorTempKelvin.toInt()}K',
            style: const TextStyle(
              color: SHColors.primary,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            const Text('Warm', style: TextStyle(color: Colors.white54)),
            Expanded(
              child: Slider(
                value: colorTempKelvin,
                min: 2700,
                max: 6500,
                divisions: 100,
                onChanged: (value) {
                  setState(() => colorTempKelvin = value);
                  int convertedBack = _convertFromKelvin(value.toInt());
                  _sendColorTempCommand(load['id'], convertedBack);
                },
                activeColor: SHColors.primary,
              ),
            ),
            const Text('Cool', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ],
    );
  }

  Widget _buildCurtainButtonSheet(
    String label,
    int targetPos,
    int currentPos,
    Function(int) onTap,
  ) {
    final isActive = targetPos != -1 && currentPos == targetPos;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(targetPos),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? SHColors.primary : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _convertToKelvin(int rawValue) {
    return 2700 + ((rawValue / 255) * (6500 - 2700));
  }

  int _convertFromKelvin(int kelvin) {
    return ((kelvin - 2700) / (6500 - 2700) * 255).round().clamp(0, 255);
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
