// automation_config_screen.dart
// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_home_animation/core/shared/domain/entities/smart_room.dart';
import 'package:smart_home_animation/services/device_provider.dart';

class AutomationConfigScreen extends StatefulWidget {
  final SmartRoom room;

  const AutomationConfigScreen({super.key, required this.room});

  @override
  State<AutomationConfigScreen> createState() => _AutomationConfigScreenState();
}

class _AutomationConfigScreenState extends State<AutomationConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSensor;
  String? _selectedDevice;
  String? _selectedCondition;
  String? _conditionValue;
  String? _selectedAction;
  String? _actionValue;

  @override
  Widget build(BuildContext context) {
    final deviceProvider = Provider.of<DeviceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Automation'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Sensor selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Sensor',
                  border: OutlineInputBorder(),
                ),
                value: _selectedSensor,
                items: widget.room.sensors.map((sensor) {
                  return DropdownMenuItem(
                    value: sensor.id,
                    child: Text(sensor.name),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedSensor = value),
                validator: (value) =>
                    value == null ? 'Please select a sensor' : null,
              ),

              const SizedBox(height: 20),

              // Condition selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Condition',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCondition,
                items: const [
                  DropdownMenuItem(
                    value: 'temperature_gt',
                    child: Text('Temperature >'),
                  ),
                  DropdownMenuItem(
                    value: 'temperature_lt',
                    child: Text('Temperature <'),
                  ),
                  DropdownMenuItem(
                    value: 'motion_detected',
                    child: Text('Motion Detected'),
                  ),
                  DropdownMenuItem(
                    value: 'light_level_gt',
                    child: Text('Light Level >'),
                  ),
                  DropdownMenuItem(
                    value: 'light_level_lt',
                    child: Text('Light Level <'),
                  ),
                  DropdownMenuItem(
                    value: 'humidity_gt',
                    child: Text('Humidity >'),
                  ),
                  DropdownMenuItem(
                    value: 'humidity_lt',
                    child: Text('Humidity <'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _selectedCondition = value;
                  _conditionValue = null;
                }),
                validator: (value) =>
                    value == null ? 'Please select a condition' : null,
              ),

              // Condition value input (for conditions that need a value)
              if (_selectedCondition != null &&
                  !_selectedCondition!.contains('detected'))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: _getConditionLabel(_selectedCondition!),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _conditionValue = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value';
                      }
                      return null;
                    },
                  ),
                ),

              const SizedBox(height: 20),

              // Device selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Device to Control',
                  border: OutlineInputBorder(),
                ),
                value: _selectedDevice,
                items: widget.room.devices.map((device) {
                  return DropdownMenuItem(
                    value: device.id,
                    child: Text(device.name),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedDevice = value),
                validator: (value) =>
                    value == null ? 'Please select a device' : null,
              ),

              const SizedBox(height: 20),

              // Action selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Action',
                  border: OutlineInputBorder(),
                ),
                value: _selectedAction,
                items: [
                  const DropdownMenuItem(
                    value: 'turn_on',
                    child: Text('Turn On'),
                  ),
                  const DropdownMenuItem(
                    value: 'turn_off',
                    child: Text('Turn Off'),
                  ),
                  if (_selectedDevice != null)
                    DropdownMenuItem(
                      value: 'set_brightness',
                      child: Text('Set Brightness'),
                    ),
                  if (_selectedDevice != null)
                    DropdownMenuItem(
                      value: 'set_temperature',
                      child: Text('Set Temperature'),
                    ),
                ].where((item) => item != null).toList(),
                onChanged: (value) => setState(() {
                  _selectedAction = value;
                  _actionValue = null;
                }),
                validator: (value) =>
                    value == null ? 'Please select an action' : null,
              ),

              // Action value input
              if (_selectedAction == 'set_brightness')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Brightness (%)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _actionValue = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter brightness value';
                      }
                      final intValue = int.tryParse(value);
                      if (intValue == null || intValue < 0 || intValue > 100) {
                        return 'Please enter a value between 0-100';
                      }
                      return null;
                    },
                  ),
                ),

              if (_selectedAction == 'set_temperature')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Temperature (°C)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _actionValue = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter temperature value';
                      }
                      final intValue = int.tryParse(value);
                      if (intValue == null || intValue < 16 || intValue > 30) {
                        return 'Please enter a value between 16-30°C';
                      }
                      return null;
                    },
                  ),
                ),

              const SizedBox(height: 40),

              // Save button
              ElevatedButton(
                onPressed: _saveAutomation,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Save Automation Rule'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getConditionLabel(String condition) {
    switch (condition) {
      case 'temperature_gt':
      case 'temperature_lt':
        return 'Temperature Value (°C)';
      case 'light_level_gt':
      case 'light_level_lt':
        return 'Light Level (lux)';
      case 'humidity_gt':
      case 'humidity_lt':
        return 'Humidity (%)';
      default:
        return 'Value';
    }
  }

  String _getActionCommand() {
    switch (_selectedAction) {
      case 'turn_on':
        return 'ON';
      case 'turn_off':
        return 'OFF';
      case 'set_brightness':
        return 'SET_BRIGHTNESS';
      case 'set_temperature':
        return 'SET_TEMPERATURE';
      default:
        return '';
    }
  }

  Future<void> _saveAutomation() async {
    if (_formKey.currentState!.validate()) {
      final deviceProvider = Provider.of<DeviceProvider>(
        context,
        listen: false,
      );

      // Find the selected device to get its type
      final selectedDevice = widget.room.devices.firstWhere(
        (d) => d.id == _selectedDevice,
      );

      // Prepare the action value
      dynamic actionValue;
      if (_selectedAction == 'set_brightness') {
        actionValue = int.parse(_actionValue!);
      } else if (_selectedAction == 'set_temperature') {
        actionValue = int.parse(_actionValue!);
      }

      // Prepare the condition value
      dynamic conditionValue;
      if (_conditionValue != null && _conditionValue!.isNotEmpty) {
        conditionValue = double.parse(_conditionValue!);
      }

      await deviceProvider.configureSensorTrigger(
        sensorId: _selectedSensor!,
        deviceId: _selectedDevice!,
        condition: _selectedCondition!,
        value: conditionValue,
        action: _getActionCommand(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Automation rule saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
