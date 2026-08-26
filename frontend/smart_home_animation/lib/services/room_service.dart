import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Room {
  final String id;
  final String name;
  final String? imagePath;
  final List<String> loadIds;
  final DateTime createdAt;
  final bool isFavorite;

  Room({
    required this.id,
    required this.name,
    this.imagePath,
    required this.loadIds,
    required this.createdAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imagePath': imagePath,
    'loads': loadIds,
    'createdAt': createdAt.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'],
    name: json['name'],
    imagePath: json['imagePath'],
    loadIds: List<String>.from(json['loads'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
    isFavorite: json['isFavorite'] == true,
  );

  Room copyWith({
    String? id,
    String? name,
    String? imagePath,
    List<String>? loadIds,
    DateTime? createdAt,
    bool? isFavorite,
  }) => Room(
    id: id ?? this.id,
    name: name ?? this.name,
    imagePath: imagePath ?? this.imagePath,
    loadIds: loadIds ?? this.loadIds,
    createdAt: createdAt ?? this.createdAt,
    isFavorite: isFavorite ?? this.isFavorite,
  );
}

class RoomService {
  static RoomService? _instance;
  List<Room> _rooms = [];
  final List<Function()> _listeners = [];

  RoomService._();

  static RoomService get instance {
    _instance ??= RoomService._();
    return _instance!;
  }

  List<Room> get rooms => List.unmodifiable(_rooms);

  void addListener(Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      listener();
    }
  }

  Future<void> loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsString = prefs.getString('saved_rooms');
    if (roomsString != null) {
      try {
        final roomsJson = jsonDecode(roomsString) as List;
        // Deduplicate by id, keeping the most recent entry per id
        final uniqueRooms = <String, Room>{};
        for (final json in roomsJson) {
          final room = Room.fromJson(json as Map<String, dynamic>);
          uniqueRooms[room.id] = room;
        }
        _rooms = uniqueRooms.values.toList();
        _notifyListeners();
      } catch (e) {
        debugPrint('Error loading rooms: $e');
      }
    }
  }

  Future<void> saveRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsJson = jsonEncode(_rooms.map((r) => r.toJson()).toList());
    await prefs.setString('saved_rooms', roomsJson);
  }

  /// Wipes the local cache and persistent storage. Used when the app
  /// reconnects to the MQTT broker so we don't briefly show rooms that
  /// belong to a previous board. The board will repopulate via `rooms/set`.
  Future<void> clearRooms() async {
    if (_rooms.isEmpty) {
      // Still ensure persisted storage is empty in case it diverged.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_rooms');
      return;
    }
    _rooms.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_rooms');
    _notifyListeners();
  }

  Future<void> replaceRooms(List<Room> newRooms) async {
    _rooms
      ..clear()
      ..addAll(newRooms);
    await saveRooms();
    _notifyListeners();
  }

  /// Marks a room as favorite (or not). The flag is persisted locally and
  /// synced to the board so all devices see the same favorite room.
  Future<void> setFavorite(String roomId, bool favorite) async {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index >= 0) {
      _rooms[index] = _rooms[index].copyWith(isFavorite: favorite);
      await saveRooms();
      _notifyListeners();
    }
  }

  /// Updates a room's image path (board URL after upload, or a local path
  /// when the upload failed — the renderer falls back to local cache).
  Future<void> setImagePath(String roomId, String? imagePath) async {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index >= 0) {
      _rooms[index] = _rooms[index].copyWith(imagePath: imagePath);
      await saveRooms();
      _notifyListeners();
    }
  }

  Room? get favoriteRoom {
    for (final room in _rooms) {
      if (room.isFavorite) return room;
    }
    return null;
  }

  Future<void> addLoadToRoom(String roomId, String loadId) async {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index >= 0) {
      final room = _rooms[index];
      if (!room.loadIds.contains(loadId)) {
        final updatedRoom = Room(
          id: room.id,
          name: room.name,
          imagePath: room.imagePath,
          loadIds: [...room.loadIds, loadId],
          createdAt: room.createdAt,
        );
        _rooms[index] = updatedRoom;
        await saveRooms();
        _notifyListeners();
      }
    }
  }

  Future<void> removeLoadFromRoom(String roomId, String loadId) async {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index >= 0) {
      final room = _rooms[index];
      final updatedRoom = Room(
        id: room.id,
        name: room.name,
        imagePath: room.imagePath,
        loadIds: room.loadIds.where((id) => id != loadId).toList(),
        createdAt: room.createdAt,
      );
      _rooms[index] = updatedRoom;
      await saveRooms();
      _notifyListeners();
    }
  }

  Room? getRoomById(String id) {
    try {
      return _rooms.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Room> getRoomsForLoad(String loadId) {
    return _rooms.where((r) => r.loadIds.contains(loadId)).toList();
  }
}
