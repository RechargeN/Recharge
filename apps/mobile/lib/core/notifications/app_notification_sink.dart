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
    this.templateCode,
    this.templateCount,
  });

  final String id;
  final AppNotificationAudience audience;
  final String? recipientUserId;
  final String title;
  final String body;
  final DateTime createdAtUtc;
  final String? targetRoute;

  /// L4.6: a stable local template; the inbox renders it in the reader's
  /// language. [title] stays as a fallback and [body] carries only content
  /// that is shown as is (a page name).
  final String? templateCode;
  final int? templateCount;
}

abstract class AppNotificationSink {
  Future<void> appendNotification(AppNotificationEvent event);
}
