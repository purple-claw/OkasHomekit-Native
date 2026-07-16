// lib/services/mock_device_service.dart
// ignore_for_file: unused_field

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_command.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_state.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_trigger.dart';
import 'package:smart_home_animation/core/shared/domain/entities/sensor_config.dart';

import 'i_device_service.dart';

class MockDeviceService implements IDeviceService {
  final StreamController<DeviceState> _stateController =
      StreamController<DeviceState>.broadcast();
  bool _connected = false;

  @override
  Future<bool> connect() async {
    debugPrint('Mock Device Service: Connecting...');
    await Future.delayed(Duration(milliseconds: 500));
    _connected = true;
    debugPrint('✅ Mock Device Service: Connected');
    return true;
  }

  @override
  Future<void> disconnect() async {
    debugPrint('Mock Device Service: Disconnecting...');
    _connected = false;
    await _stateController.close();
  }

  @override
  Stream<DeviceState> get deviceStateStream => _stateController.stream;

  @override
  Future<void> sendCommand(DeviceCommand command) async {
    debugPrint(
      'Mock Device Service: Command sent to ${command.deviceId}: ${command.command}',
    );
    // Simulate response
    _stateController.add(
      DeviceState(
        deviceId: command.deviceId,
        isOn: command.command == 'ON',
        attributes: {},
        lastUpdated: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<Device>> discoverDevices() async {
    debugPrint('Mock Device Service: Discovering devices...');
    return [];
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
