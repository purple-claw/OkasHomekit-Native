// lib/features/smart_room/screens/room_details_screen.dart
// ignore_for_file: unused_import

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/smart_room.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/parallax_image_card.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';

class RoomDetailScreen extends StatelessWidget {
  const RoomDetailScreen({required this.room, super.key});

  final SmartRoom room;

  @override
  Widget build(BuildContext context) {
    final okasService = Provider.of<DirectMQTTService>(context);

    // Get devices for this room from the service
    final roomDevices = okasService.devices.values
        .where((device) => room.devices.any((d) => d.id == device['id']))
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(room.name, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (room.imageUrl.isNotEmpty)
            ParallaxImageCard(imageUrl: room.imageUrl)
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blueGrey[900]!, Colors.blueGrey[800]!],
                ),
              ),
            ),

          // Blur overlay
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaY: 10, sigmaX: 10),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Settings Text
                const Text(
                  'ROOM CONTROLS',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    color: Colors.white70,
                  ),
                ),

                // Status Indicator
                _RoomStatusIndicator(
                  isConnected: okasService.isConnected,
                  deviceCount: roomDevices.length,
                ),

                // Device Controls List
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (roomDevices.isNotEmpty) ...[
                          const Text(
                            'DEVICES',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...roomDevices.map(
                            (device) =>
                                _buildDeviceCard(context, device, okasService),
                          ),
                        ] else ...[
                          const Center(
                            child: Text(
                              'No devices in this room',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    Map<String, dynamic> device,
    DirectMQTTService okasService,
  ) {
    final isOn = device['isOn'] ?? false;
    final deviceId = device['id'];
    final deviceName = device['name'];
    final deviceType = device['type'] ?? 'swt';
    final brightness = device['brightness'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey[900]?.withOpacity(0.8),
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
                size: 20,
              ),
            ),
            title: Text(
              deviceName,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              isOn ? 'ON' : 'OFF',
              style: TextStyle(
                color: isOn ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
            trailing: Switch(
              value: isOn,
              onChanged: (value) async {
                okasService.sendCommand(deviceId, value ? 'ON' : 'OFF');
                // Show feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$deviceName turned ${value ? "ON" : "OFF"}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              activeColor: Colors.amber,
            ),
          ),
          // Show slider for dimmer devices
          if (deviceType == 'dim' && isOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.brightness_low,
                    size: 20,
                    color: Colors.white54,
                  ),
                  Expanded(
                    child: Slider(
                      value: brightness.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: '$brightness%',
                      onChanged: (value) {
                        okasService.sendBrightnessCommand(
                          deviceId,
                          value.toInt(),
                        );
                      },
                    ),
                  ),
                  const Icon(
                    Icons.brightness_high,
                    size: 20,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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

class _RoomStatusIndicator extends StatelessWidget {
  final bool isConnected;
  final int deviceCount;

  const _RoomStatusIndicator({
    required this.isConnected,
    required this.deviceCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            size: 14,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            '$deviceCount device(s)',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
