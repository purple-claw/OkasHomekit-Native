// lib/test/api_test_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_home_animation/api/constants.dart';

class APITestScreen extends StatefulWidget {
  const APITestScreen({super.key});

  @override
  State<APITestScreen> createState() => _APITestScreenState();
}

class _APITestScreenState extends State<APITestScreen> {
  String _result = "Testing...";

  Future<void> testAPI() async {
    setState(() {
      _result = "Testing connection...";
    });

    try {
      // Test health endpoint
      final healthResponse = await http.get(
        Uri.parse('${Constants.localHost}/api/health'),
      );
      _result = "Health: ${healthResponse.statusCode}\n";

      // Test rooms endpoint
      final roomsResponse = await http.get(Uri.parse(Constants.rooms));
      if (roomsResponse.statusCode == 200) {
        final data = json.decode(roomsResponse.body);
        _result += "Rooms: ${data['data']?.length ?? 0} rooms found\n";

        if (data['data'] != null && data['data'].isNotEmpty) {
          for (var room in data['data']) {
            _result += "  - ${room['name']} (ID: ${room['id']})\n";

            // Test room loads
            final loadsResponse = await http.get(
              Uri.parse(Constants.roomLoads(room['id'].toString())),
            );
            if (loadsResponse.statusCode == 200) {
              final loadsData = json.decode(loadsResponse.body);
              final loads = loadsData['data']?['loads'] ?? [];
              _result += "    Loads: ${loads.length}\n";
              for (var load in loads) {
                _result +=
                    "      • ${load['name']} (${load['type']}) - ${load['isOn'] == true ? 'ON' : 'OFF'}\n";
              }
            }
          }
        }
      } else {
        _result += "Rooms failed: ${roomsResponse.statusCode}";
      }
    } catch (e) {
      _result += "Error: $e";
    } finally {
      setState(() {
        _result += "\nDone.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: testAPI,
              child: const Text('Test API Connection'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _result,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
