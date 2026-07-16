// device_service.dart
// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_command.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_state.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device_trigger.dart';
import 'package:smart_home_animation/core/shared/domain/entities/sensor_config.dart';

import 'i_device_service.dart'; // Import the interface

class MQTTDeviceService implements IDeviceService {
  late MqttServerClient _client;
  final StreamController<DeviceState> _stateController =
      StreamController<DeviceState>.broadcast();
  final String _broker;
  final int _port;
  final String _clientIdentifier;
  bool _connected = false;
  final String? _username;
  final String? _password;

  // Store subscriptions to manage them
  final Set<String> _subscribedTopics = {};

  MQTTDeviceService({
    required String broker,
    required int port,
    String? clientIdentifier,
    String? username,
    String? password,
  }) : _broker = broker,
       _port = port,
       _clientIdentifier =
           clientIdentifier ?? 'okas${DateTime.now().millisecondsSinceEpoch}',
       _username = username,
       _password = password {
    _initializeClient();
  }

  void _initializeClient() {
    // Initialize with the correct client type
    _client = MqttServerClient(_broker, _clientIdentifier);
    _client.port = _port;
    _client.logging(on: true);
    _client.keepAlivePeriod = 60;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.onSubscribed = _onSubscribed;
    // Enable auto-reconnect
    _client.autoReconnect = true;

    // IMPORTANT: Disable secure connection for local network
    _client.secure = false;

    // Set username and password if provided
    if (_username != null && _password != null) {
      _client.setProtocolV311();
      // Credentials are set in the connect message
    }
    // _client.autoReconnectInterval = Duration(seconds: 5);
  }

  void _onConnected() {
    debugPrint('✅ MQTT Connected to $_broker:$_port');
    _connected = true;
  }

  void _onDisconnected() {
    debugPrint('⚠️ MQTT Disconnected');
    _connected = false;
  }

  void _onSubscribed(String topic) {
    debugPrint('📡 Subscribed to: $topic');
    _subscribedTopics.add(topic);
  }

  @override
  Future<bool> connect() async {
    try {
      debugPrint('🔌 Connecting to MQTT broker at $_broker:$_port...');

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientIdentifier)
          .keepAliveFor(60)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      // Set username and password if provided - using the correct method
      if (_username != null && _password != null) {
        // Method 1: Set via the client's connection message
        connMessage.authenticateAs(_username, _password);
      }

      _client.connectionMessage = connMessage;

      await _client.connect();

      if (_client.connectionStatus?.state == MqttConnectionState.connected) {
        await _subscribeToStateTopics();
        _client.updates?.listen(_handleIncomingMessages);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ MQTT Connection error: $e');
      return false;
    }
  }

  // Subscribe to all state topics to receive retained messages
  Future<void> _subscribeToStateTopics() async {
    // Subscribe to device state topics (with retain flag, will receive latest state immediately)
    _client.subscribe('ohknx/sta/+/+/state', MqttQos.atLeastOnce);
    _client.subscribe('ohknx/sta/+/+/bri', MqttQos.atLeastOnce);
    _client.subscribe('ohknx/sta/+/+/temp', MqttQos.atLeastOnce);
    _client.subscribe('ohknx/sta/+/+/pos', MqttQos.atLeastOnce);
    _client.subscribe('ohknx/sta/+/+/color', MqttQos.atLeastOnce);
    _client.subscribe('sensors/+/reading', MqttQos.atLeastOnce);

    // Subscribe to system topics
    _client.subscribe('ohknx/sys/status', MqttQos.atLeastOnce);
    _client.subscribe('ohknx/sys/sign', MqttQos.atLeastOnce);

    // _client.updates?.listen(_handleIncomingMessages);
    debugPrint(
      '📡 Subscribed to state topics (retained messages will be received)',
    );
  }

