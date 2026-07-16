// entities/device_trigger.dart
import 'package:equatable/equatable.dart';

class DeviceTrigger extends Equatable {
  final String id;
  final String name;
  final String sensorId;
  final String deviceId;
  final String condition;
  final dynamic conditionValue;
  final String action;
  final dynamic actionValue;
  final bool enabled;
  final DateTime createdAt;
  final DateTime? lastTriggered;

  const DeviceTrigger({
    required this.id,
    required this.name,
    required this.sensorId,
    required this.deviceId,
    required this.condition,
    required this.conditionValue,
    required this.action,
    required this.actionValue,
    this.enabled = true,
    required this.createdAt,
    this.lastTriggered,
  });

  factory DeviceTrigger.fromJson(Map<String, dynamic> json) {
    return DeviceTrigger(
      id: json['id'] as String,
      name: json['name'] as String,
      sensorId: json['sensorId'] as String,
      deviceId: json['deviceId'] as String,
      condition: json['condition'] as String,
      conditionValue: json['conditionValue'],
      action: json['action'] as String,
      actionValue: json['actionValue'],
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastTriggered: json['lastTriggered'] != null
          ? DateTime.parse(json['lastTriggered'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sensorId': sensorId,
      'deviceId': deviceId,
      'condition': condition,
      'conditionValue': conditionValue,
      'action': action,
      'actionValue': actionValue,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'lastTriggered': lastTriggered?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    sensorId,
    deviceId,
    condition,
    conditionValue,
    action,
    actionValue,
    enabled,
    createdAt,
    lastTriggered,
  ];
}
