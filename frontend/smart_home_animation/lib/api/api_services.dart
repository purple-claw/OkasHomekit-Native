// api_services.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home_animation/core/shared/domain/entities/smart_room.dart';

class ApiService {
  String _baseUrl;

  ApiService({required String baseUrl}) : _baseUrl = baseUrl;

  String get baseUrl => _baseUrl;

  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
    debugPrint('API base URL updated to: $_baseUrl');
  }

  // Get all rooms with their loads (Full data)
  Future<List<SmartRoom>> getAllRoomsWithLoads() async {
    try {
      final url = '$_baseUrl/api/rooms';
      debugPrint('Fetching rooms from: $url');

      final response = await http.get(Uri.parse(url));

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch rooms: HTTP ${response.statusCode}');
      }

      final Map<String, dynamic> responseData = json.decode(response.body);
      debugPrint('Response data: $responseData');

      List<dynamic> roomsList = [];

      // Check if the response has a 'data' field
      if (responseData.containsKey('data')) {
        final dataValue = responseData['data'];
        if (dataValue is List) {
          roomsList = dataValue;
          debugPrint('Found ${roomsList.length} rooms in data field');
        } else {
          debugPrint('Data field is not a list: ${dataValue.runtimeType}');
        }
      } else {
        debugPrint('No data field found in response');
      }

      final List<SmartRoom> allRooms = [];

      for (var room in roomsList) {
        final roomId = room['id']?.toString() ?? '';
        final roomName = room['name'] ?? 'Unknown';

        if (roomId.isEmpty) {
          debugPrint('⚠️ Skipping room with no ID: $roomName');
          continue;
        }

        debugPrint('Processing room: $roomName (ID: $roomId)');

        try {
          final loads = room['loads'] as List? ?? [];
          debugPrint('Room $roomName has ${loads.length} loads');

          final smartRoom = SmartRoom.fromApiResponse(room, roomId);
          allRooms.add(smartRoom);
          debugPrint(
            '✅ Loaded: $roomName with ${smartRoom.devices.length} devices',
          );
        } catch (e) {
          debugPrint('❌ Error loading room $roomName: $e');
          debugPrint('Room data: $room');
        }
      }

      debugPrint('✅ Successfully loaded ${allRooms.length} rooms');
      return allRooms;
    } catch (e) {
      debugPrint('❌ Error in getAllRoomsWithLoads: $e');
      return [];
    }
  }

  // Get a single room by ID with loads
  Future<SmartRoom> getRoomWithLoadsById(String roomId) async {
    try {
      final url = '$_baseUrl/api/rooms/$roomId/loads';
      debugPrint('Fetching room from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final roomData = responseData['data'];
          return SmartRoom.fromApiResponse(roomData, roomId);
        } else {
          throw Exception('API error: ${responseData['error']}');
        }
      } else {
        throw Exception('Failed to load room: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in getRoomWithLoadsById: $e');
      throw Exception('Failed to load room: $e');
    }
  }

  // Get all rooms (basic info)
  Future<List<Map<String, dynamic>>> getRooms() async {
    try {
      final url = '$_baseUrl/api/rooms';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting rooms: $e');
      return [];
    }
  }

  // Get loads for a specific room
  Future<Map<String, dynamic>> getRoomLoads(String roomId) async {
    try {
      final url = '$_baseUrl/api/rooms/$roomId/loads';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return {};
    } catch (e) {
      debugPrint('Error getting room loads: $e');
      return {};
    }
  }

  // Get all loads with UI hints
  Future<List<Map<String, dynamic>>> getLoadDetails() async {
    try {
      final url = '$_baseUrl/api/load-details';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting load details: $e');
      return [];
    }
  }

  // Get categories with UI controls
  Future<Map<String, dynamic>> getCategories() async {
    try {
      final url = '$_baseUrl/api/categories';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return {};
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return {};
    }
  }

  // Get system signature
  Future<Map<String, dynamic>> getSignature() async {
    try {
      final url = '$_baseUrl/api/signature';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return {};
    } catch (e) {
      debugPrint('Error getting signature: $e');
      return {};
    }
  }

  // Configure KNX gateway
  Future<bool> configureKNXGateway(String ip, int port) async {
    try {
      final url = '$_baseUrl/api/configure';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'knx_gateway': ip, 'knx_port': port}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error configuring KNX gateway: $e');
      return false;
    }
  }

  // Send command to device
  Future<bool> sendDeviceCommand(
    String deviceId,
    String command, {
    dynamic value,
  }) async {
    try {
      final url = '$_baseUrl/api/devices/$deviceId/command';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'command': command, 'value': value}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending command: $e');
      return false;
    }
  }

  // Start pairing process
  Future<Map<String, dynamic>> startPairing() async {
    try {
      final url = '$_baseUrl/api/pairing/start';
      final response = await http.post(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return {};
    } catch (e) {
      debugPrint('Error starting pairing: $e');
      return {};
    }
  }

  // Complete pairing process
  Future<bool> completePairing(
    String sessionId,
    List<Map<String, dynamic>> assignments,
  ) async {
    try {
      final url = '$_baseUrl/api/pairing/complete';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'sessionId': sessionId, 'assignments': assignments}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error completing pairing: $e');
      return false;
    }
  }

  // Verify signatures
  Future<Map<String, dynamic>> verifySignatures(
    List<Map<String, dynamic>> signatures,
  ) async {
    try {
      final url = '$_baseUrl/api/verify';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'signatures': signatures}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return {};
    } catch (e) {
      debugPrint('Error verifying signatures: $e');
      return {};
    }
  }

  // Health check
  Future<bool> healthCheck() async {
    try {
      final url = '$_baseUrl/api/health';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  // Get system info
  Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final url = '$_baseUrl/api/info';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return {};
    } catch (e) {
      debugPrint('Error getting system info: $e');
      return {};
    }
  }
}
