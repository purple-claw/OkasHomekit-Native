// lib/core/shared/domain/entities/device.dart
// ignore_for_file: must_be_immutable

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum DeviceType {
  light,
  airConditioner,
  thermostat,
  smartPlug,
  fan,
  tv,
  speaker,
  camera,
  doorLock,
  windowBlind,
  curtain,
  scene,
  other,
}

// MQTT device types from OKAS system
enum MQTTDeviceType {
  swt, // Switch
  dim, // Dimmer
  rgb, // RGB Light
  tun, // Tunable White
  hvc, // HVAC
  fan, // Fan
  cur, // Curtain
  scn, // Scene
}

class Device extends Equatable {
  final String id;
  final String name;
  final DeviceType type;
  final MQTTDeviceType mqttType;
  final String room;
  final String roomId;
  final IconData icon;
  final Color color;
  final String? manufacturer;
  final String? model;
  final String? firmwareVersion;
  final String sensortype;
  final bool isOnline;
  final Map<String, dynamic> capabilities;
  final DateTime lastSeen;
  final String category;

  // Mutable properties
  bool isOn;
  double value;

  // MQTT specific properties
  int? brightness;
  int? colorTemp;
  int? hue;
  int? saturation;
  int? fanSpeed;
  int? position;
  double? temperature;
  int? setpoint;
  int? mode;
  String? sceneId;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.mqttType,
    required this.roomId,
    required this.room,
    required this.icon,
    required this.color,
    required this.isOn,
    required this.sensortype,
    this.manufacturer,
    this.model,
    this.firmwareVersion,
    this.isOnline = false,
    this.capabilities = const {},
    required this.lastSeen,
    this.category = 'other',
    this.value = 0,
    this.brightness,
    this.colorTemp,
    this.hue,
    this.saturation,
    this.fanSpeed,
    this.position,
    this.temperature,
    this.setpoint,
    this.mode,
    this.sceneId,
  });

  // Getters for UI
  bool get supportsBrightness =>
      mqttType == MQTTDeviceType.dim ||
      mqttType == MQTTDeviceType.rgb ||
      mqttType == MQTTDeviceType.tun;

  bool get supportsColor => mqttType == MQTTDeviceType.rgb;
  bool get supportsColorTemp => mqttType == MQTTDeviceType.tun;
  bool get supportsFanSpeed =>
      mqttType == MQTTDeviceType.fan || mqttType == MQTTDeviceType.hvc;
  bool get supportsPosition => mqttType == MQTTDeviceType.cur;
  bool get supportsTemperature => mqttType == MQTTDeviceType.hvc;

  String get displayStatus {
    if (!isOn) return 'OFF';

    switch (mqttType) {
      case MQTTDeviceType.dim:
      case MQTTDeviceType.rgb:
      case MQTTDeviceType.tun:
        return '${brightness ?? value.toInt()}%';
      case MQTTDeviceType.hvc:
        return '${setpoint ?? temperature?.toInt() ?? 22}°C';
      case MQTTDeviceType.cur:
        return '${position ?? 0}%';
      default:
        return 'ON';
    }
  }

  // Helper method for MQTT commands
  Map<String, dynamic> getCommandForAction(String action, {dynamic value}) {
    switch (mqttType) {
      case MQTTDeviceType.swt:
        if (action == 'ON') return {'swt': true};
        if (action == 'OFF') return {'swt': false};
        break;

      case MQTTDeviceType.dim:
        if (action == 'ON') return {'swt': true};
        if (action == 'OFF') return {'swt': false};
        if (action == 'SET_BRIGHTNESS') {
          return {'bri': value ?? brightness ?? 0};
          }
        break;

      case MQTTDeviceType.rgb:
        if (action == 'ON') return {'swt': true};
        if (action == 'OFF') return {'swt': false};
        if (action == 'SET_BRIGHTNESS') {
          return {'bri': value ?? brightness ?? 0};
          }
        if (action == 'SET_HUE') return {'hue': value ?? hue ?? 0};
        if (action == 'SET_SATURATION') {
          return {'sat': value ?? saturation ?? 0};
          }
        break;

      case MQTTDeviceType.tun:
        if (action == 'ON') return {'swt': true};
        if (action == 'OFF') return {'swt': false};
        if (action == 'SET_BRIGHTNESS') {
          return {'bri': value ?? brightness ?? 0};
          }
        if (action == 'SET_COLOR_TEMP') {
          return {'cTp': value ?? colorTemp ?? 2700};
          }
        break;

      case MQTTDeviceType.hvc:
        if (action == 'ON') return {'swt': true};
        if (action == 'OFF') return {'swt': false};
        if (action == 'SET_TEMPERATURE') {
          return {'spt': value ?? setpoint ?? 22};
          }
        if (action == 'SET_FAN_SPEED') return {'fSp': value ?? fanSpeed ?? 0};
        if (action == 'SET_MODE') return {'mod': value ?? mode ?? 0};
        break;

      case MQTTDeviceType.fan:
        if (action == 'ON') return {'swt': true};
        if (action == 'OFF') return {'swt': false};
        if (action == 'SET_FAN_SPEED') return {'fSp': value ?? fanSpeed ?? 0};
        break;

      case MQTTDeviceType.cur:
        if (action == 'SET_POSITION') return {'pos': value ?? position ?? 0};
        break;

      case MQTTDeviceType.scn:
        if (action == 'TRIGGER') return {'scn': value ?? 1};
        break;
    }
    return {};
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    IconData getIconFromType(String type) {
      switch (type) {
        case 'swt':
        case 'dim':
        case 'light':
          return Icons.lightbulb_outline;
        case 'rgb':
          return Icons.palette;
        case 'tun':
          return Icons.light_mode;
        case 'hvc':
        case 'airConditioner':
          return Icons.thermostat;
        case 'fan':
          return Icons.toys;
        case 'cur':
          return Icons.curtains;
        case 'scn':
          return Icons.auto_awesome;
        default:
          return Icons.devices_other;
      }
    }

    Color getColorFromType(String type) {
      switch (type) {
        case 'swt':
        case 'dim':
        case 'light':
        case 'tun':
          return Colors.amber;
        case 'rgb':
          return Colors.purple;
        case 'hvc':
        case 'airConditioner':
          return Colors.blue;
        case 'fan':
          return Colors.lightBlue;
        case 'cur':
          return Colors.green;
        case 'scn':
          return Colors.pink;
        default:
          return Colors.grey;
      }
    }

    String deviceTypeString = json['type'] as String? ?? 'other';
    DeviceType deviceType = DeviceType.values.firstWhere(
      (e) => e.toString().split('.').last == deviceTypeString,
      orElse: () => DeviceType.other,
    );

    String mqttTypeString =
        json['mqttType'] as String? ?? (json['typ'] as String? ?? 'swt');
    MQTTDeviceType mqttType = MQTTDeviceType.values.firstWhere(
      (e) => e.toString().split('.').last == mqttTypeString,
      orElse: () => MQTTDeviceType.swt,
    );

    final String category = json['category'] as String? ?? mqttTypeString;
    final double value = (json['value'] ?? 0).toDouble();

    final roomIdValue = json['roomId'];
    final String roomId = roomIdValue != null ? roomIdValue.toString() : '';

    final state = json['sta'] as Map<String, dynamic>?;
    final bool isOn = state?['on'] ?? json['isOn'] as bool? ?? false;
    final int? brightness = state?['bri'];
    final int? colorTemp = state?['cTp'];
    final int? hue = state?['hue'];
    final int? saturation = state?['sat'];
    final int? fanSpeed = state?['fSp'];
    final int? position = state?['pos'] ?? state?['cPs'];
    final double? temperature = state?['rTp']?.toDouble();
    final int? setpoint = state?['spt'];
    final int? mode = state?['mod'];

    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      type: deviceType,
      mqttType: mqttType,
      roomId: roomId,
      room: json['room'] as String? ?? 'Unknown Room',
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      firmwareVersion: json['firmwareVersion'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      capabilities: json['capabilities'] as Map<String, dynamic>? ?? {},
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : DateTime.now(),
      sensortype: json['sensortype'] as String? ?? 'unknown',
      icon: getIconFromType(mqttTypeString),
      color: getColorFromType(mqttTypeString),
      isOn: isOn,
      category: category,
      value: value,
      brightness: brightness,
      colorTemp: colorTemp,
      hue: hue,
      saturation: saturation,
      fanSpeed: fanSpeed,
      position: position,
      temperature: temperature,
      setpoint: setpoint,
      mode: mode,
      sceneId: json['sceneId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'mqttType': mqttType.toString().split('.').last,
      'roomId': roomId,
      'room': room,
      'manufacturer': manufacturer,
      'model': model,
      'firmwareVersion': firmwareVersion,
      'isOnline': isOnline,
      'capabilities': capabilities,
      'lastSeen': lastSeen.toIso8601String(),
      'sensortype': sensortype,
      'isOn': isOn,
      'category': category,
      'value': value,
      'brightness': brightness,
      'colorTemp': colorTemp,
      'hue': hue,
      'saturation': saturation,
      'fanSpeed': fanSpeed,
      'position': position,
      'temperature': temperature,
      'setpoint': setpoint,
      'mode': mode,
      'sceneId': sceneId,
    };
  }

  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    MQTTDeviceType? mqttType,
    String? room,
    String? roomId,
    IconData? icon,
    Color? color,
    bool? isOn,
    String? manufacturer,
    String? model,
    String? firmwareVersion,
    String? sensortype,
    bool? isOnline,
    Map<String, dynamic>? capabilities,
    DateTime? lastSeen,
    String? category,
    double? value,
    int? brightness,
    int? colorTemp,
    int? hue,
    int? saturation,
    int? fanSpeed,
    int? position,
    double? temperature,
    int? setpoint,
    int? mode,
    String? sceneId,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      mqttType: mqttType ?? this.mqttType,
      room: room ?? this.room,
      roomId: roomId ?? this.roomId,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isOn: isOn ?? this.isOn,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      sensortype: sensortype ?? this.sensortype,
      isOnline: isOnline ?? this.isOnline,
      capabilities: capabilities ?? this.capabilities,
      lastSeen: lastSeen ?? this.lastSeen,
      category: category ?? this.category,
      value: value ?? this.value,
      brightness: brightness ?? this.brightness,
      colorTemp: colorTemp ?? this.colorTemp,
      hue: hue ?? this.hue,
      saturation: saturation ?? this.saturation,
      fanSpeed: fanSpeed ?? this.fanSpeed,
      position: position ?? this.position,
      temperature: temperature ?? this.temperature,
      setpoint: setpoint ?? this.setpoint,
      mode: mode ?? this.mode,
      sceneId: sceneId ?? this.sceneId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    mqttType,
    roomId,
    room,
    manufacturer,
    model,
    firmwareVersion,
    isOnline,
    capabilities,
    lastSeen,
    sensortype,
    isOn,
    icon,
    color,
    category,
    value,
    brightness,
    colorTemp,
    hue,
    saturation,
    fanSpeed,
    position,
    temperature,
    setpoint,
    mode,
    sceneId,
  ];
}
