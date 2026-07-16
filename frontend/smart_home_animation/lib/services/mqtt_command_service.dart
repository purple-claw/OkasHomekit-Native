// lib/services/mqtt_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';

class MQTTService extends ChangeNotifier {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;

  MQTTService._internal();

  MqttServerClient? _client;
  bool _isConnected = false;
  bool _isConnecting = false;
  Map<String, Device> _devices = {};
  StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  StreamController<String> _messageController =
      StreamController<String>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  Stream<String> get messages => _messageController.stream;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  Map<String, Device> get devices => _devices;

  Future<bool> connect({String? host, int port = 1884}) async {
    if (_isConnecting) return false;

    _isConnecting = true;
    notifyListeners();

    try {
      final brokerHost = host ?? '192.168.1.164';
      final clientId =
          'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

      _client = MqttServerClient(brokerHost, clientId);
      _client!.port = port;
      _client!.keepAlivePeriod = 60;
      _client!.setProtocolV311();
      _client!.autoReconnect = true;

      _client!.onConnected = () {
        _isConnected = true;
        _isConnecting = false;
        _connectionStatusController.add(true);
        notifyListeners();
        _subscribeToTopics();
      };

      _client!.onDisconnected = () {
        _isConnected = false;
        _isConnecting = false;
        _connectionStatusController.add(false);
        notifyListeners();
      };

      print('Connecting to $brokerHost:$port...');
      await _client!.connect();

      _isConnecting = false;
      return true;
    } catch (e) {
      print('Connection error: $e');
      _isConnected = false;
      _isConnecting = false;
      _connectionStatusController.add(false);
      notifyListeners();
      return false;
    }
  }

  void _subscribeToTopics() {
    if (_client != null &&
        _client!.connectionStatus?.state == MqttConnectionState.connected) {
      const topics = [
        'home/+/light',
        'home/+/temperature',
        'home/+/status',
        'command/+/response', // Add command response topic
      ];

      for (String topic in topics) {
        _client!.subscribe(topic, MqttQos.atLeastOnce);
      }

      _client!.updates!.listen((
        List<MqttReceivedMessage<MqttMessage>> messages,
      ) {
        for (var message in messages) {
          final payload = message.payload as MqttPublishMessage;
          final text = MqttPublishPayload.bytesToStringAsString(
            payload.payload.message,
          );
          print('📨 Received on ${message.topic}: $text');
          _messageController.add('${message.topic}: $text');

          // Handle different message types
          _handleIncomingMessage(message.topic, text);
        }
      });
    }
  }

  void _handleIncomingMessage(String topic, String message) {
    try {
      final data = json.decode(message);
      // Handle different topic patterns
      if (topic.startsWith('command/') && topic.endsWith('/response')) {
        // Handle command response
        print('Command response: $data');
      } else if (topic.contains('/status')) {
        // Handle device status updates
        print('Device status update: $data');
      }
    } catch (e) {
      // Not JSON, handle as plain text
      print('Plain message: $message');
    }
  }

  Future<void> publish(String topic, String message) async {
    if (_client != null && _isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('📤 Published to $topic: $message');
    } else {
      print('Cannot publish - not connected');
    }
  }

  Future<void> sendCommand(
    int loadId,
    String type,
    Map<String, dynamic> cmd,
  ) async {
    if (!_isConnected) {
      print('Cannot send command - not connected to MQTT');
      return;
    }

    if (_client == null) {
      print('MQTT client is null');
      return;
    }

    try {
      final payload = json.encode({
        'ldId': loadId,
        'typ': type,
        'cmd': cmd,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client!.publishMessage(
        'command/sndCmd',
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('Command sent: loadId=$loadId, type=$type, cmd=$cmd');
    } catch (e) {
      print('Error sending command: $e');
    }
  }

  Future<void> sendSceneCommand(int loadId, Map<String, dynamic> cmd) async {
    await sendCommand(loadId, 'scn', cmd);
  }

  Future<void> disconnect() async {
    if (_client != null) {
      _client!.disconnect();
      _isConnected = false;
      _connectionStatusController.add(false);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectionStatusController.close();
    _messageController.close();
    disconnect();
    super.dispose();
  }
}
