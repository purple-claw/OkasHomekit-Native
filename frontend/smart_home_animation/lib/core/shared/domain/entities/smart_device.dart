// class SmartDevice {
//   SmartDevice({required this.isOn, required this.value});

//   final bool isOn;
//   final int value;
// }
// smart_device.dart (updated if needed)
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_command.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_state.dart';

class SmartDevice {
  final bool isOn;
  final double value;

  SmartDevice({required this.isOn, required this.value});

  // Factory method to create from DeviceState
  factory SmartDevice.fromDeviceState(DeviceState state) {
    return SmartDevice(
      isOn: state.isOn,
      value: state.intensity ?? state.temperature ?? state.fanSpeed ?? 0,
    );
  }

  // Convert to DeviceCommand
  DeviceCommand toDeviceCommand(String deviceId, DeviceType type) {
    String command;
    String? value;

    switch (type) {
      case DeviceType.light:
        command = isOn ? 'ON' : 'OFF';
        value = isOn ? this.value.toString() : null;
        break;
      case DeviceType.airConditioner:
        command = isOn ? 'SET_TEMPERATURE' : 'OFF';
        value = isOn ? this.value.toString() : null;
        break;
      default:
        command = isOn ? 'ON' : 'OFF';
    }

    return DeviceCommand(
      deviceId: deviceId,
      command: command,
      value: value,
      timestamp: DateTime.now(),
    );
  }
}
