abstract class DeviceEvent {}

class LoadDevices extends DeviceEvent {}

class ToggleDevice extends DeviceEvent {
  final String deviceId;
  final bool isOn;

  ToggleDevice({required this.deviceId, required this.isOn});
}

class ExecuteScene extends DeviceEvent {
  final String sceneId;
  final String pin;

  ExecuteScene({required this.sceneId, required this.pin});
}
