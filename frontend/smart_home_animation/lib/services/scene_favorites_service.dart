import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteSceneShortcut {
  const FavoriteSceneShortcut({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.scope,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String scope;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'color': color.toARGB32(),
    'scope': scope,
  };

  factory FavoriteSceneShortcut.fromJson(Map<String, dynamic> json) {
    return FavoriteSceneShortcut(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Scene',
      description: json['description'] as String? ?? '',
      icon: _iconForId(json['id'] as String? ?? ''),
      color: Color(json['color'] as int? ?? Colors.cyan.toARGB32()),
      scope: json['scope'] as String? ?? 'Global',
    );
  }

  static IconData _iconForId(String id) {
    switch (id) {
      case 'std_morning':
        return Icons.wb_sunny_outlined;
      case 'std_evening':
        return Icons.nightlight_outlined;
      case 'std_movie':
        return Icons.movie_outlined;
      case 'std_away':
        return Icons.lock_outline;
      default:
        return Icons.auto_awesome;
    }
  }
}

class SceneFavoritesService extends ChangeNotifier {
  SceneFavoritesService._();

  static final SceneFavoritesService instance = SceneFavoritesService._();
  static const _storageKey = 'favorite_scene_shortcuts';

  final Map<String, FavoriteSceneShortcut> _favorites = {};
  bool _loaded = false;

  List<FavoriteSceneShortcut> get favorites => _favorites.values.toList();

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final values = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        for (final value in values) {
          final scene = FavoriteSceneShortcut.fromJson(value);
          _favorites[scene.id] = scene;
        }
      } catch (_) {
        _favorites.clear();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setFavorite({
    required String id,
    required String name,
    required String description,
    required IconData icon,
    required Color color,
    required String scope,
    required bool favorite,
  }) async {
    if (favorite) {
      _favorites[id] = FavoriteSceneShortcut(
        id: id,
        name: name,
        description: description,
        icon: icon,
        color: color,
        scope: scope,
      );
    } else {
      _favorites.remove(id);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_favorites.values.map((scene) => scene.toJson()).toList()),
    );
  }
}
