enum NotificationType { system, reminder, activity }

enum NotificationSubjectKind {
  event,
  place,
  route,
  activity,
  bookableSession,
  system,
}

class NotificationSubjectRef {
  const NotificationSubjectRef({required this.kind, required this.id});

  final NotificationSubjectKind kind;
  final String id;
}

class ScenarioNotificationContext {
  const ScenarioNotificationContext({
    required this.scenarioDraftId,
    required this.scenarioItemId,
  });

  final String scenarioDraftId;
  final String scenarioItemId;
}

class NotificationItemEntity {
  const NotificationItemEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAtUtc,
    required this.isRead,
    required this.targetRoute,
    this.subjectRef,
    this.scenarioContext,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAtUtc;
  final bool isRead;
  final String? targetRoute;
  final NotificationSubjectRef? subjectRef;
  final ScenarioNotificationContext? scenarioContext;

  NotificationItemEntity copyWith({bool? isRead}) {
    return NotificationItemEntity(
      id: id,
      title: title,
      body: body,
      type: type,
      createdAtUtc: createdAtUtc,
      isRead: isRead ?? this.isRead,
      targetRoute: targetRoute,
      subjectRef: subjectRef,
      scenarioContext: scenarioContext,
    );
  }
}
