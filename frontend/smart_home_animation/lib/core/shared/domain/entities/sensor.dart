// entities/sensor.dart
import 'package:equatable/equatable.dart';

enum SensorType {
  temperature,
  humidity,
  motion,
  light,
  contact, // Door/window sensor
  smoke,
  co2,
  waterLeak,
  vibration,
  gas,
  other,
}

class Sensor extends Equatable {
  final String id;
  final String name;
  final SensorType type;
  final String roomId;
  final String? unit;
  final double? currentValue;
  final double? minValue;
  final double? maxValue;
  final DateTime lastReading;
  final Map<String, dynamic> metadata;

  const Sensor({
    required this.id,
    required this.name,
    required this.type,
    required this.roomId,
    this.unit,
    this.currentValue,
    this.minValue,
    this.maxValue,
    required this.lastReading,
    this.metadata = const {},
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      id: json['id'] as String,
      name: json['name'] as String,
      type: SensorType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => SensorType.other,
      ),
      roomId: json['roomId'] as String,
      unit: json['unit'] as String?,
      currentValue: json['currentValue'] != null
          ? double.tryParse(json['currentValue'].toString())
          : null,
      minValue: json['minValue'] != null
          ? double.tryParse(json['minValue'].toString())
          : null,
      maxValue: json['maxValue'] != null
          ? double.tryParse(json['maxValue'].toString())
          : null,
      lastReading: DateTime.parse(json['lastReading'] as String),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'roomId': roomId,
      'unit': unit,
      'currentValue': currentValue,
      'minValue': minValue,
      'maxValue': maxValue,
      'lastReading': lastReading.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Get emoji icon for sensor type
  String get icon {
    switch (type) {
      case SensorType.temperature:
        return '🌡️';
      case SensorType.humidity:
        return '💧';
      case SensorType.motion:
        return '👤';
      case SensorType.light:
        return '💡';
      case SensorType.contact:
        return '🚪';
      case SensorType.smoke:
        return '🔥';
      case SensorType.co2:
        return '☁️';
      case SensorType.waterLeak:
        return '💦';
      case SensorType.vibration:
        return '📳';
      case SensorType.gas:
        return '⛽'; // Gas pump emoji for gas sensor
      default:
        return '📡';
    }
  }

  // Get Material Icon for sensor type (for Flutter apps)
  // Note: This requires flutter/material.dart import
  // Uncomment if you want to use with Flutter
  /*
  IconData get materialIcon {
    switch (type) {
      case SensorType.temperature:
        return Icons.thermostat;
      case SensorType.humidity:
        return Icons.water_drop;
      case SensorType.motion:
        return Icons.directions_walk;
      case SensorType.light:
        return Icons.lightbulb_outline;
      case SensorType.contact:
        return Icons.door_front_door;
      case SensorType.smoke:
        return Icons.smoke_free;
      case SensorType.co2:
        return Icons.cloud;
      case SensorType.waterLeak:
        return Icons.water;
      case SensorType.vibration:
        return Icons.vibration;
      case SensorType.gas:
        return Icons.local_gas_station;
      default:
        return Icons.sensors;
    }
  }
  */

  // Get color for sensor type
  String get colorCode {
    switch (type) {
      case SensorType.temperature:
        return '#FF5722'; // Orange/Red
      case SensorType.humidity:
        return '#2196F3'; // Blue
      case SensorType.motion:
        return '#9C27B0'; // Purple
      case SensorType.light:
        return '#FFC107'; // Amber
      case SensorType.contact:
        return '#795548'; // Brown
      case SensorType.smoke:
        return '#F44336'; // Red
      case SensorType.co2:
        return '#607D8B'; // Blue Grey
      case SensorType.waterLeak:
        return '#00BCD4'; // Cyan
      case SensorType.vibration:
        return '#FF9800'; // Orange
      case SensorType.gas:
        return '#8BC34A'; // Light Green
      default:
        return '#9E9E9E'; // Grey
    }
  }

  // Get reading status based on current value and thresholds
  String get readingStatus {
    if (currentValue == null) return 'unknown';

    switch (type) {
      case SensorType.temperature:
        if (currentValue! < 18) return 'low';
        if (currentValue! > 28) return 'high';
        return 'normal';

      case SensorType.humidity:
        if (currentValue! < 30) return 'low';
        if (currentValue! > 70) return 'high';
        return 'normal';

      case SensorType.co2:
        if (currentValue! > 1000) return 'high';
        return 'normal';

      case SensorType.smoke:
      case SensorType.gas:
        if (currentValue! > 0) return 'detected';
        return 'clear';

      case SensorType.motion:
        return currentValue! > 0 ? 'detected' : 'clear';

      case SensorType.contact:
        return currentValue! > 0 ? 'open' : 'closed';

      case SensorType.waterLeak:
        return currentValue! > 0 ? 'leak' : 'dry';

      default:
        return 'normal';
    }
  }

  // Get formatted reading with unit
  String get formattedReading {
    if (currentValue == null) return 'No data';

    switch (type) {
      case SensorType.temperature:
        return '${currentValue!.toStringAsFixed(1)}°C';
      case SensorType.humidity:
        return '${currentValue!.toStringAsFixed(0)}%';
      case SensorType.light:
        return '${currentValue!.toStringAsFixed(0)} lux';
      case SensorType.co2:
        return '${currentValue!.toStringAsFixed(0)} ppm';
      case SensorType.motion:
        return currentValue! > 0 ? 'Motion detected' : 'No motion';
      case SensorType.contact:
        return currentValue! > 0 ? 'Open' : 'Closed';
      case SensorType.smoke:
        return currentValue! > 0 ? 'Smoke detected' : 'Clear';
      case SensorType.gas:
        return currentValue! > 0 ? 'Gas detected' : 'Clear';
      case SensorType.waterLeak:
        return currentValue! > 0 ? 'Leak detected' : 'Dry';
      default:
        return '${currentValue!.toStringAsFixed(1)}${unit ?? ''}';
    }
  }

  // Check if sensor is in alert state
  bool get isAlert {
    switch (type) {
      case SensorType.smoke:
      case SensorType.gas:
      case SensorType.waterLeak:
        return currentValue != null && currentValue! > 0;
      case SensorType.co2:
        return currentValue != null && currentValue! > 1000;
      case SensorType.temperature:
        return currentValue != null &&
            (currentValue! < 10 || currentValue! > 35);
      default:
        return false;
    }
  }

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    roomId,
    unit,
    currentValue,
    minValue,
    maxValue,
    lastReading,
    metadata,
  ];
}
