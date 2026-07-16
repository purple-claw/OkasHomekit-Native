// lib/api/api_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home_animation/api/constants.dart';
import 'package:smart_home_animation/services/mdns_resolver.dart';

final connect = GetConnect();

//======Post API's================
class AuthService {
  static String? _token;
  static String? _refreshToken;

  static String? get token => _token;
  static String? get refreshToken => _refreshToken;
}

//=======post api configure=======
// Configure KNX gateway
Future<bool> configureKNXGateway(String ip, int port) async {
  try {
    final response = await http.post(
      Uri.parse('${Constants.localHost}/api/configure'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'knx_gateway': ip, 'knx_port': port}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == true;
    }
    return false;
  } catch (e) {
    print('Error configuring KNX gateway: $e');
    return false;
  }
}

// Get all loads with UI hints
Future<List<Map<String, dynamic>>> getLoadDetails() async {
  try {
    final response = await http.get(
      Uri.parse('${Constants.localHost}/api/load-details'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    return [];
  } catch (e) {
    print('Error getting load details: $e');
    return [];
  }
}

//======= get all loads ===========
Future<List<Map<String, dynamic>>> getLoads() async {
  try {
    final response = await http.get(
      Uri.parse('${Constants.localHost}/api/loads'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] == true) {
        debugPrint("Fetched ${data['data'].length} loads");
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    return [];
  } catch (e) {
    debugPrint("Error in getLoads: $e");
    return [];
  }
}

//=======get room by id with loads=======
Future<Map<String, dynamic>> getRoomsByID(String roomId) async {
  try {
    final response = await http.get(
      Uri.parse('${Constants.localHost}/api/rooms/$roomId/loads'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      debugPrint("API Response for room $roomId: $responseData");

      if (responseData['success'] == true) {
        return responseData['data'];
      }
    }
    return {};
  } catch (e) {
    debugPrint("Error in getRoomsByID: $e");
    return {};
  }
}

//=======get categories=========
Future<Map<String, dynamic>> getCategories() async {
  try {
    final response = await http.get(
      Uri.parse('${Constants.localHost}/api/categories'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        debugPrint("Fetched categories successfully");
        return responseData['data'];
      }
    }
    return {};
  } catch (e) {
    debugPrint("Error in getCategories: $e");
    return {};
  }
}

//=======get all Rooms=========
Future<List<Map<String, dynamic>>> getRooms() async {
  try {
    final response = await http.get(
      Uri.parse('${Constants.localHost}/api/rooms'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        debugPrint("Fetched ${data['data'].length} rooms");
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    return [];
  } catch (e) {
    print('Error getting rooms: $e');
    return [];
  }
}

// Get loads for a specific room
Future<List<Map<String, dynamic>>> getRoomLoads(String roomId) async {
  try {
    final response = await http.get(
      Uri.parse('${Constants.localHost}/api/rooms/$roomId/loads'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final roomData = data['data'];
        debugPrint(
          "Room ${roomData['room']} has ${roomData['loads'].length} loads",
        );
        return List<Map<String, dynamic>>.from(roomData['loads']);
      }
    }
    return [];
  } catch (e) {
    print('Error getting room loads: $e');
    return [];
  }
}

// Send command to device
Future<bool> sendDeviceCommand(
  String deviceId,
  String command, {
  dynamic value,
}) async {
  try {
    final response = await http.post(
      Uri.parse('${Constants.localHost}/api/devices/$deviceId/command'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'command': command, 'value': value}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == true;
    }
    return false;
  } catch (e) {
    print('Error sending command: $e');
    return false;
  }
}

// Get MQTT status
Future<Map<String, dynamic>> getMQTTStatus() async {
  try {
    final response = await http.get(
      Uri.parse('${Constants.localHost}/api/mqtt/status'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {};
  } catch (e) {
    print('Error getting MQTT status: $e');
    return {};
  }
}

// Get device status
Future<Map<String, dynamic>> getDeviceStatus() async {
  try {
    final response = await http.get(
      Uri.parse('${Constants.localHost}/api/device/status'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {};
  } catch (e) {
    print('Error getting device status: $e');
    return {};
  }
}

// Resolve mDNS host to IP and update constants (optional utility)
Future<String?> resolveMDNSHost(String hostname) async {
  final ip = await MDNSResolver.resolveHost(hostname);
  if (ip != null) {
    print('Resolved $hostname to $ip');
    return ip;
  }
  return null;
}

// Discover devices via mDNS
Future<List<Map<String, dynamic>>> discoverDevices() async {
  try {
    final response = await http.get(
      Uri.parse('${Constants.localHost}/api/discover'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['devices']);
      }
    }
    return [];
  } catch (e) {
    print('Error discovering devices: $e');
    return [];
  }
}
