import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/adapters/legacy_notification_route_resolver.dart';
import '../../../../app/application/planning_navigation_intent.dart';
import '../../../../app/application/planning_navigation_resolver.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../create/application/create_taxonomy.dart';
import '../../application/controllers/notifications_controller.dart';
import '../../application/notifications_providers.dart';
import '../../application/state/notifications_state.dart';
import '../../domain/entities/notification_item_entity.dart';

enum _NotificationFeedFilter { all, newItems, reminders, updates, scenarios }

const Color _notificationsBackground = Color(0xFFF8FAF7);
const Color _rechargeGreen = Color(0xFF0B3028);
const Color _notificationFeedCard = Color(0xFF004532);
const Color _notificationUnreadDot = Color(0xFF86F076);
const Color _notificationsChip = Color(0xFFEAF0EA);

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _loadedUserId;
  _NotificationFeedFilter _filter = _NotificationFeedFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).state;
    final NotificationsController controller = ref.watch(
      notificationsControllerProvider,
    );
    final NotificationsState state = controller.state;
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _notificationsBackground,
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
      backgroundColor: _notificationsBackground,
      appBar: AppBar(
        backgroundColor: _notificationsBackground,
        foregroundColor: _rechargeGreen,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'RECHARGE',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: <Widget>[
          if (state.status == NotificationsStatus.ready &&
              state.unreadCount > 0)
            IconButton(
              tooltip: 'Read all',
              onPressed: controller.markAllAsRead,
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: switch (state.status) {
        NotificationsStatus.initial || NotificationsStatus.loading =>
          const Center(child: CircularProgressIndicator()),
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

    final List<NotificationItemEntity> visibleItems = _filteredItems(
      state.searchResults,
    );

    return RefreshIndicator(
      color: _rechargeGreen,
      onRefresh: () => controller.loadNotifications(userId: userId),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
        children: <Widget>[
          TextField(
            key: const Key('notifications-search'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: controller.updateSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search notifications',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: state.searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        controller.clearSearch();
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _NotificationFilterBar(
            selected: _filter,
            onChanged: (_NotificationFeedFilter next) {
              setState(() => _filter = next);
            },
          ),
          const SizedBox(height: 12),
          if (visibleItems.isEmpty)
            _FilteredNotificationsEmpty(
              hasSearchQuery: state.searchQuery.isNotEmpty,
              onShowAll: () {
                _searchController.clear();
                controller.clearSearch();
                setState(() => _filter = _NotificationFeedFilter.all);
              },
            )
          else
            ...visibleItems.map(
              (NotificationItemEntity item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _notificationCardFor(item: item, controller: controller),
              ),
            ),
        ],
      ),
    );
  }

  List<NotificationItemEntity> _filteredItems(
    List<NotificationItemEntity> items,
  ) {
    return switch (_filter) {
      _NotificationFeedFilter.all => items,
      _NotificationFeedFilter.newItems =>
        items
            .where((NotificationItemEntity item) => !item.isRead)
            .toList(growable: false),
      _NotificationFeedFilter.reminders =>
        items
            .where(
              (NotificationItemEntity item) =>
                  item.type == NotificationType.reminder,
            )
            .toList(growable: false),
      _NotificationFeedFilter.updates =>
        items
            .where(
              (NotificationItemEntity item) =>
                  item.type != NotificationType.reminder &&
                  item.scenarioContext == null,
            )
            .toList(growable: false),
      _NotificationFeedFilter.scenarios =>
        items
            .where((item) => item.scenarioContext != null)
            .toList(growable: false),
    };
  }

  Widget _notificationCardFor({
    required NotificationItemEntity item,
    required NotificationsController controller,
  }) {
    return _NotificationCard(
      item: item,
      onOpen: () => _openNotification(item),
      onOpenLocation: (String location) =>
          _openNotification(item, targetRoute: location),
    );
  }

  Future<void> _openNotification(
    NotificationItemEntity item, {
    String? targetRoute,
  }) async {
    await ref.read(notificationsControllerProvider).markAsRead(item.id);
    if (!mounted) return;
    final String? route =
        targetRoute ?? _typedSubjectRoute(item.subjectRef) ?? item.targetRoute;
    if (route == null || route.isEmpty) return;
    final resolved = const LegacyNotificationRouteResolver().resolve(route);
    if (resolved != null) context.push(resolved);
  }
}

String? _typedSubjectRoute(NotificationSubjectRef? subject) {
  if (subject == null || subject.id.trim().isEmpty) return null;
  return switch (subject.kind) {
    NotificationSubjectKind.route => const PlanningNavigationResolver().resolve(
      PlanningNavigationIntent.openRoute(subject.id),
    ),
    NotificationSubjectKind.system => null,
    _ => '${RouteNames.discoverDetails}/${Uri.encodeComponent(subject.id)}',
  };
}

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final _NotificationFeedFilter selected;
  final ValueChanged<_NotificationFeedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _NotificationFilterChip(
            icon: Icons.apps_rounded,
            label: 'All',
            selected: selected == _NotificationFeedFilter.all,
            onTap: () => onChanged(_NotificationFeedFilter.all),
          ),
          const SizedBox(width: 8),
          _NotificationFilterChip(
            icon: Icons.fiber_new_outlined,
            label: 'New',
            selected: selected == _NotificationFeedFilter.newItems,
            onTap: () => onChanged(_NotificationFeedFilter.newItems),
          ),
          const SizedBox(width: 8),
          _NotificationFilterChip(
            icon: Icons.notifications_none,
            label: 'Reminders',
            selected: selected == _NotificationFeedFilter.reminders,
            onTap: () => onChanged(_NotificationFeedFilter.reminders),
          ),
          const SizedBox(width: 8),
          _NotificationFilterChip(
            icon: Icons.sync,
            label: 'Updates',
            selected: selected == _NotificationFeedFilter.updates,
            onTap: () => onChanged(_NotificationFeedFilter.updates),
          ),
          const SizedBox(width: 8),
          _NotificationFilterChip(
            icon: Icons.event_note_outlined,
            label: 'Scenarios',
            selected: selected == _NotificationFeedFilter.scenarios,
            onTap: () => onChanged(_NotificationFeedFilter.scenarios),
          ),
        ],
      ),
    );
  }
}

