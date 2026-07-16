// entities/device_state.dart
import 'package:equatable/equatable.dart';

class DeviceState extends Equatable {
  final String deviceId;
  final bool isOn;
  final double? intensity; // For lights
  final double? temperature; // For AC/thermostats
  final String? mode; // For AC modes (cool, heat, fan)
  final double? fanSpeed; // For AC fan speed
  final DateTime lastUpdated;
  final Map<String, dynamic> additionalData;
  final Map<String, dynamic> attributes;

  const DeviceState({
    required this.deviceId,
    required this.isOn,
    this.intensity,
    this.temperature,
    this.mode,
    this.fanSpeed,
    required this.lastUpdated,
    this.additionalData = const {},
    this.attributes = const {},
  });

  factory DeviceState.fromJson(Map<String, dynamic> json) {
    return DeviceState(
      deviceId: json['deviceId'] as String,
      isOn: json['isOn'] as bool,
      intensity: json['intensity'] != null
          ? double.tryParse(json['intensity'].toString())
          : null,
      temperature: json['temperature'] != null
          ? double.tryParse(json['temperature'].toString())
          : null,
      mode: json['mode'] as String?,
      fanSpeed: json['fanSpeed'] != null
          ? double.tryParse(json['fanSpeed'].toString())
          : null,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      additionalData: json['additionalData'] as Map<String, dynamic>? ?? {},
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'isOn': isOn,
      'intensity': intensity,
      'temperature': temperature,
      'mode': mode,
      'fanSpeed': fanSpeed,
      'lastUpdated': lastUpdated.toIso8601String(),
      'additionalData': additionalData,
      'attributes': attributes,
    };
  }

  DeviceState copyWith({
    String? deviceId,
    bool? isOn,
    double? intensity,
    double? temperature,
    String? mode,
    double? fanSpeed,
    DateTime? lastUpdated,
    Map<String, dynamic>? additionalData,
    Map<String, dynamic>? attributes,
  }) {
    return DeviceState(
      deviceId: deviceId ?? this.deviceId,
      isOn: isOn ?? this.isOn,
      intensity: intensity ?? this.intensity,
      temperature: temperature ?? this.temperature,
      mode: mode ?? this.mode,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      additionalData: additionalData ?? this.additionalData,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  List<Object?> get props => [
    deviceId,
    isOn,
    intensity,
    temperature,
    mode,
    fanSpeed,
    lastUpdated,
    additionalData,
    attributes,
  ];
}
