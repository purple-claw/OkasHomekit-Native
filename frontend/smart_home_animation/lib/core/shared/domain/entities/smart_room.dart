// entities/smart_room.dart
import 'package:flutter/material.dart';
import 'package:smart_home_animation/core/shared/domain/entities/automation_rule.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/sensor.dart';
import 'package:smart_home_animation/core/shared/domain/entities/smart_device.dart';

import 'music_info.dart';

// Helper function to get MQTT type from device type
MQTTDeviceType _getMQTTTypeFromDeviceType(
  DeviceType type, {
  bool isDimmer = false,
  bool isRGB = false,
}) {
  switch (type) {
    case DeviceType.light:
      if (isRGB) return MQTTDeviceType.rgb;
      if (isDimmer) return MQTTDeviceType.dim;
      return MQTTDeviceType.swt;
    case DeviceType.airConditioner:
      return MQTTDeviceType.hvc;
    case DeviceType.fan:
      return MQTTDeviceType.fan;
    case DeviceType.windowBlind:
      return MQTTDeviceType.cur;
    case DeviceType.thermostat:
      return MQTTDeviceType.hvc;
    default:
      return MQTTDeviceType.swt;
  }
}

class SmartRoom {
  SmartRoom({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.temperature,
    required this.airHumidity,
    required this.lights,
    required this.airCondition,
    required this.timer,
    required this.musicInfo,
    this.devices = const [],
    this.sensors = const [],
    this.automationRules = const [],
  });

  final String id;
  final String name;
  final String imageUrl;
  final double temperature;
  final double airHumidity;
  final SmartDevice lights;
  final SmartDevice airCondition;
  final SmartDevice timer;
  final MusicInfo musicInfo;
  final List<Device> devices;
  final List<Sensor> sensors;
  final List<AutomationRule> automationRules;

  // Factory method to create SmartRoom from JSON
  factory SmartRoom.fromJson(Map<String, dynamic> json) {
    return SmartRoom(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      airHumidity: (json['airHumidity'] ?? 0.0).toDouble(),
      lights: SmartDevice(
        isOn: json['lights']?['isOn'] ?? false,
        value: (json['lights']?['value'] ?? 0).toDouble(),
      ),
      airCondition: SmartDevice(
        isOn: json['airCondition']?['isOn'] ?? false,
        value: (json['airCondition']?['value'] ?? 0).toDouble(),
      ),
      timer: SmartDevice(
        isOn: json['timer']?['isOn'] ?? false,
        value: (json['timer']?['value'] ?? 0).toDouble(),
      ),
      musicInfo: MusicInfo(
        isOn: json['musicInfo']?['isOn'] ?? false,
        currentSong: Song.defaultSong,
      ),
      devices:
          (json['devices'] as List?)?.map((d) => Device.fromJson(d)).toList() ??
          [],
      sensors:
          (json['sensors'] as List?)?.map((s) => Sensor.fromJson(s)).toList() ??
          [],
      automationRules:
          (json['automationRules'] as List?)
              ?.map((a) => AutomationRule.fromJson(a))
              .toList() ??
          [],
    );
  }

