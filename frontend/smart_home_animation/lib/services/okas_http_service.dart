// lib/services/okas_http_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OKASHttpService extends ChangeNotifier {
  static const String OKAS_IP = '192.168.1.152'; // Updated
  static const int HTTP_PORT = 80;

  bool _isConnected = false;
  bool _isLoading = false;
  String? _error;

  final Map<String, Map<String, dynamic>> _devices = {};
  final Map<String, dynamic> _rooms = {};

  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, Map<String, dynamic>> get devices => _devices;
  Map<String, dynamic> get rooms => _rooms;

  Future<bool> connect() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final healthUrl = Uri.parse('http://$OKAS_IP:$HTTP_PORT/api/health');
      final response = await http
          .get(healthUrl)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _isConnected = true;
        await loadLoads();
        return true;
      } else {
        _error = 'Device returned status ${response.statusCode}';
        _isConnected = false;
        return false;
      }
    } catch (e) {
      print('HTTP connection error: $e');
      _error = e.toString();
      _isConnected = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLoads() async {
    try {
      final url = Uri.parse('http://$OKAS_IP:$HTTP_PORT/api/loads');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final loads = data['data'] as List;
          _processLoads(loads);
        } else if (data is List) {
          _processLoads(data);
        }
      } else {
        print('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading loads: $e');
    }
  }

  void _processLoads(List loads) {
    _devices.clear();
    _rooms.clear();

    for (int i = 0; i < loads.length; i++) {
      final load = loads[i];
      final loadId = load['id']?.toString() ?? (i + 1).toString();

      _devices[loadId] = {
        'id': loadId,
        'name': load['name'] ?? 'Unknown',
        'type': load['type'] ?? 'swt',
        'isOn': load['isOn'] ?? false,
        'brightness': load['brightness'],
        'position': load['position'],
        'roomId': load['roomId']?.toString() ?? '0',
      };

      final roomName = _extractRoomName(load['name'] ?? '');
      if (!_rooms.containsKey(roomName)) {
        _rooms[roomName] = {
          'id': roomName.toLowerCase().replaceAll(' ', '_'),
          'name': roomName,
          'loads': [],
        };
      }
      _rooms[roomName]['loads'].add(loadId);
    }

    notifyListeners();
    print('✅ Loaded ${_devices.length} devices in ${_rooms.length} rooms');
  }

  String _extractRoomName(String loadName) {
    if (loadName.contains('Seating') || loadName.contains('Big'))
      return 'Big HT';
    if (loadName.contains('Middle') || loadName.contains('Display'))
      return 'Display Area';
    if (loadName.contains('Lounge')) return 'Lounge';
    if (loadName.contains('Small')) return 'Small HT';
    if (loadName.contains('Kitchen')) return 'Kitchen';
    if (loadName.contains('Bedroom')) return 'Bedroom';
    if (loadName.contains('Living')) return 'Living Room';
    return 'General';
  }

  Future<void> sendCommand(
    String deviceId,
    String command, {
    dynamic value,
  }) async {
    try {
      final url = Uri.parse(
        'http://$OKAS_IP:$HTTP_PORT/api/devices/$deviceId/command',
      );
      final response = await http
          .post(
            url,
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
}
