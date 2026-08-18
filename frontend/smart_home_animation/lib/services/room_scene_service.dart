// lib/services/room_scene_service.dart
// Persistence + activation for app-side scenes (RoomScene). Scenes are
// stored locally (SharedPreferences JSON), same pattern as RoomService.
// A scene is activated by replaying its per-load settings over MQTT using
// the existing DirectMQTTService commands, staggered ~120ms so the board's
// coalescer keeps bus writes clean.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_animation/core/shared/domain/entities/room_scene.dart';
import 'package:smart_home_animation/services/direct_mqtt_service.dart';
import 'package:smart_home_animation/services/quick_select_service.dart';
import 'package:smart_home_animation/services/scene_favorites_service.dart';

class RoomSceneService extends ChangeNotifier {
  RoomSceneService._();

  static final RoomSceneService instance = RoomSceneService._();
  static const _storageKey = 'saved_room_scenes';

  final Map<String, RoomScene> _scenes = {};
  bool _loaded = false;
  // Scenes currently activated (long-press toggles in/out). Kept here so
  // cards stay lit across navigation and deactivation can turn loads off.
  final Set<String> _activeSceneIds = {};
  final Map<String, List<Timer>> _pendingTimers = {};
  // Live board state captured right before activation (sceneId -> loadId ->
  // load fields), so deactivation can restore loads to what they were.
  final Map<String, Map<String, Map<String, dynamic>>> _snapshots = {};
  // Live bus to the board's broker. Scenes are mirrored to the board as a
  // retained MQTT payload (topic 'app/scenes') so they survive an app
  // storage clear — the broker (on the board) keeps the last list, like
  // the board's own rooms/set. Attached by DirectMQTTService on connect.
  DirectMQTTService? _mqtt;

  List<RoomScene> get scenes => _scenes.values.toList();

  bool isActive(String id) => _activeSceneIds.contains(id);

  void attachMqtt(DirectMQTTService mqtt) => _mqtt = mqtt;

  void detachMqtt() => _mqtt = null;

  /// Mirrors the current scene list to the board's broker as a retained
  /// payload. Fire-and-forget: if the bus is down the local copy stays and
  /// the next online mutation re-publishes the full list.
  Future<void> _persistToBoard() async {
    final mqtt = _mqtt;
    if (mqtt == null || !mqtt.isConnected) return;
    mqtt.publishRetained(
      'app/scenes',
      jsonEncode(_scenes.values.map((s) => s.toJson()).toList()),
    );
  }

  /// Replaces the local scene list with the board's retained payload (the
  /// broker delivers it right after (re)connect). Called by
  /// DirectMQTTService; the board is the source of truth, same as rooms.
  void hydrateFromBoard(String payload) {
    try {
      final values = (jsonDecode(payload) as List).cast<Map<String, dynamic>>();
      final hydrated = <String, RoomScene>{};
      for (final value in values) {
        final scene = RoomScene.fromJson(value);
        hydrated[scene.id] = scene;
      }
      _scenes
        ..clear()
        ..addAll(hydrated);
      // Drop active markers for scenes that no longer exist on the board.
      final known = hydrated.keys.toSet();
      _activeSceneIds.removeWhere((id) => !known.contains(id));
      _cancelAllPending();
      notifyListeners();
      _save();
    } catch (_) {
      // Malformed payload (e.g. board echoed nothing useful): keep local.
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final values = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        for (final value in values) {
          final scene = RoomScene.fromJson(value);
          _scenes[scene.id] = scene;
        }
      } catch (_) {
        _scenes.clear();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  List<RoomScene> forRoom(String roomId) => _scenes.values
      .where((s) => s.roomId == roomId)
      .toList(growable: false);

  RoomScene? getScene(String id) => _scenes[id];

  Future<void> addScene(RoomScene scene) async {
    _scenes[scene.id] = scene;
    await _save();
    notifyListeners();
    _persistToBoard();
  }

  Future<void> updateScene(RoomScene scene) async {
    _scenes[scene.id] = scene;
    await _save();
    notifyListeners();
    _persistToBoard();
  }

  Future<void> deleteScene(String id) async {
    final scene = _scenes.remove(id);
    _activeSceneIds.remove(id);
    _cancelPending(id);
    _snapshots.remove(id);
    if (scene != null) {
      // Clear every other surface the scene's shortcut id is pinned to.
      await QuickSelectService.instance.removeFromRoom(
        roomId: scene.roomId,
        loadId: 'appscene-$id',
      );
      await SceneFavoritesService.instance.removeFavorite('appscene-$id');
    }
    await _save();
    notifyListeners();
    _persistToBoard();
  }

  /// Wipes all scenes locally. Called on broker (re)connect, next to
  /// RoomService.clearRooms(), so scenes never reference loads from a
  /// previous board. The board's retained 'app/scenes' payload
  /// rehydrates the real list right after (re)connect — this wipe is
  /// intentionally NOT persisted to the board.
  Future<void> clearAll() async {
    _scenes.clear();
    _activeSceneIds.clear();
    _snapshots.clear();
    _cancelAllPending();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_scenes.values.map((s) => s.toJson()).toList()),
    );
  }

