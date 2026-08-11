// lib/services/device_provider.dart
// ignore_for_file: unused_field, unused_element

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home_animation/core/shared/domain/entities/device_command.dart';
import 'package:smart_home_animation/core/shared/domain/entities/music_info.dart';
import 'package:smart_home_animation/core/shared/domain/entities/smart_device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/smart_room.dart';
import 'package:smart_home_animation/services/api_services.dart';

import '../core/shared/domain/entities/device.dart';
import '../core/shared/domain/entities/device_state.dart';
import 'connection_service.dart';
import 'i_device_service.dart';
import 'package:smart_home_animation/core/shared/presentation/widgets/glass_panel.dart';

class DeviceProvider extends ChangeNotifier {
  final IDeviceService _deviceService;
  final ConnectionService? _connectionService;
  final dynamic _apiService;

  Stream<DeviceState> get deviceStateStream => _deviceService.deviceStateStream;

  final Map<String, Device> _devices = {};
  final Map<String, DeviceState> _deviceStates = {};
  final Map<String, SmartRoom> _rooms = {};

  bool _isConnected = false;
  bool _isLoading = false;
  String? _error;

  DeviceProvider(
    this._deviceService, {
    ConnectionService? connectionService,
    dynamic apiService,
  }) : _connectionService = connectionService,
       _apiService = apiService;

  Map<String, Device> get devices => Map.unmodifiable(_devices);
  Map<String, DeviceState> get deviceStates => Map.unmodifiable(_deviceStates);
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Device> getDevicesByRoom(String roomId) {
    return _devices.values.where((device) => device.roomId == roomId).toList();
  }

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _isConnected = await _deviceService.connect();

