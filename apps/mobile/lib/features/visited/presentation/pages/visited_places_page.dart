import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/controllers/visited_places_controller.dart';
import '../../application/state/visited_places_state.dart';
import '../../application/visited_places_providers.dart';
import '../../domain/entities/visited_place_entity.dart';

class VisitedPlacesPage extends ConsumerStatefulWidget {
  const VisitedPlacesPage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<VisitedPlacesPage> createState() => _VisitedPlacesPageState();
}

class _VisitedPlacesPageState extends ConsumerState<VisitedPlacesPage> {
  String? _requestedUserId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (widget.userId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Требуется авторизация')));
    }

    _scheduleLoad(widget.userId);
    final VisitedPlacesController controller = ref.watch(
      visitedPlacesControllerProvider,
    );
    final VisitedPlacesState state = controller.state;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Visit history'),
        centerTitle: true,
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      body: switch (state.status) {
        VisitedPlacesStatus.initial || VisitedPlacesStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        VisitedPlacesStatus.error => _MessageState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load visits',
          message: state.message ?? 'Try again.',
          actionLabel: 'Retry',
          onAction: () => controller.loadVisitedPlaces(userId: widget.userId),
        ),
        VisitedPlacesStatus.ready when state.items.isEmpty =>
          const _MessageState(
            icon: Icons.place_outlined,
            title: 'No visits yet',
            message: 'Places you explicitly mark as visited will appear here.',
          ),
        VisitedPlacesStatus.ready => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            Text(
              'Visit history',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Private, self-reported places you visited.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            _VisitPeriodFilter(
              selectedMonth: state.selectedMonth,
              selectedDay: state.selectedDay,
              onMonthPressed: () => _selectMonth(context, controller),
              onDayPressed: () => _selectDay(context, controller),
              onClear: state.hasTimeFilter ? controller.clearTimeFilter : null,
            ),
            const SizedBox(height: 18),
            if (state.visibleItems.isEmpty)
              _FilteredPeriodEmpty(onClear: controller.clearTimeFilter)
            else
              for (final VisitedPlaceEntity item in state.visibleItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _VisitedPlaceCard(
                    item: item,
                    onTap: () => context.push(
                      '${RouteNames.discoverDetails}/${item.placeId}',
                    ),
                    onRemove: () => _removeVisit(
                      context,
                      controller: controller,
                      userId: widget.userId,
                      item: item,
                    ),
                  ),
                ),
          ],
        ),
      },
    );
  }

  Future<void> _selectMonth(
    BuildContext context,
    VisitedPlacesController controller,
  ) async {
    final List<DateTime> months = _availableMonths(controller.state.items);
    if (months.isEmpty) return;

    final DateTime? selected = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Select month',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final DateTime month in months)
                ListTile(
                  leading: const Icon(Icons.calendar_view_month_outlined),
                  title: Text(
                    MaterialLocalizations.of(
                      sheetContext,
                    ).formatMonthYear(month),
                  ),
                  trailing: _sameMonth(controller.state.selectedMonth, month)
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(month),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      controller.selectMonth(selected);
    }
  }

  Future<void> _selectDay(
    BuildContext context,
    VisitedPlacesController controller,
  ) async {
    if (controller.state.items.isEmpty) return;

    final DateTime now = DateTime.now();
    final DateTime? selectedMonth = controller.state.selectedMonth;
    final DateTime firstDate = selectedMonth == null
        ? _earliestVisitDate(controller.state.items)
        : DateTime(selectedMonth.year, selectedMonth.month);
    final DateTime lastDate = selectedMonth == null
        ? _latestAllowedDate(controller.state.items, now)
        : DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    final DateTime initialDate =
        controller.state.selectedDay ??
        selectedMonth ??
        _clampDate(now, firstDate, lastDate);

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _clampDate(initialDate, firstDate, lastDate),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select visit day',
    );

    if (selected != null) {
      controller.selectDay(selected);
    }
  }

  void _scheduleLoad(String userId) {
    if (_requestedUserId == userId) return;
    _requestedUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(visitedPlacesControllerProvider).ensureLoaded(userId: userId);
    });
  }

  Future<void> _removeVisit(
    BuildContext context, {
    required VisitedPlacesController controller,
    required String userId,
    required VisitedPlaceEntity item,
  }) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Remove visit?'),
              content: Text(
                '${item.title} · '
                '${MaterialLocalizations.of(context).formatMediumDate(item.visitedOn)}',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) return;
    await controller.removeVisit(userId: userId, visitId: item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Visit removed')));
  }
}

