// lib/models/room.dart
import 'package:smart_home_animation/core/shared/domain/entities/device.dart';

class Room {
  final String id;
  final String name;
  final String? wallpaperUrl;
  final List<Device> devices;
  final DateTime createdAt;
  final bool isFavorite;

  Room({
    required this.id,
    required this.name,
    this.wallpaperUrl,
    required this.devices,
    required this.createdAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'wallpaperUrl': wallpaperUrl,
    'devices': devices.map((d) => d.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'],
    name: json['name'],
    wallpaperUrl: json['wallpaperUrl'],
    devices: (json['devices'] as List).map((d) => Device.fromJson(d)).toList(),
    createdAt: DateTime.parse(json['createdAt']),
    isFavorite: json['isFavorite'] == true,
  );
}
