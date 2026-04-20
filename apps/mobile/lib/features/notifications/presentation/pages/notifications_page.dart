import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/application/auth_providers.dart';
import '../../application/controllers/notifications_controller.dart';
import '../../application/notifications_providers.dart';
import '../../application/state/notifications_state.dart';
import '../../domain/entities/notification_item_entity.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  String? _loadedUserId;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).state;
    final NotificationsController controller =
        ref.watch(notificationsControllerProvider);
    final NotificationsState state = controller.state;
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Требуется авторизация')),
      );
    }

    if (_loadedUserId != user.id) {
      _loadedUserId = user.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(notificationsControllerProvider).ensureLoaded(userId: user.id);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Уведомления (${state.unreadCount})'),
      ),
      body: switch (state.status) {
        NotificationsStatus.initial || NotificationsStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        NotificationsStatus.error => _StateMessage(
            message: state.message ?? 'Не удалось загрузить уведомления',
            actionLabel: 'Повторить',
            onAction: () => controller.loadNotifications(userId: user.id),
          ),
        NotificationsStatus.ready => state.items.isEmpty
            ? _StateMessage(
                message: 'Пока нет уведомлений',
                actionLabel: 'Обновить',
                onAction: () => controller.loadNotifications(userId: user.id),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemBuilder: (BuildContext context, int index) {
                  final NotificationItemEntity item = state.items[index];
                  return ListTile(
                    leading: _TypeIcon(type: item.type, isRead: item.isRead),
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.body}\n${_formatDate(item.createdAtUtc)}',
                    ),
                    isThreeLine: true,
                    trailing: item.isRead
                        ? const Text('Прочитано')
                        : IconButton(
                            tooltip: 'Отметить как прочитанное',
                            icon: const Icon(Icons.mark_email_read_outlined),
                            onPressed: () => controller.markAsRead(item.id),
                          ),
                    onTap: () => _openNotification(item),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: state.items.length,
              ),
      },
    );
  }

  Future<void> _openNotification(NotificationItemEntity item) async {
    await ref.read(notificationsControllerProvider).markAsRead(item.id);
    if (!mounted) return;
    final String? route = item.targetRoute;
    if (route == null || route.isEmpty) return;
    context.push(route);
  }

  String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month ${local.year}, $hour:$minute';
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({
    required this.type,
    required this.isRead,
  });

  final NotificationType type;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final Color color = isRead ? Colors.grey : Theme.of(context).colorScheme.primary;
    final IconData icon = switch (type) {
      NotificationType.system => Icons.info_outline,
      NotificationType.reminder => Icons.alarm_outlined,
      NotificationType.activity => Icons.local_activity_outlined,
    };
    return Icon(icon, color: color);
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
