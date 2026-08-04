// lib/services/http_device_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home_animation/core/shared/domain/entities/device_trigger.dart';
import 'package:smart_home_animation/core/shared/domain/entities/sensor_config.dart';

import '../core/shared/domain/entities/device.dart';
import '../core/shared/domain/entities/device_command.dart';
import '../core/shared/domain/entities/device_state.dart';
import 'i_device_service.dart';

class HTTPDeviceService implements IDeviceService {
  final String baseUrl;
  final StreamController<DeviceState> _stateController =
      StreamController<DeviceState>.broadcast();
  bool _connected = false;

  HTTPDeviceService({required this.baseUrl});

  @override
  Future<bool> connect() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      _connected = response.statusCode == 200;
      if (_connected) {
        debugPrint('✅ Connected to backend at $baseUrl');
      } else {
        debugPrint('❌ Failed to connect to backend: ${response.statusCode}');
      }
      return _connected;
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      _connected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _stateController.close();
  }

  @override
  Stream<DeviceState> get deviceStateStream => _stateController.stream;

  @override
  Future<void> sendCommand(DeviceCommand command) async {
    if (!_connected) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/devices/${command.deviceId}/command'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'command': command.command,
          'value': command.value,
          'roomId': command.parameters['roomId'] ?? '1',
        }),
      );
      debugPrint('Command sent: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error sending command: $e');
    }
  }

  @override
  Future<List<Device>> discoverDevices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/loads'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> devicesJson = data['data'];
        return devicesJson.map((json) => Device.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error discovering devices: $e');
      return [];
    }
  }

  @override
  Future<void> configureSensor(String sensorId, SensorConfig config) async {}

  @override
  Future<void> setTrigger(DeviceTrigger trigger) async {}

  @override
  Future<void> updateDeviceState(DeviceState state) async {}

  @override
  Future<DeviceState?> getDeviceState(String deviceId) async => null;
}