      if (_isConnected) {
        _deviceService.deviceStateStream.listen((state) {
          _deviceStates[state.deviceId] = state;
          notifyListeners();
        });

        await loadDevicesFromAPI();

        if (_connectionService != null) {
          await _connectionService.saveConnectionStatus(true);
        }
      } else {
        _error = 'Failed to connect to backend';
      }
    } catch (e) {
      _error = 'Initialization error: $e';
      debugPrint('DeviceProvider initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestSync() async {
    if (_connectionService == null || _connectionService.baseUrl == null) {
      debugPrint('Connection service not available');
      return;
    }

    try {
      final url = Uri.parse('${_connectionService.baseUrl}/api/sync/request');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('Sync requested successfully');
          // Reload devices after sync
          await loadDevicesFromAPI();
        }
      }
    } catch (e) {
      debugPrint('Error requesting sync: $e');
    }
  }

  Future<void> checkSyncStatus(BuildContext context) async {
    if (_connectionService == null || _connectionService.baseUrl == null) {
      return;
    }

    try {
      final url = Uri.parse(
        '${_connectionService.baseUrl}/api/signature/status',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data']['needsSync'] == true) {
          _showSyncRequiredDialog(context);
        }
      }
    } catch (e) {
      debugPrint('Error checking sync status: $e');
    }
  }

  void _showSyncRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FrostedAlertDialog(
        title: const Text('Sync Required'),
        content: const Text(
          'The device configuration has changed. Please sync to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              await requestSync();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
  }

  // Also add this method to discover devices via mDNS
  Future<List<Map<String, dynamic>>> discoverDevicesViaMDNS() async {
    if (_connectionService == null || _connectionService.baseUrl == null) {
      return [];
    }

    try {
      final url = Uri.parse(
        '${_connectionService.baseUrl}/api/discover/devices',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']['devices']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error discovering devices: $e');
      return [];
    }
  }

  // Method to manually set device IP
  Future<bool> setDeviceIP(String ip, {int port = 1884}) async {
    if (_connectionService == null || _connectionService.baseUrl == null) {
      return false;
    }

    try {
      final url = Uri.parse(
        '${_connectionService.baseUrl}/api/discover/set-device',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ip': ip, 'port': port}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('Device IP set to $ip:$port');
          // Reload devices after changing IP
          await loadDevicesFromAPI();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error setting device IP: $e');
      return false;
    }
  }

  Future<void> loadDevicesFromAPI() async {
    if (_connectionService == null || _connectionService.baseUrl == null) {
      debugPrint('Connection service not available');
      return;
    }

    try {
      final url = Uri.parse('${_connectionService.baseUrl}/loads');
      final response = await http.get(url);

      debugPrint('Load devices response status: ${response.statusCode}');
      debugPrint('Load devices response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Load devices data: $data');

        if (data['success'] == true) {
          final devicesList = data['data'] as List;
          debugPrint('Found ${devicesList.length} devices in API');

          for (var deviceJson in devicesList) {
            final device = Device.fromJson(deviceJson);
            _devices[device.id] = device;
            debugPrint('Added device: ${device.name} (${device.id})');
          }
          notifyListeners();
          debugPrint('Loaded ${_devices.length} devices from API');
        } else {
          debugPrint('API returned error: ${data['error']}');
        }
      } else {
        debugPrint('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading devices from API: $e');
    }
  }

  Future<void> sendCommand(
    String deviceId,
    String command, {
    dynamic value,
  }) async {
    if (_connectionService == null || _connectionService.baseUrl == null)
      return;

    try {
      final url = Uri.parse(
        '${_connectionService.baseUrl}/devices/$deviceId/command',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'command': command, 'value': value}),
      );

      if (response.statusCode == 200) {
        debugPrint('Command sent: $command to $deviceId');
      }
    } catch (e) {
      debugPrint('Error sending command: $e');
    }
  }

  Future<void> toggleDevice(String deviceId, bool value) async {
    await sendCommand(deviceId, value ? 'ON' : 'OFF');
  }

  Future<void> setLightIntensity(String deviceId, double intensity) async {
    await sendCommand(deviceId, 'SET_BRIGHTNESS', value: intensity.toInt());
  }

  Future<void> setTemperature(String deviceId, double temperature) async {
    await sendCommand(deviceId, 'SET_TEMPERATURE', value: temperature.toInt());
  }

  DeviceState? getDeviceState(String deviceId) {
    return _deviceStates[deviceId];
  }

  Device? getDevice(String deviceId) {
    return _devices[deviceId];
  }

  Future<void> configureSensorTrigger({
    required String sensorId,
    required String deviceId,
    required String condition,
    required dynamic value,
    required String action,
  }) async {
    try {
      // Find the room that contains this device - safely handle not found
      SmartRoom? room;
      for (var r in _rooms.values) {
        if (r.devices.any((d) => d.id == deviceId)) {
          room = r;
          break;
        }
      }

      final url = Uri.parse(
        '${_connectionService?.baseUrl}/api/automation/rules',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sensorId': sensorId,
          'deviceId': deviceId,
          'condition': condition,
          'value': value,
          'action': action,
          'roomId': room?.id,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Automation rule configured successfully');
      } else {
        debugPrint(
          'Failed to configure automation rule: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error configuring automation rule: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAutomationRules() async {
    if (_connectionService == null || _connectionService.baseUrl == null) {
      return [];
    }

    try {
      final url = Uri.parse(
        '${_connectionService.baseUrl}/api/automation/rules',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting automation rules: $e');
      return [];
    }
  }

  Future<void> deleteAutomationRule(String ruleId) async {
    if (_connectionService == null || _connectionService.baseUrl == null)
      return;

    try {
      final url = Uri.parse(
        '${_connectionService.baseUrl}/api/automation/rules/$ruleId',
      );
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        debugPrint('Automation rule deleted successfully');
      }
    } catch (e) {
      debugPrint('Error deleting automation rule: $e');
    }
  }

  Future<void> setFanSpeed(String deviceId, double fanSpeed) async {
    final command = DeviceCommand(
      deviceId: deviceId,
      command: 'SET_FAN_SPEED',
      value: fanSpeed.toString(),
      timestamp: DateTime.now(),
    );
    await _deviceService.sendCommand(command);
  }

  Future<void> setMode(String deviceId, String mode) async {
    final command = DeviceCommand(
      deviceId: deviceId,
      command: 'SET_MODE',
      value: mode,
      timestamp: DateTime.now(),
    );
    await _deviceService.sendCommand(command);
  }

  Future<List<SmartRoom>> loadAllRooms() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First check if backend is reachable
      final mqttStatus = await getMQTTStatus();
      debugPrint('MQTT Status: $mqttStatus');

      if (mqttStatus['connected'] != true) {
        _error = 'Backend not connected to OKAS device';
        _isLoading = false;
        notifyListeners();
        return [];
      }

      // Get rooms from API
      final roomsList = await getRooms();
      debugPrint('Rooms from API: $roomsList');

      final List<SmartRoom> rooms = [];

      for (var roomJson in roomsList) {
        final roomId = roomJson['id'].toString();
        final roomName = roomJson['name'];

        // Get loads for this room
        final loads = await getRoomLoads(roomId);
        debugPrint('Room $roomName has ${loads.length} loads');

        // Create devices from loads
        final devices = loads
            .map(
              (load) => Device(
                id: load['id'].toString(),
                name: load['name'],
                type: _getDeviceTypeFromString(load['type'] ?? 'swt'),
                mqttType: _getMQTTTypeFromString(load['type'] ?? 'swt'),
                roomId: roomId,
                room: roomName,
                icon: Icons.lightbulb_outline,
                color: Colors.amber,
                isOn: load['isOn'] ?? false,
                sensortype: load['type'] ?? 'light',
                lastSeen: DateTime.now(),
                isOnline: true,
                brightness: load['brightness'],
                colorTemp: load['colorTemp'],
              ),
            )
            .toList();

        // Create SmartRoom
        final room = SmartRoom(
          id: roomId,
          name: roomName,
          imageUrl: '',
          temperature: 22.0,
          airHumidity: 45.0,
          lights: SmartDevice(isOn: false, value: 0),
          airCondition: SmartDevice(isOn: false, value: 0),
          timer: SmartDevice(isOn: false, value: 0),
          musicInfo: MusicInfo(isOn: false, currentSong: Song.defaultSong),
          devices: devices,
          sensors: [],
          automationRules: [],
        );

        rooms.add(room);
        _rooms[roomId] = room;

        // Update devices cache
        for (var device in devices) {
          _devices[device.id] = device;
        }
      }

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ Loaded ${rooms.length} rooms');
      return rooms;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading all rooms: $e');
      return [];
    }
  }

  DeviceType _getDeviceTypeFromString(String type) {
    switch (type) {
      case 'swt':
        return DeviceType.light;
      case 'dim':
        return DeviceType.light;
      case 'rgb':
        return DeviceType.light;
      case 'tun':
        return DeviceType.light;
      case 'hvc':
        return DeviceType.airConditioner;
      case 'fan':
        return DeviceType.fan;
      case 'cur':
        return DeviceType.windowBlind;
      default:
        return DeviceType.light;
    }
  }

  MQTTDeviceType _getMQTTTypeFromString(String type) {
    switch (type) {
      case 'swt':
        return MQTTDeviceType.swt;
      case 'dim':
        return MQTTDeviceType.dim;
      case 'rgb':
        return MQTTDeviceType.rgb;
      case 'tun':
        return MQTTDeviceType.tun;
      case 'hvc':
        return MQTTDeviceType.hvc;
      case 'fan':
        return MQTTDeviceType.fan;
      case 'cur':
        return MQTTDeviceType.cur;
      default:
        return MQTTDeviceType.swt;
    }
  }

  Future<List<SmartRoom>> _loadRoomsViaHttp() async {
    if (_connectionService == null || _connectionService.baseUrl == null) {
      return [];
    }

    try {
      final url = Uri.parse('${_connectionService.baseUrl}/rooms');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final roomsList = data['data'] as List;
          final List<SmartRoom> rooms = [];

          for (var roomJson in roomsList) {
            final roomId = roomJson['id'].toString();
            final loadsUrl = Uri.parse(
              '${_connectionService.baseUrl}/rooms/$roomId/loads',
            );
            final loadsResponse = await http.get(loadsUrl);

            if (loadsResponse.statusCode == 200) {
              final loadsData = json.decode(loadsResponse.body);
              if (loadsData['success'] == true) {
                final roomData = loadsData['data'];
                final room = SmartRoom.fromApiResponse(roomData, roomId);
                rooms.add(room);
              }
            }
          }
          return rooms;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error loading rooms via HTTP: $e');
      return [];
    }
  }

  Future<void> loadDevices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await loadAllRooms();
    } catch (e) {
      _error = 'Failed to load devices: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMQTTCommand(DeviceCommand command) async {
    await _deviceService.sendCommand(command);
  }

  @override
  void dispose() {
    _deviceService.disconnect();
    super.dispose();
  }
}
