// entities/sensor_config.dart
import 'package:equatable/equatable.dart';

class SensorConfig extends Equatable {
  final String sensorId;
  final double? samplingInterval; // Seconds between readings
  final double? threshold; // Threshold for triggers
  final bool enabled;
  final Map<String, dynamic> settings;

  const SensorConfig({
    required this.sensorId,
    this.samplingInterval,
    this.threshold,
    this.enabled = true,
    this.settings = const {},
  });

  factory SensorConfig.fromJson(Map<String, dynamic> json) {
    return SensorConfig(
      sensorId: json['sensorId'] as String,
      samplingInterval: json['samplingInterval'] != null
          ? double.tryParse(json['samplingInterval'].toString())
          : null,
      threshold: json['threshold'] != null
          ? double.tryParse(json['threshold'].toString())
          : null,
      enabled: json['enabled'] as bool? ?? true,
      settings: json['settings'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sensorId': sensorId,
      'samplingInterval': samplingInterval,
      'threshold': threshold,
      'enabled': enabled,
      'settings': settings,
    };
  }

  @override
  List<Object?> get props => [
    sensorId,
    samplingInterval,
    threshold,
    enabled,
    settings,
  ];
}