  /// Replays the scene's per-load settings over MQTT, staggered so rapid
  /// writes don't slam the bus. Scenes are fire-and-forget: load state is
  /// echoed back by the board's status handler.
  void activateScene(DirectMQTTService mqtt, RoomScene scene) {
    _cancelPending(scene.id);
    _snapshots[scene.id] = _captureState(mqtt, scene);
    var delay = 0;
    final timers = <Timer>[];
    for (final setting in scene.loads) {
      delay += 120;
      timers.add(Timer(Duration(milliseconds: delay), () {
        _sendSetting(mqtt, setting);
      }));
    }
    _pendingTimers[scene.id] = timers;
    _activeSceneIds.add(scene.id);
    notifyListeners();
  }

  /// Copies the live board state of every load in the scene BEFORE the
  /// scene's settings are applied, so deactivation can restore it.
  Map<String, Map<String, dynamic>> _captureState(
    DirectMQTTService mqtt,
    RoomScene scene,
  ) {
    final snap = <String, Map<String, dynamic>>{};
    for (final s in scene.loads) {
      final live = mqtt.loads[s.loadId];
      if (live != null) snap[s.loadId] = Map<String, dynamic>.from(live);
    }
    return snap;
  }

  /// Reverts every load in the scene to its pre-activation state. Loads
  /// with no captured state (never seen on the bus) fall back to OFF.
  void deactivateScene(DirectMQTTService mqtt, RoomScene scene) {
    _cancelPending(scene.id);
    final snap = _snapshots.remove(scene.id);
    for (final s in scene.loads) {
      final captured = snap?[s.loadId];
      if (captured != null) {
        _sendSetting(mqtt, _settingFromState(s, captured));
      } else {
        _sendOff(mqtt, s);
      }
    }
    _activeSceneIds.remove(scene.id);
    notifyListeners();
  }

  /// Builds the load's settings from a captured live-state map — the
  /// inverse of [SceneLoadSetting], so _sendSetting replays exactly what
  /// the load was doing before activation.
  SceneLoadSetting _settingFromState(
    SceneLoadSetting base,
    Map<String, dynamic> st,
  ) {
    return SceneLoadSetting(
      loadId: base.loadId,
      type: base.type,
      isOn: st['isOn'] == true,
      brightness: st['brightness'] as int?,
      colorTempK: st['cTp'] as int?,
      red: st['red'] as int?,
      green: st['green'] as int?,
      blue: st['blue'] as int?,
      hvacMode: st['hvacMode'] as String?,
      temp: st['temp'] as int?,
      fanSpeed: st['fanSpeed'] as int?,
      curtainPos: st['pos'] as int?,
    );
  }

  /// Fallback OFF for loads with no captured state (boards dim/tun/rgb by
  /// brightness 0, curtains by pos 0, everything else by command OFF).
  void _sendOff(DirectMQTTService mqtt, SceneLoadSetting s) {
    switch (s.type) {
      case 'dim':
      case 'tun':
      case 'rgb':
        mqtt.sendBrightnessCommand(s.loadId, 0);
      case 'cur':
        mqtt.sendCurtainPositionCommand(s.loadId, 0);
      default:
        mqtt.sendCommand(s.loadId, 'OFF');
    }
  }

  /// Long-press acts as a toggle: activate if off, deactivate if on.
  void toggleScene(DirectMQTTService mqtt, RoomScene scene) {
    if (_activeSceneIds.contains(scene.id)) {
      deactivateScene(mqtt, scene);
    } else {
      activateScene(mqtt, scene);
    }
  }

  void _cancelPending(String id) {
    _pendingTimers.remove(id)?.forEach((t) => t.cancel());
  }

  void _cancelAllPending() {
    for (final timers in _pendingTimers.values) {
      for (final t in timers) {
        t.cancel();
      }
    }
    _pendingTimers.clear();
  }

  void _sendSetting(DirectMQTTService mqtt, SceneLoadSetting s) {
    switch (s.type) {
      case 'swt':
        mqtt.sendCommand(s.loadId, s.isOn ? 'ON' : 'OFF');
      case 'dim':
        if (s.brightness != null) {
          // bri self-manages the relay on the board (bri>0 => on, 0 => off).
          mqtt.sendBrightnessCommand(s.loadId, s.brightness!);
        } else if (!s.isOn) {
          mqtt.sendCommand(s.loadId, 'OFF');
        }
      case 'tun':
        if (s.colorTempK != null) {
          mqtt.sendColorTempCommand(s.loadId, s.colorTempK!);
        }
        if (s.brightness != null) {
          mqtt.sendBrightnessCommand(s.loadId, s.brightness!);
        } else if (!s.isOn) {
          mqtt.sendCommand(s.loadId, 'OFF');
        }
      case 'rgb':
        mqtt.sendRGBCommand(
          s.loadId,
          s.red ?? 255,
          s.green ?? 255,
          s.blue ?? 255,
          brightness: s.brightness ?? (s.isOn ? 100 : 0),
        );
      case 'hvc':
        mqtt.sendCommand(s.loadId, s.isOn ? 'ON' : 'OFF');
        if (s.hvacMode != null) mqtt.sendHVACModeCommand(s.loadId, s.hvacMode!);
        if (s.temp != null) mqtt.sendTemperatureCommand(s.loadId, s.temp!);
        if (s.fanSpeed != null) mqtt.sendFanSpeedCommand(s.loadId, s.fanSpeed!);
      case 'cur':
        mqtt.sendCurtainPositionCommand(s.loadId, s.curtainPos ?? 0);
      default:
        mqtt.sendCommand(s.loadId, s.isOn ? 'ON' : 'OFF');
    }
  }
}