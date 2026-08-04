// lib/services/room_image_sync_service.dart
//
// Syncs room images to the OKAS board so that a room image picked on one
// mobile device is visible on every other device on the network.
//
// How it works:
//   1. The picker saves a compressed image to local storage (imagePath).
//   2. `uploadRoomImage` POSTs that file to the board's web server
//      (uploadRoomImage.php). The board stores it under /www/uploads/ and
//      returns an absolute URL.
//   3. The room's imagePath becomes the board URL. It syncs to all devices
//      via MQTT (rooms/set) because the URL is device-independent.
//   4. When a device renders the image, it loads from the URL (with a
//      local cache fallback so it still works offline / after the image
//      was previously downloaded).
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:smart_home_animation/api/constants.dart';

class RoomImageSyncService {
  RoomImageSyncService._();

  static final RoomImageSyncService instance = RoomImageSyncService._();

  /// Returns true when [path] looks like a local file path (not an HTTP URL).
  static bool isLocalPath(String? path) {
    if (path == null || path.isEmpty) return false;
    return !path.startsWith('http://') && !path.startsWith('https://');
  }

  /// Uploads a local image file to the board and returns the URL to use as
  /// the room's imagePath. Returns null on failure.
  Future<String?> uploadRoomImage(String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final ip = Constants.currentIp;
      if (ip.isEmpty) return null;

      final uri = Uri(
        scheme: Constants.apiScheme,
        host: ip,
        port: Constants.apiPort,
        path: '/uploadRoomImage.php',
      );

      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath('image', localPath),
        );

      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        return data['url'] as String? ?? data['path'] as String?;
      }
      print('Room image upload failed: ${data['message']}');
      return null;
    } catch (e) {
      print('Room image upload error: $e');
      return null;
    }
  }

  /// Convenience: if [imagePath] is a local file path, upload it and return
  /// the board URL. If it's already a URL (or null), return it unchanged.
  Future<String?> syncImageToBoard(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return imagePath;
    if (!isLocalPath(imagePath)) return imagePath;
    return uploadRoomImage(imagePath);
  }
}
