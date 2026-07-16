// lib/services/direct_mqtt_service.dart
// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:smart_home_animation/core/shared/domain/entities/music_info.dart';
import 'package:smart_home_animation/core/shared/domain/entities/smart_device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/smart_room.dart';

// Note: We're not using multicast_dns due to API issues
// Instead, we'll use network scanning and hostname resolution

class DirectMQTTService extends ChangeNotifier {
  MqttServerClient? _client;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _currentHost;
  int _currentPort = 1884;
  List<String> _brokerAttempts = [];
  String? _lastError;
  String? _commandToken;
  Timer? _credentialExpiryTimer;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSubscription;

  // Store devices and loads
  final Map<String, Map<String, dynamic>> _devices = {};
  final Map<String, Map<String, dynamic>> _rooms = {};
  final Map<String, Map<String, dynamic>> _loads = {};

  // Store load ID mapping
  final Map<String, int> _loadNameToId = {};

  Map<String, Map<String, dynamic>> get devices => _devices;
  Map<String, Map<String, dynamic>> get rooms => _rooms;
  Map<String, Map<String, dynamic>> get loads => _loads;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  List<String> get brokerAttempts => _brokerAttempts;
  String? get lastError => _lastError;

  DirectMQTTService();

  /// Connect only after TokenAuthService has exchanged a valid board token.
  /// The broker account remains shared for backwards compatibility; each
  /// control message carries [_commandToken] for board-side authorization.
  Future<bool> connectAuthenticated({
    required String host,
    required int port,
    required String username,
    required String password,
    required String commandToken,
    required bool tls,
    String? expiresAt,
  }) async {
    await disconnect();
    _brokerAttempts.clear();
    _lastError = null;
    _commandToken = commandToken;
    _currentHost = host;
    _currentPort = port;
    _brokerAttempts.add('Trying MQTT $host:$port');
    notifyListeners();
    _credentialExpiryTimer?.cancel();
    if (expiresAt != null) {
      final expiry = DateTime.tryParse(expiresAt);
      if (expiry != null) {
        final delay = expiry.difference(DateTime.now());
        if (delay.isNegative) {
          _lastError = 'MQTT credentials are already expired.';
          notifyListeners();
          return false;
        }
        _credentialExpiryTimer = Timer(delay, () {
          disconnect();
        });
      }
    }
    return _connectToBroker(
      host: host,
      port: port,
      username: username,
      password: password,
      tls: tls,
    );
  }

  // Auto-discover broker on current network
  Future<void> _autoDiscoverAndConnect() async {
    _brokerAttempts.clear();

    // FIRST: Try the known IP directly
    const knownHost = '192.168.1.152'; // UPDATED
    _brokerAttempts.add('Trying known IP: $knownHost:1884');
    notifyListeners();

    final success = await _connectToBroker(
      host: knownHost,
      port: 1884,
      username: '',
      password: '',
    );

    if (success) {
      _brokerAttempts.add('✅ Connected to OKAS at $knownHost:1884');
      _currentHost = knownHost;
      notifyListeners();
      return;
    }

    // If known IP fails, try hostname resolution
    final resolvedHost = await _resolveHostnames();
    if (resolvedHost != null) {
      _brokerAttempts.add('Resolved OKAS hostname to: $resolvedHost');
      notifyListeners();

      final success = await _connectToBroker(
        host: resolvedHost,
        port: 1884,
        username: '',
        password: '',
      );

      if (success) {
        _brokerAttempts.add('✅ Connected to OKAS at $resolvedHost:1884');
        _currentHost = resolvedHost;
        notifyListeners();
        return;
      }
    }

    // Then try network scanning
    final scannedHost = await _scanNetworkForOKAS();
    if (scannedHost != null) {
      _brokerAttempts.add('Network scan discovered OKAS at: $scannedHost');
      notifyListeners();

      final success = await _connectToBroker(
        host: scannedHost,
        port: 1884,
        username: '',
        password: '',
      );

      if (success) {
        _brokerAttempts.add('✅ Connected to OKAS at $scannedHost:1884');
        _currentHost = scannedHost;
        notifyListeners();
        return;
      }
    }

    // Then try common IPs
    final possibleHosts = await _getPossibleHosts();
    for (final host in possibleHosts) {
      if (_isConnected) break;

      _brokerAttempts.add('Trying $host:1884');
      notifyListeners();

      final success = await _connectToBroker(
        host: host,
        port: 1884,
        username: '',
        password: '',
      );

      if (success) {
        _brokerAttempts.add('✅ Connected to OKAS at $host:1884');
        _currentHost = host;
        notifyListeners();
        break;
      } else {
        _brokerAttempts.add('❌ Failed to connect to $host:1884');
        notifyListeners();
      }
    }

    if (!_isConnected) {
      _brokerAttempts.add('⚠️ OKAS device not found - using demo mode');
      notifyListeners();
      _loadDemoData();
    }
  }
  // Add to direct_mqtt_service.dart

