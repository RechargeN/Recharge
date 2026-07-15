import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../create/application/create_taxonomy.dart';
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
  bool _unreadOnly = false;

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
        title: Text('Inbox (${state.unreadCount})'),
      ),
      body: switch (state.status) {
        NotificationsStatus.initial || NotificationsStatus.loading =>
          const Center(
            child: CircularProgressIndicator(),
          ),
        NotificationsStatus.error => _StateMessage(
            message: state.message ?? 'Не удалось загрузить уведомления',
            actionLabel: 'Повторить',
            onAction: () => controller.loadNotifications(userId: user.id),
          ),
        NotificationsStatus.ready => _buildReadyState(
            context: context,
            controller: controller,
            userId: user.id,
            state: state,
          ),
      },
    );
  }

  Widget _buildReadyState({
    required BuildContext context,
    required NotificationsController controller,
    required String userId,
    required NotificationsState state,
  }) {
    if (state.items.isEmpty) {
      return _StateMessage(
        message: 'Пока нет уведомлений',
        actionLabel: 'Обновить',
        onAction: () => controller.loadNotifications(userId: userId),
      );
    }

    final List<NotificationItemEntity> visibleItems = _unreadOnly
        ? state.items
            .where((NotificationItemEntity item) => !item.isRead)
            .toList(growable: false)
        : state.items;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _NotificationsHero(
          totalCount: state.items.length,
          unreadCount: state.unreadCount,
          latestItem: state.items.first,
          onRefresh: () => controller.loadNotifications(userId: userId),
          onMarkAllRead: state.unreadCount == 0
              ? null
              : () => controller.markAllAsRead(),
        ),
        const SizedBox(height: 14),
        _NotificationFilterBar(
          unreadOnly: _unreadOnly,
          onChanged: (bool next) {
            setState(() => _unreadOnly = next);
          },
        ),
        const SizedBox(height: 14),
        if (visibleItems.isEmpty)
          _FilteredNotificationsEmpty(
            onShowAll: () => setState(() => _unreadOnly = false),
          )
        else
          ...<Widget>[
            _NotificationPrioritySummary(items: visibleItems),
            const SizedBox(height: 14),
            ..._notificationSectionsFor(visibleItems).map(
              (_NotificationSectionData section) => _NotificationSectionBlock(
                section: section,
                itemBuilder: (NotificationItemEntity item) =>
                    _notificationCardFor(
                  item: item,
                  controller: controller,
                ),
              ),
            ),
          ],
      ],
    );
  }

  Widget _notificationCardFor({
    required NotificationItemEntity item,
    required NotificationsController controller,
  }) {
    return _NotificationCard(
      item: item,
      onMarkRead: item.isRead ? null : () => controller.markAsRead(item.id),
      onOpen: () => _openNotification(item),
      onOpenLocation: (String location) => _openNotification(
        item,
        targetRoute: location,
      ),
    );
  }

  Future<void> _openNotification(
    NotificationItemEntity item, {
    String? targetRoute,
  }) async {
    await ref.read(notificationsControllerProvider).markAsRead(item.id);
    if (!mounted) return;
    final String? route = targetRoute ?? item.targetRoute;
    if (route == null || route.isEmpty) return;
    context.push(route);
  }
}

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero({
    required this.totalCount,
    required this.unreadCount,
    required this.latestItem,
    required this.onRefresh,
    required this.onMarkAllRead,
  });

  final int totalCount;
  final int unreadCount;
  final NotificationItemEntity latestItem;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.notifications_active, color: colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Recharge inbox',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              latestItem.title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _HeroPill(label: '$unreadCount unread'),
                _HeroPill(label: '$totalCount total'),
                _HeroPill(label: _formatDate(latestItem.createdAtUtc)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onMarkAllRead,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Read all'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Обновить',
                  onPressed: onRefresh,
                  icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
                  style: IconButton.styleFrom(
                    side: BorderSide(
                      color: colorScheme.onPrimary.withValues(alpha: 0.48),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({
    required this.unreadOnly,
    required this.onChanged,
  });

  final bool unreadOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(
          value: false,
          icon: Icon(Icons.inbox),
          label: Text('All'),
        ),
        ButtonSegment<bool>(
          value: true,
          icon: Icon(Icons.mark_email_unread),
          label: Text('Unread'),
        ),
      ],
      selected: <bool>{unreadOnly},
      onSelectionChanged: (Set<bool> values) {
        onChanged(values.first);
      },
    );
  }
}

