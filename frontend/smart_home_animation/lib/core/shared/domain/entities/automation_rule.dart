// entities/automation_rule.dart
import 'package:equatable/equatable.dart';

enum TriggerType { sensor, time, deviceState, manual }

enum ActionType { toggleDevice, setDeviceValue, sendNotification, executeScene }

class AutomationRule extends Equatable {
  final String id;
  final String name;
  final String? description;
  final TriggerType triggerType;
  final Map<String, dynamic> triggerConditions;
  final ActionType actionType;
  final Map<String, dynamic> actionParameters;
  final bool enabled;
  final DateTime createdAt;
  final DateTime? lastExecuted;

  const AutomationRule({
    required this.id,
    required this.name,
    this.description,
    required this.triggerType,
    required this.triggerConditions,
    required this.actionType,
    required this.actionParameters,
    this.enabled = true,
    required this.createdAt,
    this.lastExecuted,
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    return AutomationRule(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      triggerType: TriggerType.values.firstWhere(
        (e) => e.toString().split('.').last == json['triggerType'],
        orElse: () => TriggerType.manual,
      ),
      triggerConditions: json['triggerConditions'] as Map<String, dynamic>,
      actionType: ActionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['actionType'],
        orElse: () => ActionType.toggleDevice,
      ),
      actionParameters: json['actionParameters'] as Map<String, dynamic>,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastExecuted: json['lastExecuted'] != null
          ? DateTime.parse(json['lastExecuted'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'triggerType': triggerType.toString().split('.').last,
      'triggerConditions': triggerConditions,
      'actionType': actionType.toString().split('.').last,
      'actionParameters': actionParameters,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'lastExecuted': lastExecuted?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    triggerType,
    triggerConditions,
    actionType,
    actionParameters,
    enabled,
    createdAt,
    lastExecuted,
  ];
}