  void sendBrightnessCommand(String deviceId, int brightness) {
    print(
      'Sending brightness to OKAS: loadId=$deviceId, brightness=$brightness',
    );

    final load = _loads[deviceId];
    if (load != null) {
      final ldId = load['ldId'] as int? ?? int.tryParse(deviceId) ?? 1;
      final loadType = load['type'] as String? ?? 'dim';

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': {'bri': brightness.clamp(0, 100)},
      });

      publish('command/sndCmd', message);

      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['brightness'] = brightness;
        _devices[deviceId]!['brightness'] = brightness;
        notifyListeners();
      }
    }
  }

  void sendColorTempCommand(String deviceId, int colorTemp) {
    print('Sending color temp to OKAS: loadId=$deviceId, colorTemp=$colorTemp');

    final load = _loads[deviceId];
    if (load != null) {
      final ldId = load['ldId'] as int? ?? int.tryParse(deviceId) ?? 1;
      final loadType = load['type'] as String? ?? 'tun';

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': {'cTp': colorTemp.clamp(2700, 6500)},
      });

      publish('command/sndCmd', message);

      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['cTp'] = colorTemp;
        _devices[deviceId]!['cTp'] = colorTemp;
        notifyListeners();
      }
    }
  }

  // RGB Control
  void sendRGBCommand(String deviceId, int red, int green, int blue) {
    print('Sending RGB to OKAS: loadId=$deviceId, R=$red, G=$green, B=$blue');

    final load = _loads[deviceId];
    if (load != null) {
      final ldId = load['ldId'] as int? ?? int.tryParse(deviceId) ?? 1;
      final loadType = load['type'] as String? ?? 'rgb';

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': {
          'r': red.clamp(0, 255),
          'g': green.clamp(0, 255),
          'b': blue.clamp(0, 255),
        },
      });

      publish('command/sndCmd', message);

      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['red'] = red;
        _loads[deviceId]!['green'] = green;
        _loads[deviceId]!['blue'] = blue;
        _devices[deviceId]!['red'] = red;
        _devices[deviceId]!['green'] = green;
        _devices[deviceId]!['blue'] = blue;
        notifyListeners();
      }
    }
  }

  // HVAC Mode Control
  void sendHVACModeCommand(String deviceId, String mode) {
    print('Sending HVAC mode to OKAS: loadId=$deviceId, mode=$mode');

    final load = _loads[deviceId];
    if (load != null) {
      final ldId = load['ldId'] as int? ?? int.tryParse(deviceId) ?? 1;
      final loadType = load['type'] as String? ?? 'hvc';

      // Map mode to OKAS format
      String hvacMode;
      switch (mode.toLowerCase()) {
        case 'cool':
          hvacMode = 'cool';
          break;
        case 'heat':
          hvacMode = 'heat';
          break;
        case 'auto':
          hvacMode = 'auto';
          break;
        case 'dry':
          hvacMode = 'dry';
          break;
        default:
          hvacMode = 'cool';
      }

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': {'mod': hvacMode},
      });

      publish('command/sndCmd', message);

      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['hvacMode'] = mode;
        _devices[deviceId]!['hvacMode'] = mode;
        notifyListeners();
      }
    }
  }

  // Temperature Control for HVAC
  void sendTemperatureCommand(String deviceId, int temperature) {
    print('Sending temperature to OKAS: loadId=$deviceId, temp=$temperature°C');

    final load = _loads[deviceId];
    if (load != null) {
      final ldId = load['ldId'] as int? ?? int.tryParse(deviceId) ?? 1;
      final loadType = load['type'] as String? ?? 'hvc';

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': {'temp': temperature.clamp(16, 32)},
      });

      publish('command/sndCmd', message);

      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['temp'] = temperature;
        _devices[deviceId]!['temp'] = temperature;
        notifyListeners();
      }
    }
  }

  void sendCurtainPositionCommand(String deviceId, int position) {
    print(
      'Sending curtain position to OKAS: loadId=$deviceId, position=$position',
    );

    final load = _loads[deviceId];
    if (load != null) {
      final ldId = load['ldId'] as int? ?? int.tryParse(deviceId) ?? 1;
      final loadType = load['type'] as String? ?? 'cur';

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': {'pos': position.clamp(0, 100)},
      });

      publish('command/sndCmd', message);

      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['cPs'] = position;
        _loads[deviceId]!['pos'] = position;
        _devices[deviceId]!['cPs'] = position;
        _devices[deviceId]!['pos'] = position;
        notifyListeners();
      }
    }
  }

  // Resolve common OKAS hostnames
  Future<String?> _resolveHostnames() async {
    const hostnames = ['okas.local', 'okas-homekit.local'];

    for (final hostname in hostnames) {
      try {
        print('Resolving $hostname...');
        final addresses = await InternetAddress.lookup(hostname);
        if (addresses.isNotEmpty) {
          final ip = addresses.first.address;
          print('✅ Resolved $hostname to $ip');
          return ip;
        }
      } catch (e) {
        print('Could not resolve $hostname: $e');
      }
    }
    return null;
  }

  // Network scan to find OKAS board by testing common IPs
  Future<String?> _scanNetworkForOKAS() async {
    final currentIp = await _getCurrentDeviceIP();
    if (currentIp == null) return null;

    final parts = currentIp.split('.');
    if (parts.length != 4) return null;

    final network = '${parts[0]}.${parts[1]}.${parts[2]}';

    // YOUR OKAS BOARD IP - ADD THIS FIRST
    final priorityIps = [
      '192.168.1.152', // Your OKAS board IP (UPDATED)
      '192.168.1.120',
      '192.168.1.119',
      '$network.152',
      '$network.120',
      '$network.119',
    ];

    // Check priority IPs first
    for (final ip in priorityIps) {
      try {
        print('Testing priority IP: $ip');
        final socket = await Socket.connect(
          ip,
          1884,
          timeout: Duration(seconds: 2),
        );
        socket.destroy();
        print('✅ Found OKAS board at $ip');
        return ip;
      } catch (e) {
        print('Could not connect to $ip: $e');
      }
    }

    // Common OKAS IP suffixes
    final commonIps = [
      '$network.199',
      '$network.108',
      '$network.100',
      '$network.164',
      '$network.200',
      '$network.1',
    ];

    for (final ip in commonIps) {
      try {
        print('Testing IP: $ip');
        final socket = await Socket.connect(
          ip,
          1884,
          timeout: Duration(seconds: 2),
        );
        socket.destroy();
        print('✅ Found OKAS board at $ip');
        return ip;
      } catch (e) {
        // Connection failed, try next IP
      }
    }

    return null;
  }

  // Update _getPossibleHosts method
  Future<List<String>> _getPossibleHosts() async {
    final Set<String> hosts = {};

    // YOUR KNOWN OKAS BOARD IP - PRIORITY 1
    hosts.addAll([
      '192.168.1.152', // Your OKAS board IP (UPDATED)
      '192.168.1.120',
      '192.168.1.119',
      '192.168.1.187',
      '192.168.1.100',
      'okas-homekit.local',
      'okas.local',
    ]);

    // Common OKAS IP addresses
    hosts.addAll([
      '192.168.1.199',
      '192.168.1.108',
      '192.168.1.164',
      '192.168.1.200',
      '192.168.0.100',
      '10.0.0.100',
    ]);

    // Current network IP range
    final networkHosts = await _scanCurrentNetwork();
    hosts.addAll(networkHosts);

    // Gateway IP
    final gateway = await _getGatewayIP();
    if (gateway != null) hosts.add(gateway);

    // Current device IP
    final currentIp = await _getCurrentDeviceIP();
    if (currentIp != null) hosts.add(currentIp);

    // Localhost
    hosts.add('localhost');
    hosts.add('127.0.0.1');

    return hosts.toList();
  }

  Future<List<String>> _scanCurrentNetwork() async {
    final List<String> hosts = [];
    final currentIp = await _getCurrentDeviceIP();

    if (currentIp != null) {
      final parts = currentIp.split('.');
      if (parts.length == 4) {
        final network = '${parts[0]}.${parts[1]}.${parts[2]}';
        const commonSuffixes = [1, 100, 108, 164, 199, 200, 250];

        for (final suffix in commonSuffixes) {
          hosts.add('$network.$suffix');
        }
      }
    }
    return hosts;
  }

  Future<String?> _getGatewayIP() async {
    try {
      final info = NetworkInfo();
      final gateway = await info.getWifiGatewayIP();
      if (gateway != null && gateway.isNotEmpty && gateway != '0.0.0.0') {
        return gateway;
      }
    } catch (e) {
      print('Error getting gateway: $e');
    }
    return null;
  }

  Future<String?> _getCurrentDeviceIP() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip != null && ip.isNotEmpty && ip != '0.0.0.0') {
        return ip;
      }
    } catch (e) {
      print('Error getting device IP: $e');
    }
    return null;
  }

  Future<bool> _connectToBroker({
    required String host,
    required int port,
    required String username,
    required String password,
    bool tls = false,
  }) async {
    if (_isConnecting) return false;

    _isConnecting = true;
    notifyListeners();

    try {
      final clientId = 'okas_app_${DateTime.now().millisecondsSinceEpoch}';

      _client = MqttServerClient(host, clientId);
      _client!.port = port;
      _client!.secure = tls;
      _client!.keepAlivePeriod = 30;
      _client!.disconnectOnNoResponsePeriod = 20;
      _client!.setProtocolV311();
      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;

      final connectMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .keepAliveFor(30)
          .startClean()
          .authenticateAs(username, password);

      _client!.connectionMessage = connectMessage;

      _client!.onConnected = () {
        print('✅ Connected to OKAS MQTT at $host:$port');
        _isConnected = true;
        _isConnecting = false;
        _lastError = null;
        _brokerAttempts.add('Connected to MQTT $host:$port');
        notifyListeners();
        _subscribeToTopics();
        _requestAllLoads();
      };

      _client!.onDisconnected = () {
        print('❌ Disconnected from OKAS MQTT');
        _isConnected = false;
        _isConnecting = false;
        notifyListeners();
      };

      _client!.onAutoReconnect = () {
        print('🔄 Reconnecting to OKAS MQTT at $host:$port');
        _isConnected = false;
        _isConnecting = true;
        _lastError = 'Reconnecting to OKAS MQTT...';
        _brokerAttempts.add('Reconnecting to MQTT $host:$port');
        notifyListeners();
      };

      _client!.onAutoReconnected = () {
        print('✅ Reconnected to OKAS MQTT at $host:$port');
        _isConnected = true;
        _isConnecting = false;
        _lastError = null;
        _brokerAttempts.add('Reconnected to MQTT $host:$port');
        notifyListeners();
        _requestAllLoads();
      };

      print('Connecting to OKAS at $host:$port...');
      final connMessage = await _client!.connect();

      _isConnecting = false;

      if (connMessage != null &&
          connMessage.returnCode == MqttConnectReturnCode.connectionAccepted) {
        return true;
      }
      _lastError = 'MQTT rejected connection: ${connMessage?.returnCode ?? 'no response'}';
      _brokerAttempts.add(_lastError!);
      notifyListeners();
      return false;
    } catch (e) {
      print('Connection error to $host: $e');
      _lastError = 'MQTT connection error to $host:$port - $e';
      _brokerAttempts.add(_lastError!);
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  // Add this method to send fan speed commands
  void sendFanSpeedCommand(String deviceId, int speed) {
    print('Sending fan speed to OKAS: loadId=$deviceId, speed=$speed');

    final load = _loads[deviceId];
    if (load != null) {
      final ldId = load['ldId'] as int? ?? int.tryParse(deviceId) ?? 1;
      final loadType = load['type'] as String? ?? 'fan';

      // Convert UI speed (0-250) back to OKAS range (0-255)
      final okasSpeed = (speed / 250 * 255).round();

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': {'fSp': okasSpeed},
      });

      print('Publishing fan command: $message');
      publish('command/sndCmd', message);

      // Update local state immediately
      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['fanSpeed'] = speed;
        _loads[deviceId]!['fSp'] = okasSpeed;
        _devices[deviceId]!['fanSpeed'] = speed;
        _devices[deviceId]!['fSp'] = okasSpeed;
        notifyListeners();
      }
    }
  }

  void addRoom(Map<String, dynamic> roomData) {
    publish('rooms/add', json.encode(roomData));
  }

  void getRooms() {
    publish('rooms/get', '{}');
  }

  List<Map<String, dynamic>> getLoadsList() {
    return _loads.values.toList();
  }

  void _subscribeToTopics() {
    if (_client != null &&
        _client!.connectionStatus?.state == MqttConnectionState.connected) {
      const topics = [
        'loads/setLoads',
        'command/cmdAck',
        'status/+',
        'status/mobAck',
      ];

      for (String topic in topics) {
        _client!.subscribe(topic, MqttQos.atLeastOnce);
        print('Subscribed to: $topic');
      }

      _updatesSubscription ??= _client!.updates!.listen((
        List<MqttReceivedMessage<MqttMessage>> messages,
      ) {
        for (var message in messages) {
          final payload = message.payload as MqttPublishMessage;
          final text = MqttPublishPayload.bytesToStringAsString(
            payload.payload.message,
          );
          print('📨 OKAS Message [${message.topic}]: $text');
          _handleMessage(message.topic, text);
        }
      });
    }
  }

  // In _handleMessage method of direct_mqtt_service.dart

  void _handleMessage(String topic, String message) {
    try {
      final data = json.decode(message);

      if (topic == 'loads/setLoads' && data.containsKey('lds')) {
        _loads.clear();
        _devices.clear();
        _loadNameToId.clear();

        final List<dynamic> loads = data['lds'];
        for (var i = 0; i < loads.length; i++) {
          final load = loads[i];
          final loadId = i + 1;

          // FIX: Handle nullable values properly
          final loadName = load['nm'] as String? ?? 'Load ${loadId}';
          final loadType = load['typ'] as String? ?? 'swt';

          final sta = load['sta'] as Map<String, dynamic>?;
          final isOn = sta?['on'] as bool? ?? false;
          final brightness = sta?['bri'] as int? ?? 0;

          // FIX: Color temp - handle both int and string
          int colorTemp = 2700;
          final cTpValue = sta?['cTp'];
          if (cTpValue is int) {
            colorTemp = cTpValue;
          } else if (cTpValue is String) {
            colorTemp = int.tryParse(cTpValue) ?? 2700;
          }

          // RGB values
          final red = sta?['r'] as int? ?? 255;
          final green = sta?['g'] as int? ?? 255;
          final blue = sta?['b'] as int? ?? 255;

          // HVAC values
          String hvacMode = 'Cool';
          final modValue = sta?['mod'];
          if (modValue is int) {
            switch (modValue) {
              case 0:
                hvacMode = 'Cool';
                break;
              case 1:
                hvacMode = 'Heat';
                break;
              case 2:
                hvacMode = 'Auto';
                break;
              case 3:
                hvacMode = 'Dry';
                break;
              default:
                hvacMode = 'Cool';
            }
          } else if (modValue is String) {
            hvacMode = modValue;
          }

          final temperature = sta?['spt'] as int? ?? sta?['temp'] as int? ?? 25;

          // Fan speed
          int fanSpeed = sta?['fSp'] as int? ?? sta?['spd'] as int? ?? 0;
          final displaySpeed = fanSpeed > 0
              ? (fanSpeed / 255 * 250).round()
              : 0;

          // Curtain position
          final curtainPos = sta?['pos'] as int? ?? sta?['cPs'] as int? ?? 0;

          final loadMap = <String, dynamic>{
            'id': loadId.toString(),
            'ldId': loadId,
            'name': loadName,
            'type': loadType,
            'isOn': isOn,
            'brightness': brightness,
            'cTp': colorTemp,
            'red': red,
            'green': green,
            'blue': blue,
            'hvacMode': hvacMode,
            'temp': temperature,
            'fanSpeed': displaySpeed,
            'fSp': fanSpeed,
            'cPs': curtainPos,
            'pos': curtainPos,
            'originalData': load,
          };

          _loads[loadId.toString()] = loadMap;

          final deviceMap = <String, dynamic>{
            'id': loadId.toString(),
            'ldId': loadId,
            'name': loadName,
            'type': loadType,
            'isOn': isOn,
            'brightness': brightness,
            'cTp': colorTemp,
            'red': red,
            'green': green,
            'blue': blue,
            'hvacMode': hvacMode,
            'temp': temperature,
            'fanSpeed': displaySpeed,
            'fSp': fanSpeed,
            'cPs': curtainPos,
            'pos': curtainPos,
          };

          _devices[loadId.toString()] = deviceMap;

          if (loadName.isNotEmpty) {
            _loadNameToId[loadName] = loadId;
          }
        }

        notifyListeners();
        print('✅ Loaded ${_loads.length} loads from OKAS');
      }

      // Handle status updates for specific loads
      if (topic.startsWith('status/') && topic != 'status/mobAck') {
        final ldId = topic.split('/')[1];
        final sta = data['sta'] as Map<String, dynamic>?;

        if (_loads.containsKey(ldId)) {
          final load = _loads[ldId]!;

          if (sta != null) {
            load['isOn'] = sta['on'] ?? load['isOn'];
            load['brightness'] = sta['bri'] ?? load['brightness'];

            // Handle color temp
            final cTpValue = sta['cTp'];
            if (cTpValue is int) {
              load['cTp'] = cTpValue;
            } else if (cTpValue is String) {
              load['cTp'] = int.tryParse(cTpValue) ?? load['cTp'];
            }

            load['red'] = sta['r'] ?? load['red'];
            load['green'] = sta['g'] ?? load['green'];
            load['blue'] = sta['b'] ?? load['blue'];

            // Handle HVAC mode
            final modValue = sta['mod'];
            if (modValue is int) {
              switch (modValue) {
                case 0:
                  load['hvacMode'] = 'Cool';
                  break;
                case 1:
                  load['hvacMode'] = 'Heat';
                  break;
                case 2:
                  load['hvacMode'] = 'Auto';
                  break;
                case 3:
                  load['hvacMode'] = 'Dry';
                  break;
                default:
                  load['hvacMode'] = 'Cool';
              }
            } else if (modValue is String) {
              load['hvacMode'] = modValue;
            }

            load['temp'] = sta['spt'] ?? sta['temp'] ?? load['temp'];

            // Handle fan speed
            final fanSpeed = sta['fSp'] as int? ?? sta['spd'] as int?;
            if (fanSpeed != null) {
              final displaySpeed = fanSpeed > 0
                  ? (fanSpeed / 255 * 250).round()
                  : 0;
              load['fanSpeed'] = displaySpeed;
              load['fSp'] = fanSpeed;
            }

            // Handle curtain position
            load['cPs'] = sta['pos'] ?? sta['cPs'] ?? load['cPs'];
            load['pos'] = sta['pos'] ?? sta['cPs'] ?? load['pos'];

            // Update devices map
            if (_devices.containsKey(ldId)) {
              _devices[ldId]!.addAll(load);
            }
          }

          notifyListeners();
          print('✅ Status update for load $ldId');
        }
      }

      // Handle command acknowledgment
      if (topic == 'command/cmdAck') {
        final ldId = data['ldId'] as int?;
        final status = data['sts'] as String?;
        print('Command acknowledgment for load $ldId: $status');

        if (status == 'executed' && data.containsKey('cSt')) {
          final cSt = data['cSt'] as Map<String, dynamic>?;
          final loadId = ldId?.toString();

          if (loadId != null && _loads.containsKey(loadId)) {
            if (cSt != null) {
              _loads[loadId]!['isOn'] = cSt['on'] ?? _loads[loadId]!['isOn'];
              _loads[loadId]!['brightness'] =
                  cSt['bri'] ?? _loads[loadId]!['brightness'];

              if (_devices.containsKey(loadId)) {
                _devices[loadId]!['isOn'] =
                    cSt['on'] ?? _devices[loadId]!['isOn'];
                _devices[loadId]!['brightness'] =
                    cSt['bri'] ?? _devices[loadId]!['brightness'];
              }
            }
            notifyListeners();
          }
        }
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  List<SmartRoom> getSmartRooms() {
    return _rooms.entries.map((entry) {
      final roomData = entry.value;
      return SmartRoom(
        id: roomData['id'] ?? entry.key,
        name: entry.key,
        imageUrl: '',
        temperature: 22.0,
        airHumidity: 45.0,
        lights: SmartDevice(isOn: false, value: 0),
        airCondition: SmartDevice(isOn: false, value: 0),
        timer: SmartDevice(isOn: false, value: 0),
        musicInfo: MusicInfo(isOn: false, currentSong: Song.defaultSong),
        devices: [],
        sensors: [],
        automationRules: [],
      );
    }).toList();
  }

  void _updateDefaultRooms() {
    _rooms.clear();

    if (_loads.isNotEmpty) {
      final Map<String, List<String>> roomMap = {};

      for (var entry in _loads.entries) {
        final loadName = entry.value['name']?.toLowerCase() ?? '';
        final loadId = entry.key;

        String roomName = 'General';
        if (loadName.contains('living') ||
            loadName.contains('seating') ||
            loadName.contains('front') ||
            loadName.contains('wall') ||
            loadName.contains('middle')) {
          roomName = 'Living Room';
        } else if (loadName.contains('bed') || loadName.contains('tunning')) {
          roomName = 'Bedroom';
        } else if (loadName.contains('kitchen')) {
          roomName = 'Kitchen';
        } else if (loadName.contains('track') || loadName.contains('bar')) {
          roomName = 'Bar Area';
        } else if (loadName.contains('curtain')) {
          roomName = 'Curtains';
        } else if (loadName.contains('screen')) {
          roomName = 'Screen';
        }

        if (!roomMap.containsKey(roomName)) {
          roomMap[roomName] = [];
        }
        roomMap[roomName]!.add(loadId);
      }

      int roomId = 1;
      for (var entry in roomMap.entries) {
        _rooms[entry.key] = {
          'id': 'room_$roomId',
          'name': entry.key,
          'loads': entry.value,
        };
        roomId++;
      }
    }
  }

  void _requestAllLoads() {
    publish('loads/getLoads', '{}');
  }

  void _loadDemoData() {
    if (_loads.isEmpty) {
      _loads['1'] = {
        'id': '1',
        'ldId': 1,
        'name': 'Track Light',
        'isOn': false,
        'type': 'swt',
      };
      _loads['2'] = {
        'id': '2',
        'ldId': 2,
        'name': 'Bar Lights',
        'isOn': true,
        'type': 'swt',
      };
      _loads['3'] = {
        'id': '3',
        'ldId': 3,
        'name': 'Seating Lights',
        'isOn': true,
        'type': 'dim',
      };

      _rooms['Living Room'] = {
        'id': 'room_1',
        'name': 'Living Room',
        'loads': ['1', '2', '3'],
      };
      _devices.addAll(_loads);
      notifyListeners();
    }
  }

  Future<void> loadRoomsAndDevices() async {
    notifyListeners();
  }

  void sendCommand(String loadId, String command) {
    print('Sending to OKAS: loadId=$loadId, command=$command');

    final load = _loads[loadId];
    if (load != null) {
      final ldId = load['ldId'] ?? int.tryParse(loadId) ?? 1;
      final loadType = load['type'] ?? 'swt';
      final newState = command == 'ON';

      Map<String, dynamic> cmd = {};

      switch (loadType) {
        case 'swt':
          cmd = {'swt': newState};
          break;
        case 'dim':
          if (newState) {
            final brightness = load['brightness'] ?? 100;
            cmd = {'swt': newState};
          } else {
            cmd = {'swt': false};
          }
          break;
        case 'tun':
          cmd = {'swt': newState};
          break;
        case 'cur':
          cmd = {'pos': newState ? 100 : 0};
          break;
        case 'fan':
          cmd = {'fSp': newState ? 128 : 0};
          break;
        case 'rgb':
          cmd = {'swt': newState};
          break;
        case 'hvc':
          // HVAC uses swt for on/off
          cmd = {'swt': newState};
          break;
        case 'scn':
          cmd = {'scn': newState ? 1 : 0};
          break;
        default:
          cmd = {'swt': newState};
      }

      final message = json.encode({'ldId': ldId, 'typ': loadType, 'cmd': cmd});
      print('Publishing to command/sndCmd: $message');
      publish('command/sndCmd', message);

      if (_loads.containsKey(loadId)) {
        _loads[loadId]!['isOn'] = newState;
        _devices[loadId]!['isOn'] = newState;
        notifyListeners();
      }
    }
  }

  Future<void> publish(String topic, String message) async {
    if (_client != null && _isConnected) {
      try {
        final builder = MqttClientPayloadBuilder();
        final decoded = jsonDecode(message);
        if (decoded is Map<String, dynamic> && _commandToken != null) {
          decoded['commandToken'] = _commandToken;
          builder.addString(jsonEncode(decoded));
        } else {
          builder.addString(message);
        }
        _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
        print('📤 OKAS Command to $topic');
      } catch (e) {
        print('Error publishing: $e');
      }
    }
  }

  String? getCurrentHost() => _currentHost;

  void refreshLoads() {
    _requestAllLoads();
  }

  Future<void> disconnect() async {
    await _updatesSubscription?.cancel();
    _updatesSubscription = null;
    if (_client != null) {
      _client!.disconnect();
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> reconnect() async {
    // Reconnection requires a fresh token exchange from TokenAuthService.
    await disconnect();
  }

  @override
  void dispose() {
    _credentialExpiryTimer?.cancel();
    disconnect();
    super.dispose();
  }
}
