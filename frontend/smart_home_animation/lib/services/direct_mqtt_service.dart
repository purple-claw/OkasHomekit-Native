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
import 'package:smart_home_animation/services/room_service.dart';

// Note: We're not using multicast_dns due to API issues
// Instead, we'll use network scanning and hostname resolution

class _Hsv {
  final double hue;
  final double sat;
  const _Hsv(this.hue, this.sat);
}

class DirectMQTTService extends ChangeNotifier with WidgetsBindingObserver {
  MqttServerClient? _client;
  bool _isConnected = false;
  bool _isConnecting = false;
  // True after the first rooms/set has been received from the board in
  // this session. The board publishes rooms/set with retain=true so the
  // broker delivers the last known list immediately on subscribe, so
  // priming normally completes within a few hundred ms of MQTT connect.
  // Until primed, RoomService is treated as untrusted cache and a "create
  // room" only publishes the rooms/add — the local list is overwritten
  // by the board's reply when priming finishes.
  bool _roomsPrimed = false;
  String? _currentHost;
  int _currentPort = 1884;
  String? _currentUsername;
  String? _currentPassword;
  bool _currentTls = false;
  List<String> _brokerAttempts = [];
  String? _lastError;
  String? _commandToken;
  Timer? _credentialExpiryTimer;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSubscription;

  // Payload dedup: on a fresh install the board publishes loads/setLoads
  // and rooms/set twice within a few hundred ms — once as the retained
  // message on subscribe, once as the reply to our loads/getLoads +
  // rooms/get requests. Both carry identical payloads. Without dedup the
  // home screen and loads grid rebuild twice, which reads as a visible
  // double-refresh flicker. We keep a hash of the last processed payload
  // per topic and skip rebuilds when the incoming payload matches within
  // a short dedup window.
  final Map<String, String> _lastPayloadHash = {};
  final Map<String, DateTime> _lastPayloadTime = {};
  // Per-load status dedup: topic status/{ldId} -> last processed payload.
  final Map<String, String> _lastStatusHash = {};

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
  /// True when the room list has been primed from the board at least
  /// once in this session. While false, the local cache may be stale or
  /// empty even though the board has data — useful for showing a
  /// loading state.
  bool get roomsPrimed => _roomsPrimed;
  List<String> get brokerAttempts => _brokerAttempts;
  String? get lastError => _lastError;

  /// Returns true when [payload] for [topic] is a duplicate of the last
  /// processed payload within the dedup window (default 2s). Skips the
  /// expensive rebuild + notifyListeners() in that case.
  ///
  /// The board stamps every response with a fresh `ts` field, so the
  /// retained message and the getLoads reply differ only in that field.
  /// We strip it before comparing so the duplicate is caught.
  bool _isDuplicatePayload(String topic, String payload) {
    final now = DateTime.now();
    final lastTime = _lastPayloadTime[topic];
    if (lastTime != null &&
        now.difference(lastTime) < const Duration(seconds: 2)) {
      final lastHash = _lastPayloadHash[topic];
      if (lastHash != null && lastHash == _normalizePayload(payload)) {
        return true;
      }
    }
    _lastPayloadHash[topic] = _normalizePayload(payload);
    _lastPayloadTime[topic] = now;
    return false;
  }

  /// Strips volatile fields (ts) so identical logical payloads compare
  /// equal even when the board re-stamps them.
  String _normalizePayload(String payload) {
    try {
      final decoded = json.decode(payload);
      if (decoded is Map<String, dynamic>) {
        decoded.remove('ts');
        return json.encode(decoded);
      }
    } catch (_) {
      // Not JSON — compare raw.
    }
    return payload;
  }

  DirectMQTTService() {
    WidgetsBinding.instance.addObserver(this);
  }

