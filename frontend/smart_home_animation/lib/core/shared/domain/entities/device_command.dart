// entities/device_command.dart
import 'package:equatable/equatable.dart';

class DeviceCommand extends Equatable {
  final String deviceId;
  final String command;
  final String? value;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;

  const DeviceCommand({
    required this.deviceId,
    required this.command,
    this.value,
    this.parameters = const {},
    required this.timestamp,
  });

  factory DeviceCommand.fromJson(Map<String, dynamic> json) {
    return DeviceCommand(
      deviceId: json['deviceId'] as String,
      command: json['command'] as String,
      value: json['value'] as String?,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'command': command,
      'value': value,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [deviceId, command, value, parameters, timestamp];
}