  void _handleIncomingMessages(
    List<MqttReceivedMessage<MqttMessage>> messages,
  ) {
    for (var message in messages) {
      final topic = message.topic;
      final payload = message.payload as MqttPublishMessage;
      final payloadBytes = payload.payload.message;
      final payloadString = utf8.decode(payloadBytes);

      debugPrint(
        '📨 MQTT Message received - Topic: $topic, Payload: $payloadString',
      );

      // Parse the topic to extract information
      final topicParts = topic.split('/');
      if (topicParts.length >= 4 && topicParts[1] == 'sta') {
        final roomId = topicParts[2];
        final loadId = topicParts[3];
        final property = topicParts[4];

        // Convert payload to appropriate value
        dynamic value;
        switch (property) {
          case 'state':
            value =
                payloadString == 'ON' ||
                payloadString == 'true' ||
                payloadString == '1';
            break;
          case 'bri':
          case 'pos':
          case 'temp':
            value = double.tryParse(payloadString) ?? 0;
            break;
          case 'color':
            value = payloadString;
            break;
          default:
            value = payloadString;
        }

        // Create DeviceState object - FIXED: always provide a boolean for isOn
        final bool isOnValue = property == 'state'
            ? (value == true)
            : false; // Default to false for non-state properties

        // Build attributes map
        final Map<String, dynamic> attributes = {'roomId': roomId};

        // Add property-specific value
        switch (property) {
          case 'bri':
            attributes['intensity'] = value;
            break;
          case 'temp':
            attributes['temperature'] = value;
            break;
          case 'pos':
            attributes['position'] = value;
            break;
          case 'color':
            attributes['color'] = value;
            break;
        }

        // Create DeviceState object
        final deviceState = DeviceState(
          deviceId: loadId,
          isOn: isOnValue, // Now always a boolean
          intensity: property == 'bri' ? value : null,
          temperature: property == 'temp' ? value : null,
          mode: null,
          fanSpeed: null,
          lastUpdated: DateTime.now(),
          additionalData: {
            'topic': topic,
            'property': property,
            'value': value,
          },
          attributes: attributes,
        );

        _stateController.add(deviceState);
      }
    }
  }

  // Publish command to device (using set topic)
  @override
  Future<void> sendCommand(DeviceCommand command) async {
    if (!_connected) {
      debugPrint('⚠️ MQTT not connected, cannot send command');
      return;
    }

    try {
      // Determine the topic and payload based on command
      final deviceId = command.deviceId;
      final roomId = command.parameters['roomId'] ?? '1';
      String topic;
      String payload;

      switch (command.command) {
        case 'ON':
          topic = 'ohknx/set/$roomId/$deviceId/state';
          payload = 'ON';
          break;
        case 'OFF':
          topic = 'ohknx/set/$roomId/$deviceId/state';
          payload = 'OFF';
          break;
        case 'SET_BRIGHTNESS':
          topic = 'ohknx/set/$roomId/$deviceId/bri';
          payload = command.value ?? '0';
          break;
        case 'SET_TEMPERATURE':
          topic = 'ohknx/set/$roomId/$deviceId/temp';
          payload = command.value ?? '22';
          break;
        case 'SET_POSITION':
          topic = 'ohknx/set/$roomId/$deviceId/pos';
          payload = command.value ?? '0';
          break;
        case 'SET_COLOR':
          topic = 'ohknx/set/$roomId/$deviceId/color';
          payload = command.value ?? '#FFFFFF';
          break;
        default:
          debugPrint('⚠️ Unknown command: ${command.command}');
          return;
      }

      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);

      _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

      debugPrint('📤 Command published - Topic: $topic, Payload: $payload');
    } catch (e) {
      debugPrint('❌ Error sending command: $e');
    }
  }

  // Request current state for a specific device
  Future<void> requestDeviceState(String deviceId, String roomId) async {
    if (!_connected) return;

    // Publish a state request (device should respond with retained message)
    final topic = 'ohknx/sys/state/request';
    final payload = json.encode({
      'deviceId': deviceId,
      'roomId': roomId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  @override
  Stream<DeviceState> get deviceStateStream => _stateController.stream;

  Future<void> disconnect() async {
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      _client.disconnect();
    }
    await _stateController.close();
    _connected = false;
    debugPrint('🔌 MQTT Disconnected');
  }

  @override
  Future<List<Device>> discoverDevices() async {
    // Devices will be discovered via MQTT messages and HTTP API
    return [];
  }

  @override
  Future<void> configureSensor(String sensorId, SensorConfig config) async {}

  @override
  Future<void> setTrigger(DeviceTrigger trigger) async {}

  @override
  Future<void> updateDeviceState(DeviceState state) async {}

  @override
  Future<DeviceState?> getDeviceState(String deviceId) async => null;
}
