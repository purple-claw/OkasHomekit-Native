import 'package:smart_home_animation/core/shared/domain/entities/device.dart';

abstract class DeviceState {}

class DeviceInitial extends DeviceState {}

class DeviceLoading extends DeviceState {}

class DeviceLoaded extends DeviceState {
  final List<Device> devices;

  DeviceLoaded({required this.devices});
}

class DeviceError extends DeviceState {
  final String message;

  DeviceError({required this.message});
}