class _VisitPeriodFilter extends StatelessWidget {
  const _VisitPeriodFilter({
    required this.selectedMonth,
    required this.selectedDay,
    required this.onMonthPressed,
    required this.onDayPressed,
    required this.onClear,
  });

  final DateTime? selectedMonth;
  final DateTime? selectedDay;
  final VoidCallback onMonthPressed;
  final VoidCallback onDayPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: onMonthPressed,
          icon: const Icon(Icons.calendar_view_month_outlined, size: 18),
          label: Text(
            selectedMonth == null
                ? 'Month'
                : localizations.formatMonthYear(selectedMonth!),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onDayPressed,
          icon: const Icon(Icons.calendar_today_outlined, size: 17),
          label: Text(
            selectedDay == null
                ? 'Day'
                : localizations.formatMediumDate(selectedDay!),
          ),
        ),
        if (onClear != null)
          TextButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }
}

class _FilteredPeriodEmpty extends StatelessWidget {
  const _FilteredPeriodEmpty({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Icon(Icons.event_busy_outlined, color: colors.primary),
            const SizedBox(height: 10),
            Text(
              'No visits in this period',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onClear, child: const Text('Clear period')),
          ],
        ),
      ),
    );
  }
}

class _VisitedPlaceCard extends StatelessWidget {
  const _VisitedPlaceCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final VisitedPlaceEntity item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 104,
              height: 132,
              child: item.coverImageUrl.isEmpty
                  ? ColoredBox(
                      color: colors.secondaryContainer,
                      child: Icon(
                        Icons.place_outlined,
                        color: colors.onSecondaryContainer,
                      ),
                    )
                  : Image.network(
                      item.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: colors.secondaryContainer,
                        child: Icon(
                          Icons.place_outlined,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(item.visitedOn),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Visit actions',
                          onSelected: (String action) {
                            if (action == 'remove') onRemove();
                          },
                          itemBuilder: (BuildContext context) =>
                              const <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'remove',
                                  child: Text('Remove from history'),
                                ),
                              ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Self-reported',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<DateTime> _availableMonths(List<VisitedPlaceEntity> items) {
  final Map<int, DateTime> uniqueMonths = <int, DateTime>{};
  for (final VisitedPlaceEntity item in items) {
    final DateTime localDate = item.visitedOn;
    uniqueMonths[localDate.year * 100 + localDate.month] = DateTime(
      localDate.year,
      localDate.month,
    );
  }
  final List<DateTime> months = uniqueMonths.values.toList(growable: false);
  months.sort((DateTime a, DateTime b) => b.compareTo(a));
  return months;
}

bool _sameMonth(DateTime? left, DateTime right) {
  return left?.year == right.year && left?.month == right.month;
}

DateTime _earliestVisitDate(List<VisitedPlaceEntity> items) {
  DateTime earliest = items.first.visitedOn;
  for (final VisitedPlaceEntity item in items.skip(1)) {
    final DateTime candidate = item.visitedOn;
    if (candidate.isBefore(earliest)) earliest = candidate;
  }
  return DateTime(earliest.year, earliest.month, earliest.day);
}

DateTime _latestAllowedDate(List<VisitedPlaceEntity> items, DateTime today) {
  DateTime latest = DateTime(today.year, today.month, today.day);
  for (final VisitedPlaceEntity item in items) {
    final DateTime candidate = item.visitedOn;
    if (candidate.isAfter(latest)) {
      latest = DateTime(candidate.year, candidate.month, candidate.day);
    }
  }
  return latest;
}

DateTime _clampDate(DateTime value, DateTime firstDate, DateTime lastDate) {
  if (value.isBefore(firstDate)) return firstDate;
  if (value.isAfter(lastDate)) return lastDate;
  return value;
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 42, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