class _NotificationPrioritySummary extends StatelessWidget {
  const _NotificationPrioritySummary({
    required this.items,
  });

  final List<NotificationItemEntity> items;

  @override
  Widget build(BuildContext context) {
    final List<_NotificationSectionData> sections =
        _notificationSectionsFor(items);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sections
          .map(
            (_NotificationSectionData section) => _NotificationMetaChip(
              icon: section.icon,
              label: '${section.shortLabel} ${section.items.length}',
            ),
          )
          .toList(growable: false),
    );
  }
}

class _NotificationSectionBlock extends StatelessWidget {
  const _NotificationSectionBlock({
    required this.section,
    required this.itemBuilder,
  });

  final _NotificationSectionData section;
  final Widget Function(NotificationItemEntity item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Icon(section.icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        section.title,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      Text(
                        section.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                _NotificationCountBadge(count: section.items.length),
              ],
            ),
          ),
          ...section.items.map(
            (NotificationItemEntity item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: itemBuilder(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCountBadge extends StatelessWidget {
  const _NotificationCountBadge({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onOpen,
    required this.onOpenLocation,
    required this.onMarkRead,
  });

  final NotificationItemEntity item;
  final VoidCallback onOpen;
  final Future<void> Function(String location) onOpenLocation;
  final Future<void> Function()? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _NotificationDestination destination =
        _notificationDestinationFor(item.targetRoute);
    final _NotificationRoutePreview? routePreview =
        _NotificationRoutePreview.fromTargetRoute(item.targetRoute);
    final List<_NotificationRouteAction> routeActions =
        routePreview?.actionTargets ?? const <_NotificationRouteAction>[];
    final bool hasTargetRoute =
        item.targetRoute != null && item.targetRoute!.trim().isNotEmpty;
    final Color borderColor = item.isRead
        ? colorScheme.outline.withValues(alpha: 0.16)
        : colorScheme.primary.withValues(alpha: 0.44);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead
              ? colorScheme.surface
              : colorScheme.primaryContainer.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _TypeIcon(type: item.type, isRead: item.isRead),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      _ReadBadge(isRead: item.isRead),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _NotificationMetaChip(
                        icon: destination.icon,
                        label: destination.label,
                      ),
                      _NotificationMetaChip(
                        icon: Icons.schedule,
                        label: _formatDate(item.createdAtUtc),
                      ),
                    ],
                  ),
                  if (routePreview != null) ...<Widget>[
                    const SizedBox(height: 10),
                    _NotificationRoutePreviewPanel(preview: routePreview),
                  ],
                  if (routeActions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: routeActions
                          .map(
                            (_NotificationRouteAction action) =>
                                OutlinedButton.icon(
                              onPressed: () {
                                onOpenLocation(action.location);
                              },
                              icon: Icon(action.icon, size: 18),
                              label: Text(action.label),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      if (hasTargetRoute) ...<Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onOpen,
                            icon: Icon(destination.icon),
                            label: Text(destination.actionLabel),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else
                        const Spacer(),
                      if (onMarkRead != null)
                        IconButton(
                          tooltip: 'Отметить как прочитанное',
                          icon: const Icon(Icons.mark_email_read),
                          onPressed: onMarkRead,
                        )
                      else
                        const Text('Прочитано'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRoutePreviewPanel extends StatelessWidget {
  const _NotificationRoutePreviewPanel({
    required this.preview,
  });

  final _NotificationRoutePreview preview;

  @override
  Widget build(BuildContext context) {
    final TextStyle? labelStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (preview.moodLabel != null)
              _NotificationMetaChip(
                icon: Icons.self_improvement,
                label: preview.moodLabel!,
              ),
            if (preview.durationLabel != null)
              _NotificationMetaChip(
                icon: Icons.timer_outlined,
                label: preview.durationLabel!,
              ),
            if (preview.freeOnly)
              const _NotificationMetaChip(
                icon: Icons.savings_outlined,
                label: 'Free',
              ),
            if (preview.walkingOnly)
              const _NotificationMetaChip(
                icon: Icons.directions_walk,
                label: 'Walking',
              ),
            if (preview.stepLabels.isNotEmpty)
              _NotificationMetaChip(
                icon: Icons.alt_route,
                label: '${preview.stepLabels.length} stops',
              ),
          ],
        ),
        if (preview.stepLabels.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            preview.stepLabels.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ],
      ],
    );
  }
}

class _NotificationMetaChip extends StatelessWidget {
  const _NotificationMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: colorScheme.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRoutePreview {
  const _NotificationRoutePreview({
    required this.targetPath,
    required this.mood,
    required this.duration,
    required this.free,
    required this.walking,
    required this.prompt,
    required this.stepCategories,
    required this.stepLabels,
  });

  final String targetPath;
  final String? mood;
  final String? duration;
  final String? free;
  final String? walking;
  final String? prompt;
  final List<String> stepCategories;
  final List<String> stepLabels;

  String? get moodLabel => mood == null ? null : _humanizeQueryLabel(mood!);

  int? get durationMinutes => int.tryParse(duration ?? '');

  String? get durationLabel {
    final int? minutes = durationMinutes;
    return minutes == null ? null : '$minutes min';
  }

  bool get freeOnly => _boolFromQuery(free);

  bool get walkingOnly => _boolFromQuery(walking);

  String get promptLabel {
    final String? promptValue = prompt;
    if (promptValue != null && promptValue.isNotEmpty) return promptValue;
    final String moodValue = moodLabel ?? 'Custom';
    final int stopCount = stepCategories.length;
    return stopCount == 0
        ? '$moodValue recharge route'
        : '$moodValue route with $stopCount stops';
  }

  String get titleLabel => '${moodLabel ?? 'Custom'} recharge route';

  String get subtitleLabel {
    final List<String> parts = <String>[
      if (stepCategories.isNotEmpty) '${stepCategories.length} stops',
      if (durationLabel != null) durationLabel!,
    ];
    return parts.isEmpty ? 'Scenario route' : parts.join(' · ');
  }

  Map<String, String> _routeParameters({required bool includeMode}) {
    return <String, String>{
      if (includeMode) 'mode': 'scenario',
      if (mood != null) 'mood': mood!,
      if (duration != null) 'duration': duration!,
      if (free != null) 'free': free!,
      if (walking != null) 'walking': walking!,
      if (prompt != null) 'prompt': prompt!,
      if (stepCategories.isNotEmpty) 'steps': stepCategories.join(','),
    };
  }

  String get builderLocation {
    return Uri(
      path: RouteNames.scenarioBuilder,
      queryParameters: _routeParameters(includeMode: false),
    ).toString();
  }

  String get mapLocation {
    return Uri(
      path: RouteNames.discoverMap,
      queryParameters: _routeParameters(includeMode: true),
    ).toString();
  }

  String get createLocation {
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._routeParameters(includeMode: false),
        'source': 'scenario',
        'type': 'event',
        'title': titleLabel,
        'subtitle': subtitleLabel,
        'q': promptLabel,
        'category': 'scenario',
      },
    ).toString();
  }

  List<_NotificationRouteAction> get actionTargets {
    return <_NotificationRouteAction>[
      if (targetPath != RouteNames.scenarioBuilder)
        _NotificationRouteAction(
          icon: Icons.tune,
          label: 'Edit route',
          location: builderLocation,
        ),
      if (targetPath != RouteNames.discoverMap)
        _NotificationRouteAction(
          icon: Icons.map_outlined,
          label: 'Map route',
          location: mapLocation,
        ),
      _NotificationRouteAction(
        icon: Icons.add_circle_outline,
        label: 'Create route',
        location: createLocation,
      ),
    ];
  }

  static _NotificationRoutePreview? fromTargetRoute(String? targetRoute) {
    final String path = _pathForTargetRoute(targetRoute);
    final Map<String, String> query = _queryForTargetRoute(targetRoute);
    final bool isRouteTarget = path == RouteNames.scenarioBuilder ||
        (path == RouteNames.discoverMap && query['mode'] == 'scenario');
    if (!isRouteTarget) return null;

    final List<String> stepCategories = (query['steps'] ?? '')
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    final List<String> stepLabels = stepCategories
        .map(createTaxonomyLabelForPath)
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);

    final String? mood = _optionalQueryValue(query['mood']);
    final String? duration = _optionalQueryValue(
      query['duration'] ?? query['durationMinutes'],
    );
    final String? free = _boolParamFromQuery(query['free'] ?? query['freeOnly']);
    final String? walking = _boolParamFromQuery(
      query['walking'] ?? query['walkingOnly'],
    );
    final String? prompt = _optionalQueryValue(query['prompt'] ?? query['q']);

    if (mood == null &&
        duration == null &&
        free == null &&
        walking == null &&
        prompt == null &&
        stepLabels.isEmpty) {
      return null;
    }

    return _NotificationRoutePreview(
      targetPath: path,
      mood: mood,
      duration: duration,
      free: free,
      walking: walking,
      prompt: prompt,
      stepCategories: stepCategories,
      stepLabels: stepLabels,
    );
  }
}

class _NotificationRouteAction {
  const _NotificationRouteAction({
    required this.icon,
    required this.label,
    required this.location,
  });

