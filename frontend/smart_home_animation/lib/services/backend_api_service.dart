// lib/services/backend_api_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/constants.dart';
import 'mdns_discovery.dart';

class BackendApiService extends ChangeNotifier {
  bool _isConnected = false;
  bool _isLoading = false;
  String? _error;
  String? _currentIp;

  final MDNSDiscovery _mdns = MDNSDiscovery();
  final Map<String, Map<String, dynamic>> _devices = {};
  final Map<String, dynamic> _rooms = {};

  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentIp => _currentIp;
  Map<String, Map<String, dynamic>> get devices => _devices;
  Map<String, dynamic> get rooms => _rooms;

  Future<void> initialize() async {
    // Setup MDNS callbacks with proper signature
    _mdns.addListener((String ip, {String? mac}) {
      print('📍 MDNS found device at: $ip');
      if (mac != null) {
        print('   📡 MAC Address: $mac');
      }
      _currentIp = ip;
      Constants.updateBaseUrl(ip);
      connect();
    });

    // Start continuous discovery
    _mdns.startBackgroundDiscovery();

    // Also try common IPs as fallback
    await MDNSDiscovery.commonIPs;

    // Initial connection attempt
    await connect();
  }

  Future<bool> connect() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse(Constants.health);
      print('🔌 Connecting to: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _isConnected = true;
        _currentIp = Constants.currentIp;
        await loadRoomsAndDevices();
        print('✅ Connected to backend at ${Constants.localHost}');
        return true;
      } else {
        _error = 'Backend returned ${response.statusCode}';
        _isConnected = false;
        return false;
      }
    } catch (e) {
      print('❌ Backend connection error: $e');
      _error = e.toString();
      _isConnected = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRoomsAndDevices() async {
    if (!_isConnected) return;

    try {
      final roomsResponse = await http.get(Uri.parse(Constants.rooms));
      if (roomsResponse.statusCode == 200) {
        final roomsData = json.decode(roomsResponse.body);
        if (roomsData['success'] == true) {
          final roomsList = roomsData['data'] as List;

          _rooms.clear();
          _devices.clear();

          for (var room in roomsList) {
            final roomId = room['id'].toString();
            final roomName = room['name'];

            final devicesResponse = await http.get(
              Uri.parse(Constants.roomLoads(roomId)),
            );

            if (devicesResponse.statusCode == 200) {
              final devicesData = json.decode(devicesResponse.body);
              if (devicesData['success'] == true) {
                final loads = devicesData['data']['loads'] as List;

                _rooms[roomName] = {
                  'id': roomId,
                  'name': roomName,
                  'loads': [],
                };

                for (var load in loads) {
                  final deviceId = load['id'].toString();
                  _devices[deviceId] = {
                    'id': deviceId,
                    'name': load['name'],
                    'type': load['type'],
                    'isOn': load['isOn'] ?? false,
                    'brightness': load['brightness'],
                    'position': load['position'],
                  };
                  _rooms[roomName]['loads'].add(deviceId);
                }
              }
            }
          }

          notifyListeners();
          print(
            '✅ Loaded ${_devices.length} devices in ${_rooms.length} rooms',
          );
        }
      }
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> sendCommand(
    String deviceId,
    String command, {
    dynamic value,
  }) async {
    if (!_isConnected) return;

    try {
      final response = await http
          .post(
            Uri.parse(Constants.deviceCommand(deviceId)),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'command': command, 'value': value}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          if (_devices.containsKey(deviceId)) {
            if (command == 'ON') {
              _devices[deviceId]?['isOn'] = true;
            } else if (command == 'OFF') {
              _devices[deviceId]?['isOn'] = false;
            } else if (command == 'SET_BRIGHTNESS') {
              _devices[deviceId]?['brightness'] = value;
            }
            notifyListeners();
          }
          print('✅ Command sent: $command to $deviceId');
        }
      }
    } catch (e) {
      print('Error sending command: $e');
    }
  }

  @override
  void dispose() {
    _mdns.dispose();
    super.dispose();
  }
}
