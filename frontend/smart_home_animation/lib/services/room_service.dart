import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';

class Room {
  final String id;
  final String name;
  final String? imagePath;
  final List<String> loadIds;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.name,
    this.imagePath,
    required this.loadIds,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imagePath': imagePath,
    'loads': loadIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'],
    name: json['name'],
    imagePath: json['imagePath'],
    loadIds: List<String>.from(json['loads'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
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
        print('Error loading rooms: $e');
      }
    }
  }

  Future<void> saveRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsJson = jsonEncode(_rooms.map((r) => r.toJson()).toList());
    await prefs.setString('saved_rooms', roomsJson);
  }

  Future<void> addRoom(Room room) async {
    _rooms.add(room);
    await saveRooms();
    _notifyListeners();
  }

  Future<void> updateRoom(Room room) async {
    final index = _rooms.indexWhere((r) => r.id == room.id);
    if (index >= 0) {
      _rooms[index] = room;
      await saveRooms();
      _notifyListeners();
    }
  }

  Future<void> deleteRoom(String roomId) async {
    _rooms.removeWhere((r) => r.id == roomId);
    await saveRooms();
    _notifyListeners();
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