  final IconData icon;
  final String label;
  final String location;
}

enum _NotificationSectionKind {
  actionNeeded,
  routePlans,
  creatorUpdates,
  otherUpdates,
}

class _NotificationSectionData {
  const _NotificationSectionData({
    required this.kind,
    required this.items,
  });

  final _NotificationSectionKind kind;
  final List<NotificationItemEntity> items;

  String get title {
    return switch (kind) {
      _NotificationSectionKind.actionNeeded => 'Action needed',
      _NotificationSectionKind.routePlans => 'Route plans',
      _NotificationSectionKind.creatorUpdates => 'Creator updates',
      _NotificationSectionKind.otherUpdates => 'Other updates',
    };
  }

  String get shortLabel {
    return switch (kind) {
      _NotificationSectionKind.actionNeeded => 'Actions',
      _NotificationSectionKind.routePlans => 'Routes',
      _NotificationSectionKind.creatorUpdates => 'Creator',
      _NotificationSectionKind.otherUpdates => 'Updates',
    };
  }

  String get subtitle {
    return switch (kind) {
      _NotificationSectionKind.actionNeeded =>
        'Open tasks and reminders that need a next step.',
      _NotificationSectionKind.routePlans =>
        'Scenario routes ready to build, map, or publish.',
      _NotificationSectionKind.creatorUpdates =>
        'Publishing, moderation, and creator workspace updates.',
      _NotificationSectionKind.otherUpdates =>
        'General Recharge news and activity updates.',
    };
  }

