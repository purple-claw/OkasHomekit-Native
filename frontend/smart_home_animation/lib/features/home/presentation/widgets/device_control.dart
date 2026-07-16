// lib/widgets/device_control.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/services/mqtt_command_service.dart';

class DeviceControl extends StatefulWidget {
  final Device device;

  const DeviceControl({super.key, required this.device});

  @override
  State<DeviceControl> createState() => _DeviceControlState();
}

class _DeviceControlState extends State<DeviceControl> {
  late Device _device;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
  }

  void _sendCommand(Map<String, dynamic> cmd) async {
    final mqttService = Provider.of<MQTTService>(context, listen: false);
    final loadId = int.parse(_device.id);

    // Use mqttType instead of type
    final mqttTypeString = _device.mqttType.toString().split('.').last;
    await mqttService.sendCommand(loadId, mqttTypeString, cmd);

    // Update local state optimistically
    setState(() {
      if (cmd.containsKey('swt')) {
        _device = _device.copyWith(isOn: cmd['swt'] as bool);
      }
      if (cmd.containsKey('bri')) {
        final briValue = cmd['bri'] as int;
        _device = _device.copyWith(
          brightness: briValue,
          value: briValue.toDouble(),
        );
      }
      if (cmd.containsKey('cTp')) {
        _device = _device.copyWith(colorTemp: cmd['cTp'] as int);
      }
    });
  }

  void _showDetailedControl() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          double localBrightness = (_device.brightness ?? 0).toDouble();
          double localColorTemp = (_device.colorTemp ?? 2700).toDouble();

          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _device.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Power Control
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _sendCommand({'swt': true}),
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('ON'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _sendCommand({'swt': false}),
                      icon: const Icon(Icons.power_off),
                      label: const Text('OFF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),

                // Brightness Control
                if (_device.supportsBrightness)
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text('Brightness', style: TextStyle(fontSize: 16)),
                      Slider(
                        value: localBrightness,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: '${localBrightness.toInt()}%',
                        onChanged: (value) {
                          setState(() {
                            localBrightness = value;
                          });
                        },
                        onChangeEnd: (value) =>
                            _sendCommand({'bri': value.toInt()}),
                      ),
                    ],
                  ),

                // Color Temperature Control
                if (_device.supportsColorTemp)
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Color Temperature',
                        style: TextStyle(fontSize: 16),
                      ),
                      Slider(
                        value: localColorTemp,
                        min: 2000,
                        max: 6500,
                        divisions: 45,
                        label: '${localColorTemp.toInt()}K',
                        onChanged: (value) {
                          setState(() {
                            localColorTemp = value;
                          });
                        },
                        onChangeEnd: (value) =>
                            _sendCommand({'cTp': value.toInt()}),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _showDetailedControl,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _device.isOn
                      ? Colors.amber.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIcon(),
                  color: _device.isOn ? Colors.amber : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _device.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _device.isOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 12,
                        color: _device.isOn ? Colors.green : Colors.red,
                      ),
                    ),
                    if (_device.brightness != null)
                      Text(
                        '${_device.brightness}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              Switch(
                value: _device.isOn,
                onChanged: (value) => _sendCommand({'swt': value}),
                activeColor: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    // Use mqttType to determine icon
    switch (_device.mqttType) {
      case MQTTDeviceType.swt:
        return Icons.power_settings_new;
      case MQTTDeviceType.dim:
        return Icons.brightness_6;
      case MQTTDeviceType.rgb:
        return Icons.palette;
      case MQTTDeviceType.tun:
        return Icons.light_mode;
      case MQTTDeviceType.hvc:
        return Icons.thermostat;
      case MQTTDeviceType.fan:
        return Icons.toys;
      case MQTTDeviceType.cur:
        return Icons.curtains;
      case MQTTDeviceType.scn:
        return Icons.auto_awesome;
    }
  }
}
