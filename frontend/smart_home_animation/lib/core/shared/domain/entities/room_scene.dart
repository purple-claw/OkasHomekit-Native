// lib/core/shared/domain/entities/room_scene.dart
// App-side "software scene": a group of loads (from ONE room) with
// predefined settings. Distinct from board/KNX scenes (type 'scn' loads):
// those are uploaded to the board by the programmer and activated with a
// single command; a RoomScene lives in the app and is replayed by sending
// the per-load commands it captured.
import 'package:flutter/material.dart';

/// One load entry inside a RoomScene: the load id + the exact settings to
/// apply when the scene activates. Fields are null when irrelevant for
/// that load type (e.g. brightness for a plain switch).
class SceneLoadSetting {
  const SceneLoadSetting({
    required this.loadId,
    required this.type,
    this.isOn = true,
    this.brightness,
    this.colorTempK,
    this.red,
    this.green,
    this.blue,
    this.hvacMode,
    this.temp,
    this.fanSpeed,
    this.curtainPos,
  });

  final String loadId;
  final String type; // swt | dim | tun | rgb | hvc | fan | cur
  final bool isOn;
  final int? brightness; // 0-100
  final int? colorTempK; // 2000-6500 (Kelvin; sent as Mired like the app does)
  final int? red;
  final int? green;
  final int? blue; // 0-255
  final String? hvacMode; // Cool | Heat | Auto | Dry
  final int? temp; // °C
  final int? fanSpeed;
  final int? curtainPos; // 0-100

  Map<String, dynamic> toJson() => {
    'loadId': loadId,
    'type': type,
    'isOn': isOn,
    if (brightness != null) 'brightness': brightness,
    if (colorTempK != null) 'colorTempK': colorTempK,
    if (red != null) 'red': red,
    if (green != null) 'green': green,
    if (blue != null) 'blue': blue,
    if (hvacMode != null) 'hvacMode': hvacMode,
    if (temp != null) 'temp': temp,
    if (fanSpeed != null) 'fanSpeed': fanSpeed,
    if (curtainPos != null) 'curtainPos': curtainPos,
  };

  factory SceneLoadSetting.fromJson(Map<String, dynamic> json) =>
      SceneLoadSetting(
        loadId: json['loadId'] as String,
        type: json['type'] as String? ?? 'swt',
        isOn: json['isOn'] as bool? ?? true,
        brightness: json['brightness'] as int?,
        colorTempK: json['colorTempK'] as int?,
        red: json['red'] as int?,
        green: json['green'] as int?,
        blue: json['blue'] as int?,
        hvacMode: json['hvacMode'] as String?,
        temp: json['temp'] as int?,
        fanSpeed: json['fanSpeed'] as int?,
        curtainPos: json['curtainPos'] as int?,
      );

  SceneLoadSetting copyWith({bool? isOn, int? brightness, int? colorTempK,
    int? red, int? green, int? blue, String? hvacMode, int? temp,
    int? fanSpeed, int? curtainPos}) => SceneLoadSetting(
    loadId: loadId,
    type: type,
    isOn: isOn ?? this.isOn,
    brightness: brightness ?? this.brightness,
    colorTempK: colorTempK ?? this.colorTempK,
    red: red ?? this.red,
    green: green ?? this.green,
    blue: blue ?? this.blue,
    hvacMode: hvacMode ?? this.hvacMode,
    temp: temp ?? this.temp,
    fanSpeed: fanSpeed ?? this.fanSpeed,
    curtainPos: curtainPos ?? this.curtainPos,
  );
}

class RoomScene {
  const RoomScene({
    required this.id,
    required this.roomId,
    required this.name,
    required this.iconId,
    required this.loads,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String name;
  final String iconId;
  final List<SceneLoadSetting> loads;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'roomId': roomId,
    'name': name,
    'iconId': iconId,
    'loads': loads.map((l) => l.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory RoomScene.fromJson(Map<String, dynamic> json) => RoomScene(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    name: json['name'] as String? ?? 'Scene',
    iconId: json['iconId'] as String? ?? 'auto_awesome',
    loads: (json['loads'] as List? ?? [])
        .map((l) => SceneLoadSetting.fromJson(l as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

/// Curated icon options for app scenes. Only the [iconId] is persisted;
/// icons are always resolved through this const map so release builds can
/// tree-shake unused glyphs (same pattern as SceneFavoritesService).
const Map<String, IconData> roomSceneIcons = {
  'auto_awesome': Icons.auto_awesome_rounded,
  'movie': Icons.movie_creation_rounded,
  'dinner': Icons.dinner_dining_rounded,
  'coffee': Icons.coffee_rounded,
  'party': Icons.celebration_rounded,
  'sleep': Icons.bedtime_rounded,
  'sunrise': Icons.wb_sunny_rounded,
  'night': Icons.nightlight_round,
  'work': Icons.work_rounded,
  'gym': Icons.fitness_center_rounded,
  'book': Icons.auto_stories_rounded,
  'tv': Icons.live_tv_rounded,
  'game': Icons.sports_esports_rounded,
  'music': Icons.music_note_rounded,
  'cleaning': Icons.cleaning_services_rounded,
  'security': Icons.security_rounded,
  'garden': Icons.local_florist_rounded,
  'guests': Icons.people_rounded,
  'birthday': Icons.cake_rounded,
  'romance': Icons.favorite_rounded,
  'focus': Icons.center_focus_strong_rounded,
  'kids': Icons.child_care_rounded,
  'pets': Icons.pets_rounded,
  'energy': Icons.bolt_rounded,
  'relax': Icons.spa_rounded,
  'reading': Icons.chrome_reader_mode_rounded,
  'travel': Icons.luggage_rounded,
  'theater': Icons.theaters_rounded,
};

IconData roomSceneIcon(String iconId) =>
    roomSceneIcons[iconId] ?? Icons.auto_awesome_rounded;