  IconData get icon {
    return switch (kind) {
      _NotificationSectionKind.actionNeeded => Icons.priority_high,
      _NotificationSectionKind.routePlans => Icons.route,
      _NotificationSectionKind.creatorUpdates => Icons.storefront_outlined,
      _NotificationSectionKind.otherUpdates => Icons.info_outline,
    };
  }
}

List<_NotificationSectionData> _notificationSectionsFor(
  List<NotificationItemEntity> items,
) {
  final Map<_NotificationSectionKind, List<NotificationItemEntity>> buckets =
      <_NotificationSectionKind, List<NotificationItemEntity>>{
    for (final _NotificationSectionKind kind in _NotificationSectionKind.values)
      kind: <NotificationItemEntity>[],
  };

  for (final NotificationItemEntity item in items) {
    buckets[_notificationSectionKindFor(item)]!.add(item);
  }

  return _NotificationSectionKind.values
      .map(
        (_NotificationSectionKind kind) => _NotificationSectionData(
          kind: kind,
          items: List<NotificationItemEntity>.unmodifiable(buckets[kind]!),
        ),
      )
      .where((_NotificationSectionData section) => section.items.isNotEmpty)
      .toList(growable: false);
}

_NotificationSectionKind _notificationSectionKindFor(
  NotificationItemEntity item,
) {
  if (_NotificationRoutePreview.fromTargetRoute(item.targetRoute) != null) {
    return _NotificationSectionKind.routePlans;
  }

  final String path = _pathForTargetRoute(item.targetRoute);
  final Map<String, String> query = _queryForTargetRoute(item.targetRoute);
  if (_isCreatorNotificationTarget(path: path, query: query)) {
    return _NotificationSectionKind.creatorUpdates;
  }

  final bool hasTargetRoute =
      item.targetRoute != null && item.targetRoute!.trim().isNotEmpty;
  if (!item.isRead &&
      (hasTargetRoute || item.type == NotificationType.reminder)) {
    return _NotificationSectionKind.actionNeeded;
  }

  return _NotificationSectionKind.otherUpdates;
}

bool _isCreatorNotificationTarget({
  required String path,
  required Map<String, String> query,
}) {
  if (path == RouteNames.profile) return true;
  if (path != RouteNames.create) return false;
  return query['source'] == 'publish' || query['status'] == 'pendingReview';
}

class _NotificationDestination {
  const _NotificationDestination({
    required this.icon,
    required this.label,
    required this.actionLabel,
  });

