// // lib/services/room_service.dart (or wherever you manage rooms)
// import 'dart:convert';

// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:smart_home_animation/core/shared/domain/entities/device.dart';
// import 'package:smart_home_animation/core/shared/domain/entities/room.dart';

// class RoomService {
//   List<Room> _rooms = [];

//   // Add device to room
//   Future<void> addDeviceToRoom(String roomId, Device device) async {
//     final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
//     if (roomIndex != -1) {
//       final updatedRoom = Room(
//         id: _rooms[roomIndex].id,
//         name: _rooms[roomIndex].name,
//         wallpaperUrl: _rooms[roomIndex].wallpaperUrl,
//         devices: [..._rooms[roomIndex].devices, device],
//         createdAt: _rooms[roomIndex].createdAt,
//       );
//       _rooms[roomIndex] = updatedRoom;
//       await _saveRoomsToStorage();
//     }
//   }

//   // Remove device from room
//   Future<void> removeDeviceFromRoom(String roomId, String deviceId) async {
//     final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
//     if (roomIndex != -1) {
//       final updatedRoom = Room(
//         id: _rooms[roomIndex].id,
//         name: _rooms[roomIndex].name,
//         wallpaperUrl: _rooms[roomIndex].wallpaperUrl,
//         devices: _rooms[roomIndex].devices
//             .where((d) => d.id != deviceId)
//             .toList(),
//         createdAt: _rooms[roomIndex].createdAt,
//       );
//       _rooms[roomIndex] = updatedRoom;
//       await _saveRoomsToStorage();
//     }
//   }

//   Future<void> _saveRoomsToStorage() async {
//     final prefs = await SharedPreferences.getInstance();
//     final roomsJson = _rooms.map((room) => room!.toJson()).toList();
//     await prefs.setString('saved_rooms', jsonEncode(roomsJson));
//     print('Saved ${_rooms.length} rooms with devices');
//   }

//   Future<void> _loadRoomsFromStorage() async {
//     final prefs = await SharedPreferences.getInstance();
//     final roomsString = prefs.getString('saved_rooms');
//     if (roomsString != null) {
//       final roomsJson = jsonDecode(roomsString) as List;
//       setState(() {
//         _rooms = roomsJson.map((json) => Room.fromJson(json)).toList();
//       });
//       print('Loaded ${_rooms.length} rooms from storage');
//       _rooms.forEach((room) {
//         print('Room "${room.name}" has ${room.devices.length} devices');
//       });
//     }
//   }
// }
