// lib/widgets/device_control_popup.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/services/mqtt_command_service.dart';

class DeviceControlPopup extends StatefulWidget {
  final Device device;

  const DeviceControlPopup({super.key, required this.device});

  @override
  State<DeviceControlPopup> createState() => _DeviceControlPopupState();
}

class _DeviceControlPopupState extends State<DeviceControlPopup> {
  late Device _device;
  double _localBrightness = 0;
  double _localColorTemp = 2700;
  int _localFanSpeed = 0;
  int _localPosition = 0;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _localBrightness = (_device.brightness ?? 0).toDouble();
    _localColorTemp = (_device.colorTemp ?? 2700).toDouble();
    _localFanSpeed = _device.fanSpeed ?? 0;
    _localPosition = _device.position ?? 0;
  }

  void _sendCommand(Map<String, dynamic> cmd) async {
    final mqttService = Provider.of<MQTTService>(context, listen: false);
    final loadId = int.parse(_device.id);
    final type = _device.mqttType.toString().split('.').last;
    await mqttService.sendCommand(loadId, type, cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                _getIcon(),
                size: 32,
                color: _device.isOn ? Colors.amber : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _device.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Power Control
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPowerButton('ON', true, Colors.green),
              _buildPowerButton('OFF', false, Colors.red),
            ],
          ),

          // Brightness Control
          if (_device.supportsBrightness) _buildBrightnessControl(),

          // Color Temperature Control
          if (_device.supportsColorTemp) _buildColorTempControl(),

          // Fan Speed Control
          if (_device.supportsFanSpeed) _buildFanSpeedControl(),

          // Position Control (Curtains)
          if (_device.supportsPosition) _buildPositionControl(),

          // Temperature Control (HVAC)
          if (_device.supportsTemperature) _buildTemperatureControl(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPowerButton(String label, bool isOn, Color color) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () {
          _sendCommand({'swt': isOn});
          setState(() => _device.isOn = isOn);
        },
        icon: Icon(isOn ? Icons.power_settings_new : Icons.power_off),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _device.isOn == isOn ? color : Colors.grey[800],
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBrightnessControl() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.brightness_low),
            Expanded(
              child: Slider(
                value: _localBrightness,
                min: 0,
                max: 100,
                divisions: 100,
                label: '${_localBrightness.toInt()}%',
                onChanged: (value) => setState(() => _localBrightness = value),
                onChangeEnd: (value) => _sendCommand({'bri': value.toInt()}),
              ),
            ),
            const Icon(Icons.brightness_high),
          ],
        ),
        Center(
          child: Text(
            '${_localBrightness.toInt()}%',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildColorTempControl() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.wb_sunny),
            Expanded(
              child: Slider(
                value: _localColorTemp,
                min: 2000,
                max: 6500,
                divisions: 45,
                label: '${_localColorTemp.toInt()}K',
                onChanged: (value) => setState(() => _localColorTemp = value),
                onChangeEnd: (value) => _sendCommand({'cTp': value.toInt()}),
              ),
            ),
            const Icon(Icons.wb_sunny),
          ],
        ),
        Center(
          child: Text(
            '${_localColorTemp.toInt()}K',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildFanSpeedControl() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text('Fan Speed', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final speed = index + 1;
            return _buildSpeedButton(
              speed,
              speed.toString(),
              _localFanSpeed == speed,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSpeedButton(int speed, String label, bool isSelected) {
    return ElevatedButton(
      onPressed: () {
        _sendCommand({'fSp': speed});
        setState(() => _localFanSpeed = speed);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey[800],
        shape: const CircleBorder(),
      ),
      child: Text(label),
    );
  }

  Widget _buildPositionControl() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.curtains),
            Expanded(
              child: Slider(
                value: _localPosition.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '${_localPosition}%',
                onChanged: (value) =>
                    setState(() => _localPosition = value.toInt()),
                onChangeEnd: (value) => _sendCommand({'pos': value.toInt()}),
              ),
            ),
            const Icon(Icons.curtains),
          ],
        ),
        Center(
          child: Text(
            '${_localPosition}% Open',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureControl() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.thermostat),
            Expanded(
              child: Slider(
                value: (_device.setpoint ?? 22).toDouble(),
                min: 16,
                max: 30,
                divisions: 14,
                label: '${_device.setpoint ?? 22}°C',
                onChanged: (value) {
                  setState(() => _device.setpoint = value.toInt());
                  _sendCommand({'spt': value.toInt()});
                },
              ),
            ),
            const Icon(Icons.thermostat),
          ],
        ),
        Center(
          child: Text(
            '${_device.setpoint ?? 22}°C',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  IconData _getIcon() {
    switch (_device.mqttType) {
      case MQTTDeviceType.swt:
      case MQTTDeviceType.dim:
      case MQTTDeviceType.tun:
        return Icons.lightbulb_outline;
      case MQTTDeviceType.rgb:
        return Icons.palette;
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
