// lib/screens/mqtt_test_screen.dart
// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../services/device_provider.dart';

class MQTTTestScreen extends StatefulWidget {
  @override
  _MQTTTestScreenState createState() => _MQTTTestScreenState();
}

class _MQTTTestScreenState extends State<MQTTTestScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _setupMQTTListener();
  }

  void _setupMQTTListener() {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    // Listen to device state updates
    deviceProvider.deviceStateStream.listen((state) {
      setState(() {
        _messages.insert(
          0,
          '[${DateTime.now().toLocal().toString().substring(11, 19)}] Device: ${state.deviceId}, State: ${state.isOn}',
        );
        if (_messages.length > 50) _messages.removeLast();
      });
    });
  }

  Future<void> _sendCommand() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    // Example: Toggle a light
    await deviceProvider.toggleDevice('living_main_light', true);

    setState(() {
      _messages.insert(
        0,
        '[${DateTime.now().toLocal().toString().substring(11, 19)}] Command sent: Turn ON living_main_light',
      );
    });
  }

  Future<void> _sendBrightnessCommand() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    // Set brightness
    await deviceProvider.setLightIntensity('living_main_light', 75);

    setState(() {
      _messages.insert(
        0,
        '[${DateTime.now().toLocal().toString().substring(11, 19)}] Command sent: Set brightness to 75%',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('MQTT Test')),
      body: Column(
        children: [
          // Connection Status
          Consumer<DeviceProvider>(
            builder: (context, provider, child) => Container(
              padding: EdgeInsets.all(16),
              color: provider.isConnected ? Colors.green : Colors.red,
              child: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    provider.isConnected
                        ? 'MQTT Connected to 192.168.1.169:1884'
                        : 'MQTT Disconnected',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Control Buttons
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sendCommand,
                        child: Text('Turn ON Light'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sendBrightnessCommand,
                        child: Text('Set 75% Brightness'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final deviceProvider = Provider.of<DeviceProvider>(
                      context,
                      listen: false,
                    );
                    await deviceProvider.setTemperature('living_ac', 24);
                  },
                  child: Text('Set AC to 24°C'),
                ),
              ],
            ),
          ),

          // Message Log
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'MQTT Message Log',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(_messages[index]),
                        leading: Icon(Icons.message, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
