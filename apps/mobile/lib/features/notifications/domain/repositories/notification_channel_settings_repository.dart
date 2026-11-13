/// N3c: one notification category with its channels as the server decides
/// them. `pushEnabled` is null while the active policy offers no push channel.
final class NotificationCategoryChannels {
  const NotificationCategoryChannels({
    required this.category,
    required this.inAppEnabled,
    required this.inAppLocked,
    required this.pushEnabled,
  });

  final String category;
  final bool inAppEnabled;

  /// A locked category always keeps its inbox record; only push may change.
  final bool inAppLocked;
  final bool? pushEnabled;
}

/// The caller's channel preferences at one server revision.
final class NotificationChannelSettings {
  const NotificationChannelSettings({
    required this.revision,
    required this.categories,
  });

  final int revision;
  final List<NotificationCategoryChannels> categories;
}

/// Consent for push and inbox per category, kept on the server only. The
/// device never stores a copy; every change carries the revision it saw.
abstract interface class NotificationChannelSettingsRepository {
  Future<NotificationChannelSettings> load();

  Future<NotificationChannelSettings> update({
    required int expectedRevision,
    required String category,
    bool? inApp,
    bool? push,
  });

  /// Dev only: one synthetic notification for the signed-in owner (inbox
  /// record first, then the push hint).
  Future<void> sendTestNotification();
}