  // App lifecycle: when the app is backgrounded, Android suspends the
  // socket; the broker drops the session on keepalive timeout. On resume
  // the mqtt_client auto-reconnect may be deadlocked (autoReconnectInProgress
  // stuck true after one thrown connect()), so bypass it entirely and build
  // a fresh client. Fast path: the broker accepts the stable client id
  // immediately (no 30s keepalive-timeout wait).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_isConnected &&
        _currentHost != null) {
      print('App resumed - forcing fresh MQTT reconnect');
      _isConnecting = false;
      unawaited(() async {
        await disconnect();
        await _connectToBroker(
          host: _currentHost!,
          port: _currentPort,
          username: _currentUsername ?? '',
          password: _currentPassword ?? '',
          tls: _currentTls,
        );
      }());
    }
  }

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
    _currentUsername = username;
    _currentPassword = password;
    _currentTls = tls;
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
        // When the MQTT credentials expire, request a fresh session instead
        // of silently disconnecting forever. The UI keeps working; the only
        // difference is a brief reconnect. (TokenAuthService.checkAutoLogin
        // re-exchanges the owner/guest token on next launch.)
        _credentialExpiryTimer = Timer(delay, () {
          print('MQTT credentials expired - requesting reconnection');
          _isConnected = false;
          _lastError = 'MQTT credentials expired. Reconnecting...';
          notifyListeners();
          _requestAllLoads();
          _requestAllRooms();
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

      final clamped = brightness.clamp(0, 100);
      // Off/on logic for dimmers: sliding up from 0% must turn the load on,
      // and sliding to 0% must turn it off — the bus relay cannot be left
      // out of sync with the slider. We pair bri with swt so the load's
      // on/off state always matches the slider position.
      final isOn = clamped > 0;
      final cmd = <String, dynamic>{
        'bri': clamped,
        'swt': isOn,
      };

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': cmd,
      });

      publish('command/sndCmd', message);

      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['brightness'] = clamped;
        _loads[deviceId]!['isOn'] = isOn;
        _devices[deviceId]!['brightness'] = clamped;
        _devices[deviceId]!['isOn'] = isOn;
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

      // Tunable colour temperature is expressed in Kelvin on the wire —
      // the board's Tun action converts to Mired for the DPT7.600 bus write.
      final clamped = colorTemp.clamp(2000, 6500);
      // Pair colour-temp writes with swt=true so the load turns on when
      // the user actively tunes it. The user is interacting with the slider,
      // so leaving the relay in the previous state would be wrong.
      // (Old bug: swt was tied to `clamped > 2700`, which turned the lamp
      // OFF whenever the user dragged below 2700K.)
      final cmd = <String, dynamic>{
        'cTp': clamped,
        'swt': true,
      };

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': cmd,
      });

      publish('command/sndCmd', message);

      if (_loads.containsKey(deviceId)) {
        // Cache the value as Mired (1_000_000 / K) so reads stay consistent
        // with what the board publishes on status/+.
        final mired = clamped > 0 ? (1000000 / clamped).round() : 0;
        _loads[deviceId]!['cTp'] = mired;
        _loads[deviceId]!['isOn'] = true;
        _devices[deviceId]!['cTp'] = mired;
        _devices[deviceId]!['isOn'] = true;
        notifyListeners();
      }
    }
  }

  // RGB Control. Brightness rides along with every command: the board's
  // sndRGB computes the bus color from Val.Hue/Val.Sat/Val.Bri, and its
  // 'swt' path re-applies `Val.Bri > 0 ? Val.Bri : 100` — so an RGB
  // command without bri silently snaps to 100% on first use.
  void sendRGBCommand(String deviceId, int red, int green, int blue,
      {int? brightness}) {
    print('Sending RGB to OKAS: loadId=$deviceId, R=$red, G=$green, B=$blue');

    final load = _loads[deviceId];
    if (load != null) {
      final ldId = load['ldId'] as int? ?? int.tryParse(deviceId) ?? 1;
      final loadType = load['type'] as String? ?? 'rgb';

      final r = red.clamp(0, 255);
      final g = green.clamp(0, 255);
      final b = blue.clamp(0, 255);
      final bri = brightness?.clamp(0, 100);
      // The board's PAR_MAP expects HSV (Hue 0-360, Sat 0-100) for RGB
      // loads, not raw r/g/b. Without this conversion the bus write goes
      // through the unknown-parameter path and silently fails. Value is
      // carried as 'bri' (0-100), not folded into the hue/sat math.
      final hsv = _rgbToHsv(r, g, b);
      final cmd = <String, dynamic>{
        if (bri != null) 'bri': bri,
        'hue': hsv.hue,
        'sat': hsv.sat,
        // Sliding brightness to 0 must drop the relay, mirroring the
        // dimmer path (swt matches the slider position).
        'swt': bri == null || bri > 0,
      };

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': cmd,
      });

      publish('command/sndCmd', message);

      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['red'] = r;
        _loads[deviceId]!['green'] = g;
        _loads[deviceId]!['blue'] = b;
        _loads[deviceId]!['hue'] = hsv.hue;
        _loads[deviceId]!['sat'] = hsv.sat;
        if (bri != null) _loads[deviceId]!['brightness'] = bri;
        _loads[deviceId]!['isOn'] = bri == null || bri > 0;
        _devices[deviceId]!['red'] = r;
        _devices[deviceId]!['green'] = g;
        _devices[deviceId]!['blue'] = b;
        _devices[deviceId]!['hue'] = hsv.hue;
        _devices[deviceId]!['sat'] = hsv.sat;
        if (bri != null) _devices[deviceId]!['brightness'] = bri;
        _devices[deviceId]!['isOn'] = bri == null || bri > 0;
        notifyListeners();
      }
    }
  }

  /// RGB (0-255) -> HSV with hue in degrees (0-360) and saturation as a
  /// 0-100 percentage, matching what the board's `Hue`/`Sat` actions expect.
  _Hsv _rgbToHsv(int r, int g, int b) {
    final rn = r / 255.0;
    final gn = g / 255.0;
    final bn = b / 255.0;
    final maxC = [rn, gn, bn].reduce((a, b) => a > b ? a : b);
    final minC = [rn, gn, bn].reduce((a, b) => a < b ? a : b);
    final delta = maxC - minC;
    double hue = 0;
    if (delta != 0) {
      if (maxC == rn) {
        hue = 60 * (((gn - bn) / delta) % 6);
      } else if (maxC == gn) {
        hue = 60 * (((bn - rn) / delta) + 2);
      } else {
        hue = 60 * (((rn - gn) / delta) + 4);
      }
    }
    if (hue < 0) hue += 360;
    final double sat = maxC == 0 ? 0 : (delta / maxC) * 100;
    return _Hsv(hue, sat);
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
      // Use a STABLE client id (not a fresh timestamp one). After a
      // force-close, the broker may still hold the old TCP session; a
      // persistent id lets the new connection replace it immediately
      // instead of failing with "client already connected" and forcing a
      // keepalive-timeout wait (~30s). This is the main reason reconnection
      // after force-close took several seconds.
      const clientId = 'okas_app_stable';
      // Fresh connect params but keep the socket timeout short so a
      // dead connection is detected quickly.
      _client = MqttServerClient(host, clientId);
      _client!.port = port;
      _client!.secure = tls;
      _client!.keepAlivePeriod = 15;
      _client!.disconnectOnNoResponsePeriod = 8;
      _client!.setProtocolV311();
      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;

      final connectMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .keepAliveFor(15)
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
        // Clear stale cached rooms from any previous board so the UI does not
        // briefly show ghost rooms while we wait for the new board's response.
        // The board is the source of truth — its `rooms/set` reply (now
        // published with retain=true so the broker delivers it immediately
        // on subscribe) will populate the real list via `replaceRooms`.
        RoomService.instance.clearRooms();
        _roomsPrimed = false;
        _requestAllLoads();
        _requestAllRooms();
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
        _requestAllRooms();
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

      // Accept bus-speed (0..255) directly. The Fan sheet scales 0..100 to
      // 0..250 and then to 0..255; the HVAC sheet already produces 0..255
      // because the load's Smx tells the slider how many discrete steps to
      // expose. Clamping the input keeps both call sites safe regardless of
      // which range they happened to use.
      final okasSpeed = speed.clamp(0, 255);

      // Off/on logic for the fan: sliding all the way down to 0 must turn
      // the relay off, and sliding up from 0 must turn it on. The bus does
      // not infer the switch state from fSp alone, so we pair the speed
      // change with an explicit swt write so the load's on/off state stays
      // in sync with the slider position.
      final isOn = okasSpeed > 0;
      final cmd = <String, dynamic>{
        'fSp': okasSpeed,
        'swt': isOn,
      };

      final message = json.encode({
        'ldId': ldId,
        'typ': loadType,
        'cmd': cmd,
      });

      print('Publishing fan command: $message');
      publish('command/sndCmd', message);

      // Update local state immediately
      if (_loads.containsKey(deviceId)) {
        _loads[deviceId]!['fanSpeed'] = okasSpeed;
        _loads[deviceId]!['fSp'] = okasSpeed;
        _loads[deviceId]!['isOn'] = isOn;
        _devices[deviceId]!['fanSpeed'] = speed;
        _devices[deviceId]!['fSp'] = okasSpeed;
        _devices[deviceId]!['isOn'] = isOn;
        notifyListeners();
      }
    }
  }

  void addRoom(Map<String, dynamic> roomData) {
    publish('rooms/add', json.encode(roomData));
  }

  void deleteRoom(String roomId) {
    publish('rooms/delete', json.encode({'id': roomId}));
  }

  void updateRoom(Map<String, dynamic> roomData) {
    publish('rooms/add', json.encode(roomData));
  }

  void getRooms() {
    publish('rooms/get', '{}');
  }

  /// Syncs a room's favorite flag to the board so every device sees the
  /// same favorite room. The board replies on rooms/set with the full list.
  void setFavoriteRoom(String roomId, bool favorite) {
    publish(
      'rooms/add',
      json.encode({
        'id': roomId,
        'name': RoomService.instance.getRoomById(roomId)?.name ?? 'Room',
        'loads': RoomService.instance.getRoomById(roomId)?.loadIds ?? <String>[],
        'isFavorite': favorite,
      }),
    );
  }

  List<Map<String, dynamic>> getLoadsList() {
    return _loads.values.toList();
  }

  String _defaultLoadName(String type, int loadId) {
    switch (type) {
      case 'swt':
        return 'Switch $loadId';
      case 'dim':
        return 'Dimmer $loadId';
      case 'rgb':
        return 'RGB Light $loadId';
      case 'tun':
        return 'Tunable Light $loadId';
      case 'hvc':
        return 'AC $loadId';
      case 'fan':
        return 'Fan $loadId';
      case 'cur':
        return 'Curtain $loadId';
      case 'scn':
        return 'Scene $loadId';
      default:
        return 'Load $loadId';
    }
  }

  void _subscribeToTopics() {
    if (_client != null &&
        _client!.connectionStatus?.state == MqttConnectionState.connected) {
      const topics = [
        'loads/setLoads',
        'command/cmdAck',
        'status/+',
        'status/mobAck',
        'rooms/set',
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
        // Skip rebuild when this payload is identical to the one we just
        // processed (retained publish + getLoads reply arrive back-to-back
        // on fresh install).
        if (_isDuplicatePayload(topic, message)) {
          print('⏭ Skipped duplicate loads/setLoads payload');
          return;
        }
        _loads.clear();
        _devices.clear();
        _loadNameToId.clear();

        final List<dynamic> loads = data['lds'];
        for (var i = 0; i < loads.length; i++) {
          final load = loads[i];
          final loadId = i + 1;

          // FIX: Handle nullable values properly
          final loadType = load['typ'] as String? ?? load['type'] as String? ?? 'swt';
          final rawNm = load['nm'];
          final rawName = load['name'];
          String loadName;
          if (rawNm is String && rawNm.isNotEmpty) {
            loadName = rawNm;
          } else if (rawName is String && rawName.isNotEmpty) {
            loadName = rawName;
          } else {
            loadName = _defaultLoadName(loadType, loadId);
          }

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

          // RGB values — the board publishes HSV (hue/sat) for RGB loads,
          // not raw r/g/b. Fall back to r/g/b if present (older firmware or
          // edge devices), otherwise convert hue/sat to RGB at full value.
          int red = (sta?['r'] as int?) ?? -1;
          int green = (sta?['g'] as int?) ?? -1;
          int blue = (sta?['b'] as int?) ?? -1;
          if (red < 0 || green < 0 || blue < 0) {
            final hue = (sta?['hue'] as num?)?.toDouble() ?? 0.0;
            final sat = (sta?['sat'] as num?)?.toDouble() ?? 0.0;
            // HSV -> RGB at the reported brightness (bri 0-100) so the
            // cached color matches what the lamp actually shows.
            final v = (brightness > 0 ? brightness : 100) / 100.0;
            final h = hue % 360;
            final s = sat.clamp(0.0, 1.0);
            final c = v * s;
            final x = c * (1 - (((h / 60) % 2) - 1).abs());
            final m = v - c;
            double rp = 0, gp = 0, bp = 0;
            if (h < 60) {
              rp = c;
              gp = x;
            } else if (h < 120) {
              rp = x;
              gp = c;
            } else if (h < 180) {
              gp = c;
              bp = x;
            } else if (h < 240) {
              gp = x;
              bp = c;
            } else if (h < 300) {
              rp = x;
              bp = c;
            } else {
              rp = c;
              bp = x;
            }
            red = ((rp + m) * 255).round().clamp(0, 255);
            green = ((gp + m) * 255).round().clamp(0, 255);
            blue = ((bp + m) * 255).round().clamp(0, 255);
          }

          // HVAC values. Bus uses HomeKit TargetHeatingCoolingState values:
          // 0=OFF, 1=HEAT, 2=COOL, 3=AUTO. DRY (no HomeKit equivalent) is
          // mapped to COOL on the board, so case 2 covers both.
          String hvacMode = 'Cool';
          final modValue = sta?['mod'];
          if (modValue is int) {
            switch (modValue) {
              case 0:
                hvacMode = 'Off';
                break;
              case 1:
                hvacMode = 'Heat';
                break;
              case 2:
                hvacMode = 'Cool';
                break;
              case 3:
                hvacMode = 'Auto';
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
          // Fan-speed configuration comes from loadData.json (`Smx` = max
          // speed, `Fst` = step). Fall back to the Figma spec defaults
          // (5 speeds, step 1) when the load doesn't carry them, so a
          // board running an older config still gets a working slider.
          int fanSpeedMax = (load['Smx'] as int?) ?? 5;
          int fanSpeedStep = (load['Fst'] as int?) ?? 1;
          if (fanSpeedMax < 1) fanSpeedMax = 5;
          if (fanSpeedStep < 1) fanSpeedStep = 1;
          if (fanSpeedStep > fanSpeedMax) fanSpeedStep = fanSpeedMax;

          // Curtain position. The backend (mqttClnt.js gtLdSt) publishes
          // { cPs: current, tPs: target } for curtain loads. Earlier code
          // only looked for pos / cPs, missing tPs and leaving the slider
          // stuck at 0. Accept any of the three so the value always flows.
          final curtainPos = sta?['tPs'] as int? ??
              sta?['cPs'] as int? ??
              sta?['pos'] as int? ??
              0;

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
            'fanSpeedMax': fanSpeedMax,
            'fanSpeedStep': fanSpeedStep,
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
            'fanSpeedMax': fanSpeedMax,
            'fanSpeedStep': fanSpeedStep,
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

      // Handle rooms updates - board is the source of truth, replace list
      if (topic == 'rooms/set' && data.containsKey('rooms')) {
        // Skip rebuild when this payload is identical to the one we just
        // processed (retained publish + getRooms reply arrive back-to-back
        // on fresh install).
        if (_isDuplicatePayload(topic, message)) {
          print('⏭ Skipped duplicate rooms/set payload');
          return;
        }
        final roomsData = data['rooms'] as List<dynamic>;
        final newRooms = <Room>[];
        for (var roomJson in roomsData) {
          final room = Room(
            id: roomJson['id']?.toString() ?? '',
            name: roomJson['name']?.toString() ?? 'Unnamed',
            imagePath: roomJson['imagePath']?.toString(),
            loadIds: List<String>.from(
              (roomJson['loads'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList(),
            ),
            createdAt: DateTime.tryParse(roomJson['createdAt'] ?? '') ??
                DateTime.now(),
            isFavorite: roomJson['isFavorite'] == true,
          );
          newRooms.add(room);
        }
        // Replace entire rooms list to avoid duplicates
        RoomService.instance.replaceRooms(newRooms);
        _roomsPrimed = true;
        print('✅ Loaded ${newRooms.length} rooms from OKAS');
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

            // RGB: board sends HSV (hue/sat) — fall back to r/g/b when
            // available, otherwise derive RGB from HSV at full value so the
            // picker stays in sync with the live bus state.
            int? nr = sta['r'] as int?;
            int? ng = sta['g'] as int?;
            int? nb = sta['b'] as int?;
            if (nr == null || ng == null || nb == null) {
              final hue = (sta['hue'] as num?)?.toDouble();
              final sat = (sta['sat'] as num?)?.toDouble();
              if (hue != null && sat != null) {
                final h = hue % 360;
                final s = sat.clamp(0.0, 1.0);
                // Dim by the reported bri so the picker shows the real color.
                final bri = sta['bri'] as num? ?? 100;
                final v = (bri > 0 ? bri : 100) / 100.0;
                final c = v * s;
                final x = c * (1 - (((h / 60) % 2) - 1).abs());
                final m = v - c;
                double rp = 0, gp = 0, bp = 0;
                if (h < 60) {
                  rp = c;
                  gp = x;
                } else if (h < 120) {
                  rp = x;
                  gp = c;
                } else if (h < 180) {
                  gp = c;
                  bp = x;
                } else if (h < 240) {
                  gp = x;
                  bp = c;
                } else if (h < 300) {
                  rp = x;
                  bp = c;
                } else {
                  rp = c;
                  bp = x;
                }
                nr = ((rp + m) * 255).round().clamp(0, 255);
                ng = ((gp + m) * 255).round().clamp(0, 255);
                nb = ((bp + m) * 255).round().clamp(0, 255);
              }
            }
            if (nr != null) load['red'] = nr;
            if (ng != null) load['green'] = ng;
            if (nb != null) load['blue'] = nb;

            // Handle HVAC mode. The bus uses HomeKit
            // TargetHeatingCoolingState values: 0=OFF, 1=HEAT, 2=COOL, 3=AUTO.
            // DRY has no HomeKit equivalent — the board maps it to COOL (2).
            final modValue = sta['mod'];
            if (modValue is int) {
              switch (modValue) {
                case 0:
                  load['hvacMode'] = 'Off';
                  break;
                case 1:
                  load['hvacMode'] = 'Heat';
                  break;
                case 2:
                  load['hvacMode'] = 'Cool';
                  break;
                case 3:
                  load['hvacMode'] = 'Auto';
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

            // Handle curtain position — same fallback chain as in the
            // initial loads/setLoads parse so the live status update matches
            // what was seeded from the retained topic.
            final newPos = sta['tPs'] ?? sta['cPs'] ?? sta['pos'] ?? load['cPs'];
            load['cPs'] = newPos;
            load['pos'] = newPos;
            load['tPs'] = newPos;

            // Update devices map
            if (_devices.containsKey(ldId)) {
              _devices[ldId]!.addAll(load);
            }

            // Only notify when the state actually changed. The board
            // republishes status/{ldId} with retain=true on subscribe and
            // after every command ack — an unchanged payload would otherwise
            // trigger a full UI rebuild (grid flicker) for every load on
            // every connect. The ts field is stripped before comparing.
            final before = _lastStatusHash[ldId];
            final after = _normalizePayload(message);
            if (before == after) {
              print('⏭ Skipped duplicate status for load $ldId');
              return;
            }
            _lastStatusHash[ldId] = after;
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
              // Curtain ack: update tPs (target) and cPs (current) if the
              // ack payload includes them. Some loads only include tPs.
              if (cSt['tPs'] != null || cSt['cPs'] != null || cSt['pos'] != null) {
                final ackPos = cSt['tPs'] ?? cSt['cPs'] ?? cSt['pos'];
                _loads[loadId]!['cPs'] = ackPos;
                _loads[loadId]!['pos'] = ackPos;
                _loads[loadId]!['tPs'] = ackPos;
              }

              if (_devices.containsKey(loadId)) {
                _devices[loadId]!['isOn'] =
                    cSt['on'] ?? _devices[loadId]!['isOn'];
                _devices[loadId]!['brightness'] =
                    cSt['bri'] ?? _devices[loadId]!['brightness'];
                if (cSt['tPs'] != null || cSt['cPs'] != null || cSt['pos'] != null) {
                  final ackPos = cSt['tPs'] ?? cSt['cPs'] ?? cSt['pos'];
                  _devices[loadId]!['cPs'] = ackPos;
                  _devices[loadId]!['pos'] = ackPos;
                  _devices[loadId]!['tPs'] = ackPos;
                }
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

  /// Ask the board for its current rooms list. The board replies on
  /// `rooms/set` which we handle in `_handleMessage`. This is what makes the
  /// Rooms tab reflect the actual board state instead of any stale cache
  /// from a previously-configured board.
  void _requestAllRooms() {
    publish('rooms/get', '{}');
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
      // Kill the auto-reconnect loop before tearing down. mqtt_client's
      // disconnect() leaves autoReconnect=true, so the old client keeps
      // reconnecting and fights a fresh client over the same client id.
      _client!.autoReconnect = false;
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
    WidgetsBinding.instance.removeObserver(this);
    _credentialExpiryTimer?.cancel();
    disconnect();
    super.dispose();
  }
}
