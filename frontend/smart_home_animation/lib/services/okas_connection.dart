// lib/services/okas_connection.dart
// ignore_for_file: unused_field

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class OKASConnection extends ChangeNotifier {
  static const String OKAS_IP = '192.168.1.152'; // Updated
  static const List<int> PORTS = [1884, 1883, 8883];

  late MqttServerClient _client;
  bool _isConnected = false;
  String? _connectedPort;

  final Map<String, Map<String, dynamic>> _devices = {};
  final Map<String, dynamic> _rooms = {};

  bool get isConnected => _isConnected;
  Map<String, Map<String, dynamic>> get devices => _devices;
  Map<String, dynamic> get rooms => _rooms;

  Future<bool> connect() async {
    for (int port in PORTS) {
      print('Trying port $port...');
      final success = await _tryConnect(port);
      if (success) {
        _connectedPort = port.toString();
        return true;
      }
    }
    print('❌ Failed to connect on all ports');
    return false;
  }

  Future<bool> _tryConnect(int port) async {
    _client = MqttServerClient(
      OKAS_IP,
      'flutter_${DateTime.now().millisecondsSinceEpoch}',
    );
    _client.port = port;
    _client.logging(on: true);
    _client.keepAlivePeriod = 60;
    _client.autoReconnect = false;
    _client.setProtocolV311();

    final connMessage = MqttConnectMessage()
        .keepAliveFor(60)
        .startClean()
        .authenticateAs('okasapi', 'okas1234');

    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
      _isConnected =
          _client.connectionStatus?.state == MqttConnectionState.connected;

      if (_isConnected) {
        print('✅ Connected to OKAS at $OKAS_IP:$port');
        _subscribeToTopics();
        _requestLoads();
        _client.updates?.listen(_handleMessage);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Port $port failed: $e');
      _isConnected = false;
      return false;
    }
  }

  void _subscribeToTopics() {
    _client.subscribe('loads/setLoads', MqttQos.atLeastOnce);
    _client.subscribe('command/cmdAck', MqttQos.atLeastOnce);
    _client.subscribe('status/+', MqttQos.atLeastOnce);
  }

  void _requestLoads() {
    final builder = MqttClientPayloadBuilder();
    builder.addString('{}');
    _client.publishMessage(
      'loads/getLoads',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    print('📤 Requested loads from device');
  }

  void _handleMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (var message in messages) {
      final topic = message.topic;
      final payload = utf8.decode(
        (message.payload as MqttPublishMessage).payload.message,
      );
      print('📨 MQTT: $topic = $payload');

      try {
        final data = json.decode(payload);
        if (topic == 'loads/setLoads') {
          _handleLoadList(data);
        }
      } catch (e) {
        print('Error parsing: $e');
      }
    }
  }

  void _handleLoadList(Map<String, dynamic> data) {
    final loads = data['lds'] as List? ?? [];
    print('📦 Received ${loads.length} loads');

    for (int i = 0; i < loads.length; i++) {
      final load = loads[i];
      final loadId = (i + 1).toString();

      _devices[loadId] = {
        'id': loadId,
        'name': load['nm'] ?? 'Unknown',
        'type': load['typ'] ?? 'swt',
        'isOn': load['sta']?['on'] ?? false,
        'brightness': load['sta']?['bri'],
        // Curtain position: backend publishes tPs (target) and cPs (current).
        // Read tPs first so the slider reflects where the curtain is going.
        'position': load['sta']?['tPs'] ?? load['sta']?['cPs'] ?? load['sta']?['pos'],
      };

      final roomName = _extractRoomName(load['nm'] ?? '');
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
    return 'General';
  }

  Future<void> sendCommand(
    String deviceId,
    String command, {
    dynamic value,
  }) async {
    if (!_isConnected) return;

    final device = _devices[deviceId];
    if (device == null) return;

    final type = device['type'];
    Map<String, dynamic> cmd = {};

    if (command == 'ON')
      cmd = {'swt': true};
    else if (command == 'OFF')
      cmd = {'swt': false};
    else if (command == 'SET_BRIGHTNESS')
      cmd = {'bri': value};

    final payload = json.encode({
      'ldId': int.parse(deviceId),
      'typ': type,
      'cmd': cmd,
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client.publishMessage(
      'command/sndCmd',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    print('📤 Command sent: $payload');
  }

  void disconnect() {
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      _client.disconnect();
    }
    _isConnected = false;
    notifyListeners();
  }
}