class _NotificationFilterChip extends StatelessWidget {
  const _NotificationFilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected ? _rechargeGreen : _notificationsChip;
    final Color foreground = selected ? Colors.white : _rechargeGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _rechargeGreen : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
  });

  final NotificationItemEntity item;
  final VoidCallback onOpen;
  final Future<void> Function(String location) onOpenLocation;

  @override
  Widget build(BuildContext context) {
    final _NotificationDestination destination = _notificationDestinationFor(
      item.targetRoute,
    );
    final _NotificationRoutePreview? routePreview =
        _NotificationRoutePreview.fromTargetRoute(item.targetRoute);
    final List<_NotificationRouteAction> routeActions =
        routePreview?.actionTargets ?? const <_NotificationRouteAction>[];
    final bool hasTargetRoute =
        item.targetRoute != null && item.targetRoute!.trim().isNotEmpty;
    final bool hasMenu = hasTargetRoute || routeActions.isNotEmpty;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        decoration: BoxDecoration(
          color: _notificationFeedCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: item.isRead ? 0.08 : 0.18),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1A003F32),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _TypeIcon(type: item.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.18,
                        ),
                      ),
                      if (hasTargetRoute) ...<Widget>[
                        const SizedBox(height: 5),
                        Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _formatTime(item.createdAtUtc),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hasMenu) ...<Widget>[
                        const SizedBox(height: 6),
                        _NotificationActionsMenu(
                          destination: destination,
                          routeActions: routeActions,
                          onOpen: onOpen,
                          onOpenLocation: onOpenLocation,
                        ),
                      ] else
                        const SizedBox(height: 18),
                      const SizedBox(height: 6),
                      _UnreadDot(isRead: item.isRead),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationActionsMenu extends StatelessWidget {
  const _NotificationActionsMenu({
    required this.destination,
    required this.routeActions,
    required this.onOpen,
    required this.onOpenLocation,
  });

  final _NotificationDestination destination;
  final List<_NotificationRouteAction> routeActions;
  final VoidCallback onOpen;
  final Future<void> Function(String location) onOpenLocation;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_NotificationMenuAction>(
      tooltip: 'Notification actions',
      icon: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 32),
      color: Colors.white,
      onSelected: (_NotificationMenuAction action) {
        if (action.location == null) {
          onOpen();
          return;
        }
        onOpenLocation(action.location!);
      },
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<_NotificationMenuAction>>[
          PopupMenuItem<_NotificationMenuAction>(
            value: _NotificationMenuAction(location: null),
            child: Row(
              children: <Widget>[
                Icon(destination.icon, size: 18),
                const SizedBox(width: 8),
                Text(destination.actionLabel),
              ],
            ),
          ),
          ...routeActions.map(
            (_NotificationRouteAction action) =>
                PopupMenuItem<_NotificationMenuAction>(
                  value: _NotificationMenuAction(location: action.location),
                  child: Row(
                    children: <Widget>[
                      Icon(action.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(action.label),
                    ],
                  ),
                ),
          ),
        ];
      },
    );
  }
}

class _NotificationMenuAction {
  const _NotificationMenuAction({required this.location});

  final String? location;
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isRead
            ? Colors.white.withValues(alpha: 0.22)
            : _notificationUnreadDot,
        shape: BoxShape.circle,
      ),
      child: const SizedBox(width: 8, height: 8),
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
      if (stepLabels.isNotEmpty) '${stepLabels.length} stops',
      if (durationLabel != null) durationLabel!,
      if (freeOnly) 'Free',
      if (walkingOnly) 'Walking',
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
      path: RouteNames.legacyScenarioBuilder,
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

  // Legacy raw planning links remain openable during the observation period,
  // but Notifications must not expose Scenario/Builder route actions.
  List<_NotificationRouteAction> get actionTargets =>
      const <_NotificationRouteAction>[];

  static _NotificationRoutePreview? fromTargetRoute(String? targetRoute) {
    final String path = _pathForTargetRoute(targetRoute);
    final Map<String, String> query = _queryForTargetRoute(targetRoute);
    final bool isRouteTarget =
        path == RouteNames.legacyScenarioBuilder ||
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
    final String? free = _boolParamFromQuery(
      query['free'] ?? query['freeOnly'],
    );
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

  if (path == RouteNames.legacyScenarioBuilder) {
    return const _NotificationDestination(
      icon: Icons.notifications_outlined,
      label: 'Legacy notification',
      actionLabel: 'Open',
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

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final NotificationType type;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (type) {
      NotificationType.system => Icons.info,
      NotificationType.reminder => Icons.alarm,
      NotificationType.activity => Icons.local_activity,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _FilteredNotificationsEmpty extends StatelessWidget {
  const _FilteredNotificationsEmpty({
    required this.hasSearchQuery,
    required this.onShowAll,
  });

  final bool hasSearchQuery;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: <Widget>[
          const Icon(Icons.mark_email_read, size: 36),
          const SizedBox(height: 10),
          Text(
            hasSearchQuery
                ? 'По вашему запросу ничего не найдено'
                : 'В этом фильтре пока пусто',
          ),
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
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final DateTime local = value.toLocal();
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