  final IconData icon;
  final String label;
  final String actionLabel;
}

_NotificationDestination _notificationDestinationFor(String? targetRoute) {
  final String path = _pathForTargetRoute(targetRoute);
  final Map<String, String> query = _queryForTargetRoute(targetRoute);

  if (path == RouteNames.scenarioBuilder) {
    return const _NotificationDestination(
      icon: Icons.route,
      label: 'Route scenario',
      actionLabel: 'Open route',
    );
  }
  if (path == RouteNames.discoverMap && query['mode'] == 'scenario') {
    return const _NotificationDestination(
      icon: Icons.route,
      label: 'Route map',
      actionLabel: 'Open route',
    );
  }
  if (path == RouteNames.discoverMap) {
    return const _NotificationDestination(
      icon: Icons.map,
      label: 'Map',
      actionLabel: 'Open map',
    );
  }
  if (path.startsWith(RouteNames.discoverDetails)) {
    return const _NotificationDestination(
      icon: Icons.local_activity,
      label: 'Details',
      actionLabel: 'Open details',
    );
  }
  if (path == RouteNames.favorites) {
    return const _NotificationDestination(
      icon: Icons.favorite,
      label: 'Saved plan',
      actionLabel: 'Open saved',
    );
  }
  if (path == RouteNames.search) {
    return const _NotificationDestination(
      icon: Icons.search,
      label: 'Search',
      actionLabel: 'Search',
    );
  }
  if (path == RouteNames.create) {
    if (query['source'] == 'publish' || query['status'] == 'pendingReview') {
      return const _NotificationDestination(
        icon: Icons.fact_check_outlined,
        label: 'Publish status',
        actionLabel: 'Open listing',
      );
    }
    return const _NotificationDestination(
      icon: Icons.add_circle,
      label: 'Create',
      actionLabel: 'Open create',
    );
  }
  if (path == RouteNames.profile) {
    return const _NotificationDestination(
      icon: Icons.storefront_outlined,
      label: 'Creator profile',
      actionLabel: 'Open profile',
    );
  }
  if (path == RouteNames.discover) {
    return const _NotificationDestination(
      icon: Icons.explore,
      label: 'Discover',
      actionLabel: 'Open feed',
    );
  }
  return const _NotificationDestination(
    icon: Icons.info,
    label: 'Update',
    actionLabel: 'Open',
  );
}

String _pathForTargetRoute(String? targetRoute) {
  if (targetRoute == null || targetRoute.trim().isEmpty) return '';
  return Uri.parse(targetRoute).path;
}

Map<String, String> _queryForTargetRoute(String? targetRoute) {
  if (targetRoute == null || targetRoute.trim().isEmpty) {
    return const <String, String>{};
  }
  return Uri.parse(targetRoute).queryParameters;
}

String? _optionalQueryValue(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value.trim();
}

bool _boolFromQuery(String? value) {
  final String? normalized = _optionalQueryValue(value)?.toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

String? _boolParamFromQuery(String? value) {
  final String? normalized = _optionalQueryValue(value)?.toLowerCase();
  if (normalized == '1' || normalized == 'true' || normalized == 'yes') {
    return '1';
  }
  if (normalized == '0' || normalized == 'false' || normalized == 'no') {
    return '0';
  }
  return null;
}

String _humanizeQueryLabel(String value) {
  final String normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return normalized;
  return normalized[0].toUpperCase() + normalized.substring(1);
}

class _ReadBadge extends StatelessWidget {
  const _ReadBadge({
    required this.isRead,
  });

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isRead
            ? colorScheme.secondaryContainer.withValues(alpha: 0.52)
            : colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          isRead ? 'Read' : 'New',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isRead ? colorScheme.onSecondaryContainer : colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color color = isRead ? colorScheme.outline : colorScheme.primary;
    final IconData icon = switch (type) {
      NotificationType.system => Icons.info,
      NotificationType.reminder => Icons.alarm,
      NotificationType.activity => Icons.local_activity,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _FilteredNotificationsEmpty extends StatelessWidget {
  const _FilteredNotificationsEmpty({
    required this.onShowAll,
  });

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: <Widget>[
          const Icon(Icons.mark_email_read, size: 36),
          const SizedBox(height: 10),
          const Text('Непрочитанных уведомлений нет'),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onShowAll,
            child: const Text('Показать все'),
          ),
        ],
      ),
    );
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

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month ${local.year}, $hour:$minute';
}