  // Convert SmartRoom to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'temperature': temperature,
      'airHumidity': airHumidity,
      'lights': {'isOn': lights.isOn, 'value': lights.value},
      'airCondition': {'isOn': airCondition.isOn, 'value': airCondition.value},
      'timer': {'isOn': timer.isOn, 'value': timer.value},
      'musicInfo': {'isOn': musicInfo.isOn},
      'devices': devices.map((d) => d.toJson()).toList(),
      'sensors': sensors.map((s) => s.toJson()).toList(),
      'automationRules': automationRules.map((a) => a.toJson()).toList(),
    };
  }

  factory SmartRoom.fromApiResponse(
    Map<String, dynamic> roomData,
    String roomId,
  ) {
    final roomName = roomData['name'] ?? '';
    final loads = roomData['loads'] as List? ?? [];

    // Use a default image instead of empty string
    final imageUrl = roomData['imageUrl'] ?? '';

    // Initialize device collections
    final List<Device> devices = [];

    // Track device states
    bool lightsOn = false;
    double lightValue = 0;
    bool acOn = false;
    double acValue = 0;
    bool speakerOn = false;
    double temperature = 22.0;
    double humidity = 45.0;

    // Process each load
    for (var load in loads) {
      // Make sure the load has an ID
      if (load['id'] == null) continue;

      // Create Device object
      final device = Device.fromJson(load);
      devices.add(device);

      // Update room summary based on device category
      final category = load['category'] as String? ?? '';
      final isOn = load['isOn'] as bool? ?? false;
      final value = (load['value'] as num?)?.toDouble() ?? 0;

      switch (category) {
        case 'light':
        case 'dimmer':
        case 'switch':
          lightsOn = lightsOn || isOn;
          lightValue = value > 0 ? value : lightValue;
          break;

        case 'hvac':
        case 'airConditioner':
          acOn = acOn || isOn;
          acValue = value > 0 ? value : acValue;
          // Extract temperature from capabilities
          final capabilities =
              load['capabilities'] as Map<String, dynamic>? ?? {};
          if (capabilities['currentTemperature'] != null) {
            temperature = (capabilities['currentTemperature'] as num)
                .toDouble();
          }
          break;

        case 'speaker':
          speakerOn = speakerOn || isOn;
          break;
      }

      // Extract humidity from capabilities if available
      final capabilities = load['capabilities'] as Map<String, dynamic>? ?? {};
      if (capabilities['humidity'] != null) {
        humidity = (capabilities['humidity'] as num).toDouble();
      }
    }

    return SmartRoom(
      id: roomId,
      name: roomName,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : '',
      temperature: temperature,
      airHumidity: humidity,
      lights: SmartDevice(isOn: lightsOn, value: lightValue),
      airCondition: SmartDevice(isOn: acOn, value: acValue),
      timer: SmartDevice(isOn: false, value: 0),
      musicInfo: MusicInfo(isOn: speakerOn, currentSong: Song.defaultSong),
      devices: devices,
      sensors: [],
      automationRules: [],
    );
  }

  // Helper method to find real device by type
  Device? findDeviceByType(DeviceType type) {
    try {
      return devices.firstWhere((device) => device.type == type);
    } catch (e) {
      return null;
    }
  }

  // Helper to get all light devices
  List<Device> get lightDevices {
    return devices.where((device) => device.type == DeviceType.light).toList();
  }

  // Helper to get air conditioner device
  Device? get airConditionerDevice {
    try {
      return devices.firstWhere(
        (device) => device.type == DeviceType.airConditioner,
      );
    } catch (e) {
      return null;
    }
  }

  // Helper to get thermostat device
  Device? get thermostatDevice {
    try {
      return devices.firstWhere(
        (device) => device.type == DeviceType.thermostat,
      );
    } catch (e) {
      return null;
    }
  }

  // Helper to get TV device
  Device? get tvDevice {
    try {
      return devices.firstWhere((device) => device.type == DeviceType.tv);
    } catch (e) {
      return null;
    }
  }

  // Helper to get speaker device
  Device? get speakerDevice {
    try {
      return devices.firstWhere((device) => device.type == DeviceType.speaker);
    } catch (e) {
      return null;
    }
  }

  // Helper to get temperature sensor
  Sensor? get temperatureSensor {
    try {
      return sensors.firstWhere(
        (sensor) => sensor.type == SensorType.temperature,
      );
    } catch (e) {
      return null;
    }
  }

  // Helper to get humidity sensor
  Sensor? get humiditySensor {
    try {
      return sensors.firstWhere((sensor) => sensor.type == SensorType.humidity);
    } catch (e) {
      return null;
    }
  }

  // Helper to get motion sensor
  Sensor? get motionSensor {
    try {
      return sensors.firstWhere((sensor) => sensor.type == SensorType.motion);
    } catch (e) {
      return null;
    }
  }

  // Helper to get all online devices
  List<Device> get onlineDevices {
    return devices.where((device) => device.isOnline).toList();
  }

  // Helper to get all active devices (turned on)
  List<Device> get activeDevices {
    return devices.where((device) => device.isOn).toList();
  }

  // Helper to get device count
  int get deviceCount => devices.length;

  // Helper to get sensor count
  int get sensorCount => sensors.length;

  // Helper to get automation rule count
  int get automationRuleCount => automationRules.length;

  SmartRoom copyWith({
    String? id,
    String? name,
    String? imageUrl,
    double? temperature,
    double? airHumidity,
    SmartDevice? lights,
    SmartDevice? airCondition,
    SmartDevice? timer,
    MusicInfo? musicInfo,
    List<Device>? devices,
    List<Sensor>? sensors,
    List<AutomationRule>? automationRules,
  }) {
    return SmartRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      temperature: temperature ?? this.temperature,
      airHumidity: airHumidity ?? this.airHumidity,
      lights: lights ?? this.lights,
      airCondition: airCondition ?? this.airCondition,
      musicInfo: musicInfo ?? this.musicInfo,
      timer: timer ?? this.timer,
      devices: devices ?? this.devices,
      sensors: sensors ?? this.sensors,
      automationRules: automationRules ?? this.automationRules,
    );
  }

  // Create fake values with real devices
  static List<SmartRoom> get fakeValues => [
    livingRoom,
    diningRoom,
    kitchen,
    bedroom,
    bathroom,
    office,
    guestRoom,
  ];

  // Helper function to get icon for device type
  static IconData _getIconForDeviceType(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return Icons.lightbulb_outline;
      case DeviceType.airConditioner:
        return Icons.ac_unit;
      case DeviceType.thermostat:
        return Icons.thermostat;
      case DeviceType.smartPlug:
        return Icons.power;
      case DeviceType.fan:
        return Icons.toys;
      case DeviceType.tv:
        return Icons.tv;
      case DeviceType.speaker:
        return Icons.speaker;
      case DeviceType.camera:
        return Icons.videocam;
      case DeviceType.doorLock:
        return Icons.lock_outline;
      case DeviceType.windowBlind:
        return Icons.blinds;
      case DeviceType.other:
        return Icons.devices_other;
      case DeviceType.curtain:
        return Icons.curtains;
      case DeviceType.scene:
        return Icons.auto_awesome;
    }
  }

  // Helper function to get color for device type
  static Color _getColorForDeviceType(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return Colors.amber;
      case DeviceType.airConditioner:
        return Colors.blue;
      case DeviceType.thermostat:
        return Colors.teal;
      case DeviceType.smartPlug:
        return Colors.orange;
      case DeviceType.fan:
        return Colors.lightBlue;
      case DeviceType.tv:
        return Colors.purple;
      case DeviceType.speaker:
        return Colors.indigo;
      case DeviceType.camera:
        return Colors.red;
      case DeviceType.doorLock:
        return Colors.brown;
      case DeviceType.windowBlind:
        return Colors.green;
      case DeviceType.other:
        return Colors.grey;
      case DeviceType.curtain:
        return Colors.green;
      case DeviceType.scene:
        return Colors.pink;
    }
  }

  // Helper function to create device with proper mqttType
  static Device _createDevice({
    required String id,
    required String name,
    required DeviceType type,
    required String roomId,
    required String room,
    required bool isOn,
    required String sensortype,
    String? manufacturer,
    String? model,
    Map<String, dynamic>? capabilities,
    bool isOnline = true,
    bool isRGB = false,
    bool isDimmer = false,
  }) {
    final mqttType = _getMQTTTypeFromDeviceType(
      type,
      isDimmer: isDimmer,
      isRGB: isRGB,
    );

    return Device(
      id: id,
      name: name,
      type: type,
      mqttType: mqttType,
      roomId: roomId,
      room: room,
      icon: _getIconForDeviceType(type),
      color: _getColorForDeviceType(type),
      isOn: isOn,
      sensortype: sensortype,
      manufacturer: manufacturer,
      model: model,
      capabilities: capabilities ?? {},
      lastSeen: DateTime.now(),
      isOnline: isOnline,
    );
  }

  // Living Room with real devices
  static final livingRoom = SmartRoom(
    id: '1',
    name: 'LIVING ROOM',
    imageUrl: _imagesUrls[0],
    temperature: 22.5,
    airHumidity: 45.0,
    lights: SmartDevice(isOn: true, value: 20),
    timer: SmartDevice(isOn: false, value: 20),
    airCondition: SmartDevice(isOn: false, value: 10),
    musicInfo: MusicInfo(isOn: false, currentSong: Song.defaultSong),
    devices: [
      _createDevice(
        id: 'living_main_light',
        name: 'Main Light',
        type: DeviceType.light,
        roomId: '1',
        room: 'LIVING ROOM',
        isOn: true,
        sensortype: 'light',
        manufacturer: 'Philips',
        model: 'Hue White',
        capabilities: {
          'supportsIntensity': true,
          'supportsColor': false,
          'maxIntensity': 100,
        },
        isDimmer: true,
      ),
      _createDevice(
        id: 'living_floor_lamp',
        name: 'Floor Lamp',
        type: DeviceType.light,
        roomId: '1',
        room: 'LIVING ROOM',
        isOn: false,
        sensortype: 'light',
        manufacturer: 'IKEA',
        model: 'TRÅDFRI',
        capabilities: {
          'supportsIntensity': true,
          'supportsColor': true,
          'maxIntensity': 100,
        },
        isRGB: true,
      ),
      _createDevice(
        id: 'living_ac',
        name: 'Air Conditioner',
        type: DeviceType.airConditioner,
        roomId: '1',
        room: 'LIVING ROOM',
        isOn: true,
        sensortype: 'hvac',
        manufacturer: 'LG',
        model: 'ArtCool',
        capabilities: {
          'supportsTemperature': true,
          'supportsFanSpeed': true,
          'supportsModes': true,
          'minTemperature': 16,
          'maxTemperature': 30,
          'currentTemperature': 22,
        },
      ),
      _createDevice(
        id: 'living_tv',
        name: 'Smart TV',
        type: DeviceType.tv,
        roomId: '1',
        room: 'LIVING ROOM',
        isOn: false,
        sensortype: 'media',
        manufacturer: 'Samsung',
        model: 'QLED 55"',
        capabilities: {
          'supportsVolume': true,
          'supportsInput': true,
          'supportsPower': true,
        },
      ),
      _createDevice(
        id: 'living_speaker',
        name: 'Smart Speaker',
        type: DeviceType.speaker,
        roomId: '1',
        room: 'LIVING ROOM',
        isOn: true,
        sensortype: 'audio',
        manufacturer: 'Sonos',
        model: 'One SL',
        capabilities: {'supportsVolume': true, 'supportsPlayback': true},
      ),
      _createDevice(
        id: 'living_plug',
        name: 'Smart Plug',
        type: DeviceType.smartPlug,
        roomId: '1',
        room: 'LIVING ROOM',
        isOn: true,
        sensortype: 'power',
        manufacturer: 'TP-Link',
        model: 'Kasa HS100',
        capabilities: {'supportsPowerMonitoring': true, 'powerConsumption': 45},
      ),
    ],
    sensors: [
      Sensor(
        id: 'living_temp',
        name: 'Temperature Sensor',
        type: SensorType.temperature,
        roomId: '1',
        unit: '°C',
        currentValue: 22.5,
        minValue: 10,
        maxValue: 40,
        lastReading: DateTime.now(),
      ),
      Sensor(
        id: 'living_humidity',
        name: 'Humidity Sensor',
        type: SensorType.humidity,
        roomId: '1',
        unit: '%',
        currentValue: 45.0,
        minValue: 0,
        maxValue: 100,
        lastReading: DateTime.now(),
      ),
      Sensor(
        id: 'living_motion',
        name: 'Motion Sensor',
        type: SensorType.motion,
        roomId: '1',
        lastReading: DateTime.now(),
      ),
      Sensor(
        id: 'living_light',
        name: 'Light Sensor',
        type: SensorType.light,
        roomId: '1',
        unit: 'lux',
        currentValue: 350,
        minValue: 0,
        maxValue: 1000,
        lastReading: DateTime.now(),
      ),
    ],
    automationRules: [
      AutomationRule(
        id: 'auto_1',
        name: 'Motion Lights',
        description: 'Turn on lights when motion detected',
        triggerType: TriggerType.sensor,
        triggerConditions: {
          'sensorId': 'living_motion',
          'condition': 'motion_detected',
        },
        actionType: ActionType.toggleDevice,
        actionParameters: {
          'deviceId': 'living_main_light',
          'action': 'turn_on',
        },
        enabled: true,
        createdAt: DateTime.now(),
      ),
      AutomationRule(
        id: 'auto_2',
        name: 'Evening Dim',
        description: 'Dim lights at sunset',
        triggerType: TriggerType.time,
        triggerConditions: {'time': '18:00', 'days': 'mon,tue,wed,thu,fri'},
        actionType: ActionType.setDeviceValue,
        actionParameters: {'deviceId': 'living_main_light', 'value': 40},
        enabled: true,
        createdAt: DateTime.now(),
      ),
    ],
  );

  // Dining Room
  static final diningRoom = livingRoom.copyWith(
    id: '2',
    name: 'DINING ROOM',
    imageUrl: _imagesUrls[2],
    temperature: 21.0,
    airHumidity: 48.0,
    devices: [
      _createDevice(
        id: 'dining_chandelier',
        name: 'Chandelier',
        type: DeviceType.light,
        roomId: '2',
        room: 'DINING ROOM',
        isOn: false,
        sensortype: 'light',
        manufacturer: 'Philips',
        model: 'Hue White',
        capabilities: {
          'supportsIntensity': true,
          'supportsColor': false,
          'maxIntensity': 100,
        },
        isDimmer: true,
      ),
      _createDevice(
        id: 'dining_ac',
        name: 'Air Conditioner',
        type: DeviceType.airConditioner,
        roomId: '2',
        room: 'DINING ROOM',
        isOn: false,
        sensortype: 'hvac',
        manufacturer: 'Daikin',
        model: 'Premium',
        capabilities: {
          'supportsTemperature': true,
          'supportsFanSpeed': true,
          'minTemperature': 16,
          'maxTemperature': 30,
        },
      ),
    ],
    sensors: [
      Sensor(
        id: 'dining_temp',
        name: 'Temperature Sensor',
        type: SensorType.temperature,
        roomId: '2',
        unit: '°C',
        currentValue: 21.0,
        lastReading: DateTime.now(),
      ),
    ],
  );

  // Kitchen
  static final kitchen = livingRoom.copyWith(
    id: '3',
    name: 'KITCHEN',
    imageUrl: _imagesUrls[3],
    temperature: 23.5,
    airHumidity: 55.0,
    devices: [
      _createDevice(
        id: 'kitchen_ceiling',
        name: 'Ceiling Light',
        type: DeviceType.light,
        roomId: '3',
        room: 'KITCHEN',
        isOn: true,
        sensortype: 'light',
        manufacturer: 'Philips',
        model: 'Hue White',
        capabilities: {'supportsIntensity': true, 'maxIntensity': 100},
        isDimmer: true,
      ),
      _createDevice(
        id: 'kitchen_under_cabinet',
        name: 'Under Cabinet',
        type: DeviceType.light,
        roomId: '3',
        room: 'KITCHEN',
        isOn: false,
        sensortype: 'light',
        manufacturer: 'IKEA',
        model: 'TRÅDFRI',
      ),
      _createDevice(
        id: 'kitchen_exhaust',
        name: 'Exhaust Fan',
        type: DeviceType.fan,
        roomId: '3',
        room: 'KITCHEN',
        isOn: false,
        sensortype: 'fan',
        manufacturer: 'Broan',
        model: 'Quiet',
        capabilities: {'supportsFanSpeed': true, 'speeds': 3},
      ),
    ],
    sensors: [
      Sensor(
        id: 'kitchen_temp',
        name: 'Temperature Sensor',
        type: SensorType.temperature,
        roomId: '3',
        unit: '°C',
        currentValue: 23.5,
        lastReading: DateTime.now(),
      ),
      Sensor(
        id: 'kitchen_smoke',
        name: 'Smoke Detector',
        type: SensorType.smoke,
        roomId: '3',
        lastReading: DateTime.now(),
      ),
      Sensor(
        id: 'kitchen_gas',
        name: 'Gas Sensor',
        type: SensorType.gas,
        roomId: '3',
        lastReading: DateTime.now(),
      ),
    ],
  );

  // Bedroom
  static final bedroom = livingRoom.copyWith(
    id: '4',
    name: 'BEDROOM',
    imageUrl: _imagesUrls[4],
    temperature: 20.0,
    airHumidity: 50.0,
    devices: [
      _createDevice(
        id: 'bedroom_bedside_left',
        name: 'Bedside Lamp Left',
        type: DeviceType.light,
        roomId: '4',
        room: 'BEDROOM',
        isOn: false,
        sensortype: 'light',
        manufacturer: 'Philips',
        model: 'Hue White',
        capabilities: {
          'supportsIntensity': true,
          'supportsColor': true,
          'maxIntensity': 100,
        },
        isRGB: true,
      ),
      _createDevice(
        id: 'bedroom_bedside_right',
        name: 'Bedside Lamp Right',
        type: DeviceType.light,
        roomId: '4',
        room: 'BEDROOM',
        isOn: false,
        sensortype: 'light',
        manufacturer: 'Philips',
        model: 'Hue White',
        capabilities: {
          'supportsIntensity': true,
          'supportsColor': true,
          'maxIntensity': 100,
        },
        isRGB: true,
      ),
      _createDevice(
        id: 'bedroom_ac',
        name: 'Bedroom AC',
        type: DeviceType.airConditioner,
        roomId: '4',
        room: 'BEDROOM',
        isOn: true,
        sensortype: 'hvac',
        manufacturer: 'Mitsubishi',
        model: 'Silent',
        capabilities: {
          'supportsTemperature': true,
          'supportsFanSpeed': true,
          'supportsModes': true,
          'minTemperature': 16,
          'maxTemperature': 30,
          'currentTemperature': 20,
        },
      ),
      _createDevice(
        id: 'bedroom_blinds',
        name: 'Window Blinds',
        type: DeviceType.windowBlind,
        roomId: '4',
        room: 'BEDROOM',
        isOn: true,
        sensortype: 'cover',
        manufacturer: 'IKEA',
        model: 'FYRTUR',
        capabilities: {'supportsPosition': true, 'position': 30},
      ),
    ],
    sensors: [
      Sensor(
        id: 'bedroom_temp',
        name: 'Temperature Sensor',
        type: SensorType.temperature,
        roomId: '4',
        unit: '°C',
        currentValue: 20.0,
        lastReading: DateTime.now(),
      ),
    ],
  );

  // Bathroom
  static final bathroom = livingRoom.copyWith(
    id: '5',
    name: 'BATHROOM',
    imageUrl: _imagesUrls[1],
    temperature: 24.0,
    airHumidity: 65.0,
    devices: [
      _createDevice(
        id: 'bathroom_vanity',
        name: 'Vanity Light',
        type: DeviceType.light,
        roomId: '5',
        room: 'BATHROOM',
        isOn: false,
        sensortype: 'light',
        manufacturer: 'Philips',
        model: 'Hue White',
      ),
      _createDevice(
        id: 'bathroom_heater',
        name: 'Heater',
        type: DeviceType.thermostat,
        roomId: '5',
        room: 'BATHROOM',
        isOn: false,
        sensortype: 'heater',
        manufacturer: 'Myson',
        model: 'Electric',
        capabilities: {
          'supportsTemperature': true,
          'minTemperature': 10,
          'maxTemperature': 40,
        },
      ),
      _createDevice(
        id: 'bathroom_fan',
        name: 'Exhaust Fan',
        type: DeviceType.fan,
        roomId: '5',
        room: 'BATHROOM',
        isOn: true,
        sensortype: 'fan',
        manufacturer: 'Broan',
        model: 'Quiet',
        capabilities: {'supportsFanSpeed': true, 'speeds': 3},
      ),
    ],
    sensors: [
      Sensor(
        id: 'bathroom_humidity',
        name: 'Humidity Sensor',
        type: SensorType.humidity,
        roomId: '5',
        unit: '%',
        currentValue: 65.0,
        minValue: 0,
        maxValue: 100,
        lastReading: DateTime.now(),
      ),
      Sensor(
        id: 'bathroom_temp',
        name: 'Temperature Sensor',
        type: SensorType.temperature,
        roomId: '5',
        unit: '°C',
        currentValue: 24.0,
        lastReading: DateTime.now(),
      ),
    ],
  );

  // Office
  static final office = livingRoom.copyWith(
    id: '6',
    name: 'OFFICE',
    imageUrl: _imagesUrls.isNotEmpty ? _imagesUrls[0] : '',
    temperature: 21.5,
    airHumidity: 42.0,
    devices: [
      _createDevice(
        id: 'office_desk_light',
        name: 'Desk Lamp',
        type: DeviceType.light,
        roomId: '6',
        room: 'OFFICE',
        isOn: true,
        sensortype: 'light',
        manufacturer: 'Xiaomi',
        model: 'Mi Desk Lamp',
        capabilities: {
          'supportsIntensity': true,
          'supportsColor': true,
          'maxIntensity': 100,
        },
        isRGB: true,
      ),
      _createDevice(
        id: 'office_ac',
        name: 'Office AC',
        type: DeviceType.airConditioner,
        roomId: '6',
        room: 'OFFICE',
        isOn: true,
        sensortype: 'hvac',
        manufacturer: 'LG',
        model: 'Split',
        capabilities: {
          'supportsTemperature': true,
          'supportsFanSpeed': true,
          'currentTemperature': 21,
        },
      ),
    ],
    sensors: [
      Sensor(
        id: 'office_temp',
        name: 'Temperature Sensor',
        type: SensorType.temperature,
        roomId: '6',
        unit: '°C',
        currentValue: 21.5,
        lastReading: DateTime.now(),
      ),
    ],
  );

  // Guest Room
  static final guestRoom = livingRoom.copyWith(
    id: '7',
    name: 'GUEST ROOM',
    imageUrl: _imagesUrls.isNotEmpty ? _imagesUrls[4] : '',
    temperature: 20.5,
    airHumidity: 48.0,
    devices: [
      _createDevice(
        id: 'guest_light',
        name: 'Main Light',
        type: DeviceType.light,
        roomId: '7',
        room: 'GUEST ROOM',
        isOn: false,
        sensortype: 'light',
        manufacturer: 'Philips',
        model: 'Hue',
      ),
    ],
    sensors: [
      Sensor(
        id: 'guest_temp',
        name: 'Temperature Sensor',
        type: SensorType.temperature,
        roomId: '7',
        unit: '°C',
        currentValue: 20.5,
        lastReading: DateTime.now(),
      ),
    ],
  );
}

const _imagesUrls = [
  'assets/images/0.jpeg',
  'assets/images/1.jpeg',
  'assets/images/2.jpeg',
  'assets/images/3.jpeg',
  'assets/images/4.jpeg',
];
