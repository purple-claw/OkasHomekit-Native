// lib/api/constants.dart
class Constants {
  static const String apiScheme = String.fromEnvironment(
    'OKAS_API_SCHEME',
    defaultValue: 'http',
  );
  static String _baseUrl = '';
  static String _currentIp = '';
  static String _macAddress = '';
  static String _authToken = '';
  static bool _isAuthenticated = false;
  static int _apiPort = 80;

  // Add KNX Gateway IP
  static String _knxGatewayIp = '192.168.1.11';

  // Getters
  static String get localHost => _baseUrl;
  static String get currentIp => _currentIp;
  static String get macAddress => _macAddress;
  static String get authToken => _authToken;
  static bool get isAuthenticated => _isAuthenticated;
  static String get baseUrl => _baseUrl;
  static int get apiPort => _apiPort;
  static String get knxGatewayIp => _knxGatewayIp;

  // Setters
  static void updateBaseUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _baseUrl = '$apiScheme://$url';
    } else {
      _baseUrl = url;
    }
    print('📍 Constants base URL updated to: $_baseUrl');
  }

  static void setCurrentIp(String ip) {
    _currentIp = ip;
    print('📍 Current IP set to: $ip');
  }

  static void setApiPort(int port) {
    _apiPort = port;
    print('📍 API Port set to: $port');
  }

  static void setMacAddress(String mac) {
    _macAddress = mac;
    print('📍 MAC Address set to: $mac');
  }

  static void setAuthToken(String token) {
    _authToken = token;
    _isAuthenticated = token.isNotEmpty;
    print('📍 Authentication token ${token.isNotEmpty ? 'set' : 'cleared'}');
  }

  static void clearAuth() {
    _authToken = '';
    _isAuthenticated = false;
    print('📍 Authentication cleared');
  }

  // API endpoints with authentication headers
  static Map<String, String> get authHeaders {
    if (_authToken.isNotEmpty) {
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authToken',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  // Health & Discovery
  static String get health => '$apiScheme://$_currentIp:$_apiPort/api/health';
  static String get discover => '$apiScheme://$_currentIp:$_apiPort/api/discover';
  static String get ping => '$apiScheme://$_currentIp:$_apiPort/api/ping';

  // Authentication
  static String get verifyToken =>
      '$apiScheme://$_currentIp:$_apiPort/api/auth/verify';
  static String get validateToken =>
      '$apiScheme://$_currentIp:$_apiPort/api/auth/validate';

  // Room endpoints
  static String get rooms => '$apiScheme://$_currentIp:$_apiPort/api/rooms';
  static String roomDetails(String roomId) =>
      '$apiScheme://$_currentIp:$_apiPort/api/rooms/$roomId';
  static String roomLoads(String roomId) =>
      '$apiScheme://$_currentIp:$_apiPort/api/rooms/$roomId/loads';
  static String roomDevices(String roomId) =>
      '$apiScheme://$_currentIp:$_apiPort/api/rooms/$roomId/devices';

  // Load/Device endpoints
  static String get loads => '$apiScheme://$_currentIp:$_apiPort/api/loads';
  static String loadDetails(String loadId) =>
      '$apiScheme://$_currentIp:$_apiPort/api/loads/$loadId';
  static String deviceCommand(String deviceId) =>
      '$apiScheme://$_currentIp:$_apiPort/api/devices/$deviceId/command';
  static String deviceStatus(String deviceId) =>
      '$apiScheme://$_currentIp:$_apiPort/api/devices/$deviceId/status';
  static String deviceControl(String deviceId) =>
      '$apiScheme://$_currentIp:$_apiPort/api/devices/$deviceId/control';

  // MQTT endpoints
  static String get mqttStatus =>
      '$apiScheme://$_currentIp:$_apiPort/api/mqtt/status';
  static String get mqttPublish =>
      '$apiScheme://$_currentIp:$_apiPort/api/mqtt/publish';
  static String get mqttSubscribe =>
      '$apiScheme://$_currentIp:$_apiPort/api/mqtt/subscribe';

  // System endpoints
  static String get categories => '$apiScheme://$_currentIp:$_apiPort/api/categories';
  static String get configure => '$apiScheme://$_currentIp:$_apiPort/api/configure';
  static String get boardInfo => '$apiScheme://$_currentIp:$_apiPort/api/board/info';
  static String get systemInfo =>
      '$apiScheme://$_currentIp:$_apiPort/api/system/info';
  static String get reboot => '$apiScheme://$_currentIp:$_apiPort/api/system/reboot';

  // WebSocket
  static String get webSocket => 'ws://$_currentIp:$_apiPort/ws';

  // Utility methods
  static bool isValidIp(String ip) {
    final RegExp ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipRegex.hasMatch(ip);
  }

  static bool isValidMacAddress(String mac) {
    final RegExp macRegex = RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
    );
    return macRegex.hasMatch(mac);
  }

  static String formatMacAddress(String mac) {
    final clean = mac.replaceAll(RegExp(r'[:-]'), '').toUpperCase();
    return clean.replaceAllMapped(
      RegExp(r'.{2}'),
      (match) => match.group(0)! + (match.end < clean.length ? ':' : ''),
    );
  }

  static void printConfig() {
    print('📋 OKAS Configuration:');
    print('   Base URL: $_baseUrl');
    print('   Current IP: $_currentIp');
    print('   API Port: $_apiPort');
    print('   MAC Address: $_macAddress');
    print('   Auth Token: $_authToken');
    print('   Authenticated: $_isAuthenticated');
  }
}
