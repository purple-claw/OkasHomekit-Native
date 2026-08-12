// lib/services/quick_select_service.dart
//
// "Quick Select" — pinned loads for a room (or the global Loads tab)
// shown as compact shortcuts. Persisted locally per device
// (SharedPreferences). Icons are derived from the load TYPE at render
// time (via LoadIcon assets) so no dynamic IconData is persisted — this
// keeps release builds with tree-shake-icons working.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuickSelectLoad {
  final String id;
  final String name;
  final String type;
  final Color color;

  QuickSelectLoad({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'color': color.toARGB32(),
      };

  factory QuickSelectLoad.fromJson(Map<String, dynamic> json) {
    return QuickSelectLoad(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Load',
      type: json['type'] as String? ?? 'swt',
      color: Color(json['color'] as int? ?? 0xFF2AC0D1),
    );
  }
}

class QuickSelectService extends ChangeNotifier {
  QuickSelectService._();

  static final QuickSelectService instance = QuickSelectService._();
  static const _storageKey = 'quick_select_loads';

  /// Map: roomId -> ordered list of quick-select loads for that room.
  final Map<String, List<QuickSelectLoad>> _byRoom = {};
  bool _loaded = false;

  List<QuickSelectLoad> forRoom(String roomId) =>
      List.unmodifiable(_byRoom[roomId] ?? const []);

  bool isQuickSelected(String roomId, String loadId) =>
      (_byRoom[roomId] ?? const []).any((l) => l.id == loadId);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        for (final entry in map.entries) {
          final values = (entry.value as List)
              .cast<Map<String, dynamic>>()
              .map(QuickSelectLoad.fromJson)
              .toList();
          _byRoom[entry.key] = values;
        }
      } catch (_) {
        _byRoom.clear();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> addToRoom({
    required String roomId,
    required QuickSelectLoad load,
  }) async {
    final list = _byRoom.putIfAbsent(roomId, () => []);
    if (!list.any((l) => l.id == load.id)) {
      list.add(load);
      notifyListeners();
      await _save();
    }
  }

  Future<void> removeFromRoom({
    required String roomId,
    required String loadId,
  }) async {
    final list = _byRoom[roomId];
    if (list != null) {
      list.removeWhere((l) => l.id == loadId);
      if (list.isEmpty) _byRoom.remove(roomId);
      notifyListeners();
      await _save();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_byRoom.map(
        (roomId, list) => MapEntry(
          roomId,
          list.map((l) => l.toJson()).toList(),
        ),
      )),
    );
  }
}
