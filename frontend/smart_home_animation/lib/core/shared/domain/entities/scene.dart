// lib/models/scene.dart
class Scene {
  final String id;
  final String name;
  final List<SceneAction> actions;
  final bool isSuggested;
  final DateTime createdAt;

  Scene({
    required this.id,
    required this.name,
    required this.actions,
    this.isSuggested = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'actions': actions.map((a) => a.toJson()).toList(),
    'isSuggested': isSuggested,
    'createdAt': createdAt.toIso8601String(),
  };
}

class SceneAction {
  final String deviceId;
  final String deviceName;
  final String action;
  final dynamic value;

  SceneAction({
    required this.deviceId,
    required this.deviceName,
    required this.action,
    this.value,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'action': action,
    'value': value,
  };
}
