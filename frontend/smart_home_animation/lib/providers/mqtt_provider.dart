import 'package:flutter/material.dart';
import 'package:smart_home_animation/services/mqtt_command_service.dart';

class MQTTProvider extends ChangeNotifier {
  final MQTTService _mqttService = MQTTService();
  bool _isConnected = false;
  bool _isConnecting = false;
  String _connectionMessage = 'Initializing...';

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get connectionMessage => _connectionMessage;
  MQTTService get mqttService => _mqttService;

  MQTTProvider() {
    _initMQTT();
  }

  Future<void> _initMQTT() async {
    _isConnecting = true;
    _connectionMessage = 'Connecting to MQTT broker...';
    notifyListeners();

    // Listen to connection status
    _mqttService.connectionStatus.listen((connected) {
      _isConnected = connected;
      _isConnecting = false;
      _connectionMessage = connected ? 'Connected' : 'Disconnected';
      notifyListeners();
    });

    // Attempt to connect
    bool connected = await _mqttService.connect();

    if (!connected) {
      _connectionMessage = 'Retrying connection...';
      notifyListeners();
      // Auto-retry is handled by the service
    }
  }

  Future<void> reconnect() async {
    await _mqttService.disconnect();
    await _mqttService.connect();
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }
}
