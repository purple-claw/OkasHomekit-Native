// lib/services/i_device_service.dart
import 'dart:async';

import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_command.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_state.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_trigger.dart';
import 'package:smart_home_animation/core/shared/domain/entities/sensor_config.dart';

abstract class IDeviceService {
  Future<bool> connect();
  Future<void> disconnect();
  Stream<DeviceState> get deviceStateStream;
  Future<void> sendCommand(DeviceCommand command);
  Future<List<Device>> discoverDevices();
  Future<void> configureSensor(String sensorId, SensorConfig config);
  Future<void> setTrigger(DeviceTrigger trigger);
  Future<void> updateDeviceState(DeviceState state);
  Future<DeviceState?> getDeviceState(String deviceId);
}
