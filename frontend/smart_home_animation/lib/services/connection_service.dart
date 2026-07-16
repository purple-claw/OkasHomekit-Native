// lib/services/connection_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ConnectionService extends ChangeNotifier {
  static const String _storedIpKey = 'knx_gateway_ip';
  static const String _connectionStatusKey = 'knx_connection_status';

  String? _baseUrl;
  bool _isConnecting = false;
  String? _error;

  String? get baseUrl => _baseUrl;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  bool get hasSavedConnection => _baseUrl != null;

  Future<void> setBaseUrl(String ip, {int port = 3000}) async {
    _baseUrl = 'http://$ip:$port/api';
    await _saveIp(ip);
    notifyListeners();
  }

  Future<void> _saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storedIpKey, ip);
  }

  Future<String?> getSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storedIpKey);
  }

  Future<bool> testConnection(String ip, {int port = 3000}) async {
    try {
      final url = Uri.parse('http://$ip:$port/api/health');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  Future<bool> configureKNXGateway(
    String ip, {
    int port = 3000,
    String? token,
  }) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse('http://$ip:$port/api/configure');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'knx_gateway': ip,
              'knx_port': 3671,
              'token': token, // Send token for authentication
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await setBaseUrl(ip);
        await saveConnectionStatus(true);
        _isConnecting = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Server returned error: ${response.statusCode}';
        _isConnecting = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to configure: $e';
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> saveConnectionStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectionStatusKey, status);
    if (!status) {
      _baseUrl = null;
    }
    notifyListeners();
  }

  Future<bool> getConnectionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_connectionStatusKey) ?? false;
  }

  Future<void> clearSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storedIpKey);
    await prefs.remove(_connectionStatusKey);
    _baseUrl = null;
    notifyListeners();
  }
}
