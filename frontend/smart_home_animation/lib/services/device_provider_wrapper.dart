// lib/services/device_provider_wrapper.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';

// Wrapper to provide DeviceProvider interface using DirectMQTTService
class DeviceProviderWrapper extends ChangeNotifier {
  final DirectMQTTService _mqttService;

  DeviceProviderWrapper(this._mqttService);

  Map<String, Map<String, dynamic>> get devices => _mqttService.devices;
  Map<String, Map<String, dynamic>> get rooms => _mqttService.rooms;
  bool get isConnected => _mqttService.isConnected;

  // Provide deviceStates getter that returns empty map or convert from devices
  Map<String, dynamic> get deviceStates => _mqttService.devices;

  void sendCommand(String deviceId, String command) {
    _mqttService.sendCommand(deviceId, command);
  }
}
