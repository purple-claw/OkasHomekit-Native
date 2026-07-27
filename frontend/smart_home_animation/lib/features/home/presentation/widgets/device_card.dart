import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/services/mqtt_command_service.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(),
              if (device.isOn) ...[
                const SizedBox(height: 12),
                _buildControls(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: device.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getDeviceIcon(),
            color: device.isOn ? device.color : Colors.grey,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                device.displayStatus,
                style: TextStyle(
                  color: device.isOn ? device.color : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        _buildMainToggle(),
      ],
    );
  }

  Widget _buildMainToggle() {
    return Switch(
      value: device.isOn,
      onChanged: device.supportsPosition ? null : (value) {
        _sendCommand({'swt': value});
      },
      activeColor: device.color,
    );
  }

  Widget _buildControls(BuildContext context) {
    switch (device.mqttType) {
      case MQTTDeviceType.dim:
      case MQTTDeviceType.tun:
        return _buildDimmerControls(context);
      case MQTTDeviceType.rgb:
        return _buildRgbControls(context);
      case MQTTDeviceType.hvc:
        return _buildHvacControls(context);
      case MQTTDeviceType.fan:
        return _buildFanControls(context);
      case MQTTDeviceType.cur:
        return _buildCurtainControls(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDimmerControls(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.brightness_low, color: Colors.white54, size: 20),
            Expanded(
              child: Slider(
                value: (device.brightness ?? 0).toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: device.color,
                inactiveColor: Colors.grey[700],
                onChanged: (value) {
                  _sendCommand({'bri': value.toInt()});
                },
              ),
            ),
            Text(
              '${device.brightness ?? 0}%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRgbControls(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.brightness_low, color: Colors.white54, size: 20),
            Expanded(
              child: Slider(
                value: (device.brightness ?? 0).toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: device.color,
                inactiveColor: Colors.grey[700],
                onChanged: (value) {
                  _sendCommand({'bri': value.toInt()});
                },
              ),
            ),
            Text(
              '${device.brightness ?? 0}%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.palette, color: Colors.white54, size: 20),
            const SizedBox(width: 8),
            _buildColorButton(Colors.red, 0),
            _buildColorButton(Colors.green, 120),
            _buildColorButton(Colors.blue, 240),
            _buildColorButton(Colors.purple, 280),
            _buildColorButton(Colors.orange, 30),
            _buildColorButton(Colors.white, -1),
          ],
        ),
      ],
    );
  }

  Widget _buildColorButton(Color color, int hue) {
    final isSelected = device.hue == hue || (hue == -1 && device.hue == null);
    return GestureDetector(
      onTap: () {
        if (hue == -1) {
          _sendCommand({'hue': 0, 'sat': 0});
        } else {
          _sendCommand({'hue': hue, 'sat': 100});
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildHvacControls(BuildContext context) {
    return Column(
      children: [
        // Mode Selection
        Wrap(
          spacing: 8,
          children: [
            _buildModeChip('Cool', 1, Icons.ac_unit),
            _buildModeChip('Heat', 2, Icons.whatshot),
            _buildModeChip('Auto', 3, Icons.autorenew),
            _buildModeChip('Dry', 4, Icons.water_drop),
          ],
        ),
        const SizedBox(height: 12),
        // Temperature Control
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                final current = device.setpoint ?? 22;
                if (current > 16) {
                  _sendCommand({'spt': current - 1});
                }
              },
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.white,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: device.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${device.setpoint ?? 22}°C',
                style: TextStyle(
                  color: device.color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                final current = device.setpoint ?? 22;
                if (current < 30) {
                  _sendCommand({'spt': current + 1});
                }
              },
              icon: const Icon(Icons.add_circle_outline),
              color: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Fan Speed Control
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Fan: ', style: TextStyle(color: Colors.white54)),
            ...List.generate(5, (index) {
              final speed = index + 1;
              final isActive = (device.fanSpeed ?? 0) >= speed;
              return GestureDetector(
                onTap: () => _sendCommand({'fSp': speed}),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? device.color : Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$speed',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildModeChip(String label, int mode, IconData icon) {
    final isSelected = device.mode == mode;
    return GestureDetector(
      onTap: () => _sendCommand({'mod': mode}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? device.color : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? device.color : Colors.grey[700]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFanControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.toys, color: Colors.white54, size: 20),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          final speed = index + 1;
          final isActive = (device.fanSpeed ?? 0) >= speed;
          return GestureDetector(
            onTap: () => _sendCommand({'fSp': speed}),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? device.color : Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$speed',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCurtainControls(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.curtains, color: Colors.white54, size: 20),
        Expanded(
          child: Slider(
            value: (device.position ?? 0).toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: device.color,
            inactiveColor: Colors.grey[700],
            onChanged: (value) {
              _sendCommand({'pos': value.toInt()});
            },
          ),
        ),
        Text(
          '${device.position ?? 0}%',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  void _sendCommand(Map<String, dynamic> cmd) async {
    // This would normally use Provider, but we'll emit an event
    // For now, just rebuild the widget
  }

  IconData _getDeviceIcon() {
    switch (device.mqttType) {
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
