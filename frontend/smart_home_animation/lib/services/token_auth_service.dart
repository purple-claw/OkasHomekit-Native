import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:smart_home_animation/api/constants.dart';
import 'package:smart_home_animation/services/mdns_discovery.dart';

class TokenAuthService extends ChangeNotifier {
  static const _tokenKey = 'okas_access_token';
  static const _sessionKey = 'okas_auth_session';
  static const _storage = FlutterSecureStorage();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _token;
  Map<String, dynamic>? _session;
  String? _error;
  String? _discoveredIp;
  List<String> _discoveryLogs = [];

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get discoveredIp => _discoveredIp;
  List<String> get discoveryLogs => List.unmodifiable(_discoveryLogs);
  String? get token => _token;
  String get role => _session?['principal']?['role'] as String? ?? '';
  bool get isAdmin => role == 'admin';
  Map<String, dynamic>? get mqttCredentials => _session?['mqtt'] as Map<String, dynamic>?;
  String? get commandToken => _session?['commandToken'] as String?;

  TokenAuthService() {
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    _token = await _storage.read(key: _tokenKey);
    final savedSession = await _storage.read(key: _sessionKey);
    if (savedSession != null) {
      try {
        _session = jsonDecode(savedSession) as Map<String, dynamic>;
      } catch (_) {
        await _storage.delete(key: _sessionKey);
      }
    }
    _isAuthenticated = _token != null && _session != null;
    if (_token != null) Constants.setAuthToken(_token!);
    notifyListeners();
  }

  Future<bool> authenticateWithToken(String token) async {
    _isLoading = true;
    _error = null;
    _discoveredIp = null;
    _discoveryLogs = [];
    notifyListeners();

    try {
      _discoveryLogs.add('Searching for OKAS board…');
      final boardIp = await _discoverBoardIp();
      if (boardIp == null) {
        _error = 'No OKAS board found on this network.';
        return false;
      }
      _discoveredIp = boardIp;
      _configureBoard(boardIp);
      final macToken = _macDerivedToken(Constants.macAddress);
      if (macToken != null && token.toUpperCase() != macToken) {
        _error = 'The admin token does not match this board MAC address.';
        return false;
      }
      _discoveryLogs.add('Verifying access token…');
      final session = await _exchangeToken(token, boardIp);
      if (session == null) return false;

      _token = token;
      _session = session;
      _isAuthenticated = true;
      Constants.setAuthToken(token);
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _sessionKey, value: jsonEncode(session));
      _discoveryLogs.add('Access granted.');
      return true;
    } on SocketException {
      _error = 'Cannot reach the OKAS board. Check your network connection.';
      return false;
    } on TimeoutException {
      _error = 'Connection timed out. Please try again.';
      return false;
    } catch (_) {
      _error ??= 'Unable to authenticate with this board.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkAutoLogin() async {
    await _loadSavedCredentials();
    if (_token == null) return false;
    final boardIp = await _discoverBoardIp();
    if (boardIp == null) return false;
    _discoveredIp = boardIp;
    _configureBoard(boardIp);
    final session = await _exchangeToken(_token!, boardIp);
    if (session == null) {
      await logout();
      return false;
    }
    _session = session;
    _isAuthenticated = true;
    Constants.setAuthToken(_token!);
    await _storage.write(key: _sessionKey, value: jsonEncode(session));
    notifyListeners();
    return true;
  }

  Future<List<Map<String, dynamic>>> listGuests() async {
    _requireAdmin();
    final response = await http
        .get(_apiUri('/api/auth/guests'), headers: _authHeaders())
        .timeout(const Duration(seconds: 10));
    final data = _decodeResponse(response);
    return (data['guests'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createGuest({
    required String label,
    required int durationMinutes,
  }) async {
    _requireAdmin();
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final guestToken = List.generate(8, (_) => alphabet[random.nextInt(alphabet.length)]).join();
    final response = await http
        .post(
          _apiUri('/api/auth/guests'),
          headers: _authHeaders(),
          body: jsonEncode({'label': label, 'durationMinutes': durationMinutes, 'token': guestToken}),
        )
        .timeout(const Duration(seconds: 10));
    final result = _decodeResponse(response);
    result['guestToken'] = guestToken;
    return result;
  }

  Future<void> revokeGuest(String guestId) async {
    _requireAdmin();
    final response = await http
        .post(
          _apiUri('/api/auth/guests/$guestId/revoke'),
          headers: _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));
    _decodeResponse(response);
  }

  Future<Map<String, dynamic>> updateGuest({
    required String guestId,
    required String label,
    required int durationMinutes,
  }) async {
    _requireAdmin();
    final response = await http
        .patch(
          _apiUri('/api/auth/guests/$guestId'),
          headers: _authHeaders(),
          body: jsonEncode({'label': label, 'durationMinutes': durationMinutes}),
        )
        .timeout(const Duration(seconds: 10));
    return _decodeResponse(response);
  }

  Future<void> deleteGuest(String guestId) async {
    _requireAdmin();
    final response = await http
        .delete(
          _apiUri('/api/auth/guests/$guestId'),
          headers: _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));
    _decodeResponse(response);
  }

  Future<String?> _discoverBoardIp() async {
    try {
      final devices = await MDNSDiscovery().discoverOKASDevice();
      final ip = devices.isEmpty ? null : devices.first['host'] as String?;
      if (ip != null && ip.isNotEmpty) {
        _discoveryLogs.add('Board found at $ip.');
        return ip;
      }
    } catch (_) {
      _discoveryLogs.add('Board discovery failed.');
    }
    return null;
  }

  void _configureBoard(String ip) {
    Constants.updateBaseUrl(ip);
    Constants.setCurrentIp(ip);
    Constants.setApiPort(Constants.apiScheme == 'https' ? 443 : 80);
  }

  String? _macDerivedToken(String mac) {
    final normalized = mac.toLowerCase().replaceAll(RegExp(r'[^a-f0-9]'), '');
    if (normalized.length != 12) return null;
    final digest = sha256.convert(utf8.encode('OKAS-MAC-AUTH-V1:$normalized')).bytes;
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final output = StringBuffer();
    for (final value in digest) {
      if (value >= 224) continue;
      output.write(alphabet[value % alphabet.length]);
      if (output.toString().length == 8) return output.toString();
    }
    return null;
  }

  Future<Map<String, dynamic>?> _exchangeToken(String token, String ip) async {
    try {
      final response = await http
          .post(
            Uri(scheme: Constants.apiScheme, host: ip, path: '/api/auth/exchange'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 10));
      final data = _decodeResponse(response);
      if (data['success'] == true) return data;
      _error = data['message'] as String? ?? 'Token verification failed.';
    } on AuthApiException catch (error) {
      _error = error.message;
    }
    return null;
  }

  Uri _apiUri(String endpoint) {
    final ip = _discoveredIp ?? Constants.currentIp;
    return Uri(scheme: Constants.apiScheme, host: ip, path: endpoint);
  }

  Map<String, String> _authHeaders() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_token ?? ''}',
      };

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthApiException('The board returned an invalid response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] == false) {
      throw AuthApiException(data['message'] as String? ?? 'Request failed (${response.statusCode}).');
    }
    return data;
  }

  void _requireAdmin() {
    if (!isAdmin || _token == null) {
      throw const AuthApiException('Only the board owner can manage guests.');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionKey);
    _token = null;
    _session = null;
    _isAuthenticated = false;
    Constants.clearAuth();
    notifyListeners();
  }
}

class AuthApiException implements Exception {
  final String message;
  const AuthApiException(this.message);
}
