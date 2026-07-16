// lib/widgets/add_accessories_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/services/mqtt_command_service.dart';

class AddAccessoriesBottomSheet extends StatefulWidget {
  final Function(List<String> selectedDeviceIds) onConfirm;

  const AddAccessoriesBottomSheet({super.key, required this.onConfirm});

  @override
  State<AddAccessoriesBottomSheet> createState() =>
      _AddAccessoriesBottomSheetState();
}

class _AddAccessoriesBottomSheetState extends State<AddAccessoriesBottomSheet> {
  final List<String> _selectedDeviceIds = [];

  @override
  Widget build(BuildContext context) {
    final mqttService = Provider.of<MQTTService>(context);
    final devices = mqttService.devices.values.toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Add Accessories',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select accessories to add to this room',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search accessories...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Accessories list grouped by category
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isSelected = _selectedDeviceIds.contains(device.id);

                return CheckboxListTile(
                  title: Text(device.name),
                  subtitle: Text(_getCategoryName(device.mqttType)),
                  secondary: Icon(_getIconForType(device.mqttType)),
                  value: isSelected,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedDeviceIds.add(device.id);
                      } else {
                        _selectedDeviceIds.remove(device.id);
                      }
                    });
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onConfirm(_selectedDeviceIds);
                    Navigator.pop(context);
                  },
                  child: Text('Add ${_selectedDeviceIds.length} Accessories'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCategoryName(MQTTDeviceType type) {
    switch (type) {
      case MQTTDeviceType.swt:
      case MQTTDeviceType.dim:
      case MQTTDeviceType.rgb:
      case MQTTDeviceType.tun:
        return 'Lights';
      case MQTTDeviceType.hvc:
        return 'Climate';
      case MQTTDeviceType.fan:
        return 'Fans';
      case MQTTDeviceType.cur:
        return 'Curtains';
      case MQTTDeviceType.scn:
        return 'Scenes';
    }
  }

  IconData _getIconForType(MQTTDeviceType type) {
    switch (type) {
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
