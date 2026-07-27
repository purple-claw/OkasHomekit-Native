// lib/features/home/presentation/widgets/room_details_page_view.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/smart_room.dart';

import '../../../../core/shared/domain/entities/device_state.dart';

class RoomDetailsPageView extends StatelessWidget {
  const RoomDetailsPageView({
    super.key,
    required this.animation,
    required this.room,
    required this.roomDeviceStates,
    required this.onDeviceToggle,
    required this.onIntensityChange,
    required this.onTemperatureChange,
    required this.onFanSpeedChange,
    required this.onModeChange,
  });

  final Animation<double> animation;
  final SmartRoom room;
  final Map<String, DeviceState> roomDeviceStates;
  final Function(String, bool) onDeviceToggle;
  final Function(String, double) onIntensityChange;
  final Function(String, double) onTemperatureChange;
  final Function(String, double) onFanSpeedChange;
  final Function(String, String) onModeChange;

  @override
  Widget build(BuildContext context) {
    // Separate devices by type
    final lightDevices = room.devices
        .where(
          (d) =>
              d.type == DeviceType.light ||
              d.mqttType.toString().split('.').last == 'dim' ||
              d.mqttType.toString().split('.').last == 'swt',
        )
        .toList();

    final acDevices = room.devices
        .where(
          (d) =>
              d.type == DeviceType.airConditioner ||
              d.mqttType.toString().split('.').last == 'hvc',
        )
        .toList();

    final fanDevices = room.devices
        .where((d) => d.type == DeviceType.fan)
        .toList();

    final curtainDevices = room.devices
        .where(
          (d) =>
              d.type == DeviceType.windowBlind ||
              d.mqttType.toString().split('.').last == 'cur',
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Lights Section
          if (lightDevices.isNotEmpty) ...[
            const Text('LIGHTS', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...lightDevices.map(
              (device) => _buildDeviceControl(
                context,
                device,
                roomDeviceStates[device.id],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Climate Section
          if (acDevices.isNotEmpty) ...[
            const Text(
              'CLIMATE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...acDevices.map(
              (device) => _buildDeviceControl(
                context,
                device,
                roomDeviceStates[device.id],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Fans Section
          if (fanDevices.isNotEmpty) ...[
            const Text('FANS', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...fanDevices.map(
              (device) => _buildDeviceControl(
                context,
                device,
                roomDeviceStates[device.id],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Curtains Section
          if (curtainDevices.isNotEmpty) ...[
            const Text(
              'CURTAINS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...curtainDevices.map(
              (device) => _buildDeviceControl(
                context,
                device,
                roomDeviceStates[device.id],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Sensor Information
          if (room.sensors.isNotEmpty) ...[
            const Text(
              'SENSORS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...room.sensors.map(
              (sensor) => Card(
                child: ListTile(
                  leading: Icon(Icons.sensors),
                  title: Text(sensor.name),
                  subtitle: Text('${sensor.currentValue} ${sensor.unit ?? ''}'),
                  trailing: Text(sensor.type.toString().split('.').last),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceControl(
    BuildContext context,
    Device device,
    DeviceState? state,
  ) {
    final isOn = state?.isOn ?? device.isOn;
    final deviceType = device.mqttType.toString().split('.').last;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOn
                    ? Colors.amber.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconForType(deviceType),
                color: isOn ? Colors.amber : Colors.grey,
              ),
            ),
            title: Text(device.name),
            subtitle: Text(_getStatusText(device, state, deviceType)),
            trailing: Switch(
              value: isOn,
              onChanged: (value) => onDeviceToggle(device.id, value),
              activeColor: Colors.amber,
            ),
          ),

          // Brightness Slider for dimmer/rgb/tunable
          if ((deviceType == 'dim' ||
                  deviceType == 'rgb' ||
                  deviceType == 'tun') &&
              isOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.brightness_low, size: 20),
                      Expanded(
                        child: Slider(
                          value:
                              (state?.attributes['brightness'] ??
                                      device.brightness ??
                                      0)
                                  .toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label:
                              '${(state?.attributes['brightness'] ?? device.brightness ?? 0).toInt()}%',
                          onChanged: (value) =>
                              onIntensityChange(device.id, value),
                        ),
                      ),
                      const Icon(Icons.brightness_high, size: 20),
                    ],
                  ),
                  Text(
                    '${(state?.attributes['brightness'] ?? device.brightness ?? 0).toInt()}%',
                  ),
                ],
              ),
            ),

          // HVAC Controls: Fan Speed and Mode
          if (deviceType == 'hvc' && isOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fan Speed Row
                  const Row(
                    children: [
                      Icon(Icons.toys, size: 20),
                      SizedBox(width: 8),
                      Text('Fan Speed', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final speed = index + 1;
                      final currentSpeed = state?.attributes['fanSpeed'] ?? device.fanSpeed ?? 0;
                      final isSelected = currentSpeed == speed;
                      return _buildFanSpeedButton(
                        speed: speed,
                        isSelected: isSelected,
                        onTap: () => onFanSpeedChange(device.id, speed.toDouble()),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  // Mode Row
                  const Row(
                    children: [
                      Icon(Icons.ac_unit, size: 20),
                      SizedBox(width: 8),
                      Text('Mode', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildModeChip('Cool', 'cool', state, device, onModeChange),
                      _buildModeChip('Heat', 'heat', state, device, onModeChange),
                      _buildModeChip('Auto', 'auto', state, device, onModeChange),
                      _buildModeChip('Dry', 'dry', state, device, onModeChange),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFanSpeedButton({
    required int speed,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            '$speed',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(
    String label,
    String mode,
    DeviceState? state,
    Device device,
    Function(String, String) onModeChange,
  ) {
    final currentMode = state?.mode ?? device.mode ?? 'cool';
    final isSelected = currentMode.toString() == mode || 
        (currentMode is String && currentMode.toLowerCase() == mode.toLowerCase());
    return GestureDetector(
      onTap: () => onModeChange(device.id, mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _getStatusText(Device device, DeviceState? state, String type) {
    if (state == null) return 'No response';
    if (!state.isOn) return 'OFF';

    switch (type) {
      case 'dim':
      case 'rgb':
      case 'tun':
        final brightness =
            state.attributes['brightness'] ?? device.brightness ?? 0;
        return '${brightness.toInt()}%';
      case 'hvc':
        final temp =
            state.attributes['temperature'] ?? device.temperature ?? 22;
        return '${temp.toInt()}°C';
      default:
        return 'ON';
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'swt':
        return Icons.power_settings_new;
      case 'dim':
        return Icons.brightness_6;
      case 'rgb':
        return Icons.palette;
      case 'tun':
        return Icons.light_mode;
      case 'hvc':
        return Icons.thermostat;
      case 'fan':
        return Icons.toys;
      case 'cur':
        return Icons.curtains;
      default:
        return Icons.devices;
    }
  }
}
