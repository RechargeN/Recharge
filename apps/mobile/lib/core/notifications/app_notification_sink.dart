enum AppNotificationAudience { user, moderators }

class AppNotificationEvent {
  const AppNotificationEvent({
    required this.id,
    required this.audience,
    required this.title,
    required this.body,
    required this.createdAtUtc,
    this.recipientUserId,
    this.targetRoute,
  });

  final String id;
  final AppNotificationAudience audience;
  final String? recipientUserId;
  final String title;
  final String body;
  final DateTime createdAtUtc;
  final String? targetRoute;
}

abstract class AppNotificationSink {
  Future<void> appendNotification(AppNotificationEvent event);
}
