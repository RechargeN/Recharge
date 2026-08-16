import '../../domain/entities/notification_item_entity.dart';

class NotificationItemModel {
  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAtUtcIso,
    required this.isRead,
    required this.targetRoute,
    this.subjectKind,
    this.subjectId,
    this.scenarioDraftId,
    this.scenarioItemId,
  });

  factory NotificationItemModel.fromEntity(NotificationItemEntity entity) {
    return NotificationItemModel(
      id: entity.id,
      title: entity.title,
      body: entity.body,
      type: entity.type.name,
      createdAtUtcIso: entity.createdAtUtc.toIso8601String(),
      isRead: entity.isRead,
      targetRoute: entity.targetRoute,
      subjectKind: entity.subjectRef?.kind.name,
      subjectId: entity.subjectRef?.id,
      scenarioDraftId: entity.scenarioContext?.scenarioDraftId,
      scenarioItemId: entity.scenarioContext?.scenarioItemId,
    );
  }

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      createdAtUtcIso: json['createdAtUtcIso'] as String,
      isRead: json['isRead'] as bool? ?? false,
      targetRoute: json['targetRoute'] as String?,
      subjectKind: json['subjectKind'] as String?,
      subjectId: json['subjectId'] as String?,
      scenarioDraftId: json['scenarioDraftId'] as String?,
      scenarioItemId: json['scenarioItemId'] as String?,
    );
  }

  final String id;
  final String title;
  final String body;
  final String type;
  final String createdAtUtcIso;
  final bool isRead;
  final String? targetRoute;
  final String? subjectKind;
  final String? subjectId;
  final String? scenarioDraftId;
  final String? scenarioItemId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'createdAtUtcIso': createdAtUtcIso,
      'isRead': isRead,
      'targetRoute': targetRoute,
      if (subjectKind != null) 'subjectKind': subjectKind,
      if (subjectId != null) 'subjectId': subjectId,
      if (scenarioDraftId != null) 'scenarioDraftId': scenarioDraftId,
      if (scenarioItemId != null) 'scenarioItemId': scenarioItemId,
    };
  }

  NotificationItemEntity toEntity() {
    return NotificationItemEntity(
      id: id,
      title: title,
      body: body,
      type: _parseType(type),
      createdAtUtc: DateTime.parse(createdAtUtcIso).toUtc(),
      isRead: isRead,
      targetRoute: targetRoute,
      subjectRef: _subjectRef(),
      scenarioContext: _scenarioContext(),
    );
  }

  NotificationSubjectRef? _subjectRef() {
    final id = subjectId?.trim();
    if (id == null || id.isEmpty) return null;
    final kind = NotificationSubjectKind.values
        .where((value) => value.name == subjectKind)
        .firstOrNull;
    return kind == null ? null : NotificationSubjectRef(kind: kind, id: id);
  }

  ScenarioNotificationContext? _scenarioContext() {
    final draftId = scenarioDraftId?.trim();
    final itemId = scenarioItemId?.trim();
    if (draftId == null ||
        draftId.isEmpty ||
        itemId == null ||
        itemId.isEmpty) {
      return null;
    }
    return ScenarioNotificationContext(
      scenarioDraftId: draftId,
      scenarioItemId: itemId,
    );
  }

  NotificationType _parseType(String value) {
    switch (value) {
      case 'reminder':
        return NotificationType.reminder;
      case 'activity':
        return NotificationType.activity;
      case 'system':
      default:
        return NotificationType.system;
    }
  }
}
