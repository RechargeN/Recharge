import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../domain/repositories/notification_channel_settings_repository.dart';

/// N3c: per-category consent for push (and the inbox where it may change).
/// Shows the server's answer only; a failed change reloads the server state.
class NotificationChannelSettingsSheet extends StatefulWidget {
  const NotificationChannelSettingsSheet({super.key, required this.repository});

  final NotificationChannelSettingsRepository repository;

  @override
  State<NotificationChannelSettingsSheet> createState() =>
      _NotificationChannelSettingsSheetState();
}

class _NotificationChannelSettingsSheetState
    extends State<NotificationChannelSettingsSheet> {
  NotificationChannelSettings? _settings;
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final NotificationChannelSettings settings = await widget.repository
          .load();
      if (mounted) setState(() => _settings = settings);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _change(String category, {bool? inApp, bool? push}) async {
    final NotificationChannelSettings? current = _settings;
    if (current == null || _saving) return;
    setState(() => _saving = true);
    try {
      final NotificationChannelSettings next = await widget.repository.update(
        expectedRevision: current.revision,
        category: category,
        inApp: inApp,
        push: push,
      );
      if (mounted) setState(() => _settings = next);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.notificationsChannelSaveFailed)),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(BuildContext context, String category) => switch (category) {
    'booking.receipts' => context.l10n.notificationsCategoryBookingReceipts,
    'booking.changes' => context.l10n.notificationsCategoryBookingChanges,
    _ => category,
  };

  @override
  Widget build(BuildContext context) {
    final NotificationChannelSettings? settings = _settings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.notificationsChannelSettings,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_failed)
              ListTile(
                title: Text(context.l10n.notificationsChannelLoadFailed),
                trailing: TextButton(
                  onPressed: _load,
                  child: Text(context.l10n.commonRetry),
                ),
              )
            else if (settings == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final NotificationCategoryChannels item
                  in settings.categories) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _label(context, item.category),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (item.pushEnabled != null)
                  SwitchListTile(
                    key: Key('push-${item.category}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.notificationsChannelPush),
                    value: item.pushEnabled!,
                    onChanged: _saving
                        ? null
                        : (bool value) => _change(item.category, push: value),
                  ),
                SwitchListTile(
                  key: Key('inapp-${item.category}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.notificationsChannelInApp),
                  subtitle: item.inAppLocked
                      ? Text(context.l10n.notificationsChannelLocked)
                      : null,
                  value: item.inAppEnabled,
                  onChanged: item.inAppLocked || _saving
                      ? null
                      : (bool value) => _change(item.category, inApp: value),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
