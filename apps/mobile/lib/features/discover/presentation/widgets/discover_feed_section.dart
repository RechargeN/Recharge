import 'package:flutter/material.dart';

import '../../../../shared/primitives/money/money_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/recharge_taxonomy.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../application/state/discover_feed_state.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/time_fit_evaluation.dart';

class DiscoverFeedSection extends ConsumerStatefulWidget {
  const DiscoverFeedSection({super.key, required this.onOpenDetails});

  final ValueChanged<String> onOpenDetails;

  @override
  ConsumerState<DiscoverFeedSection> createState() =>
      _DiscoverFeedSectionState();
}

class _DiscoverFeedSectionState extends ConsumerState<DiscoverFeedSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoverFeedControllerProvider).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final DiscoverFeedController controller = ref.watch(
      discoverFeedControllerProvider,
    );
    final DiscoverFeedState state = controller.state;

    switch (state.status) {
      case DiscoverFeedStatus.initial:
      case DiscoverFeedStatus.loading:
      case DiscoverFeedStatus.selectingArea:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Загружаем ленту...'),
              ],
            ),
          ),
        );
      case DiscoverFeedStatus.empty:
        return _StateCard(
          message: state.message ?? 'Пока в ленте ничего нет',
          actionLabel: 'Обновить',
          onAction: controller.loadFeed,
          extraActions: state.appliedQuery.timeWindow == null
              ? const <Widget>[]
              : <Widget>[
                  TextButton(
                    onPressed: () => controller.applyTimeFitRelaxation(
                      TimeFitRelaxation.widenWindow,
                    ),
                    child: const Text('Расширить время'),
                  ),
                  if (state.appliedQuery.travelContext?.includeReturnTrip ==
                      true)
                    TextButton(
                      onPressed: () => controller.applyTimeFitRelaxation(
                        TimeFitRelaxation.skipReturnTrip,
                      ),
                      child: const Text('Без обратной дороги'),
                    ),
                  TextButton(
                    onPressed: () => controller.applyTimeFitRelaxation(
                      TimeFitRelaxation.removeTimeFilter,
                    ),
                    child: const Text('Убрать время'),
                  ),
                ],
        );
      case DiscoverFeedStatus.error:
        return _StateCard(
          message: state.message ?? 'Не удалось загрузить ленту',
          actionLabel: 'Повторить',
          onAction: controller.loadFeed,
        );
      case DiscoverFeedStatus.permissionDenied:
        return _StateCard(
          message: state.message ?? 'Нет доступа к геопозиции',
          actionLabel: 'Открыть настройки',
          onAction: () async {},
        );
      case DiscoverFeedStatus.ready:
      case DiscoverFeedStatus.denseCluster:
        final bool hasTimeWindow = state.appliedQuery.timeWindow != null;
        bool unknownHeaderAdded = false;
        final List<Widget> children = <Widget>[];
        if (hasTimeWindow) {
          children.add(
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Matches your time',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }
        for (final DiscoverItemEntity item in state.items) {
          if (hasTimeWindow &&
              item.timeFitEvaluation?.timeFitStatus == TimeFitStatus.unknown &&
              !unknownHeaderAdded) {
            unknownHeaderAdded = true;
            children.add(
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 12, 0, 8),
                child: Text(
                  'Time not confirmed',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            );
          }
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DiscoverFeedCard(
                item: item,
                onTap: () => widget.onOpenDetails(item.id),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
    }
  }
}

class _DiscoverFeedCard extends StatelessWidget {
  const _DiscoverFeedCard({required this.item, required this.onTap});

  final DiscoverItemEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final DateTime localStart = item.startsAtUtc.toLocal();
    final String hour = localStart.hour.toString().padLeft(2, '0');
    final String minute = localStart.minute.toString().padLeft(2, '0');
    final String dateLabel = '$hour:$minute';
    final String priceLabel = item.isFree
        ? 'Free'
        : MoneyFormatter.format(item.price);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_activity_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _MetaChip(label: rechargeTaxonomyLabel(item.category)),
                        if (item.isFree) const _MetaChip(label: 'Free'),
                        if (item.timeFitEvaluation
                            case final evaluation?) ...<Widget>[
                          _MetaChip(label: _timeFitLabel(evaluation)),
                          _MetaChip(label: _openingLabel(evaluation)),
                          if (evaluation.travelMinutes != null)
                            _MetaChip(
                              label:
                                  '${evaluation.travelMinutes} min travel'
                                  '${evaluation.quality == TravelEstimateQuality.fallback || evaluation.quality == TravelEstimateQuality.modeled ? ' · est.' : ''}',
                            ),
                          if (evaluation.selectedSlotId != null)
                            _MetaChip(
                              label: 'Slot ${evaluation.selectedSlotId}',
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${item.city} · $dateLabel',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${item.distanceKm.toStringAsFixed(1)} км',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _timeFitLabel(TimeFitEvaluation evaluation) =>
    switch (evaluation.timeFitStatus) {
      TimeFitStatus.fits => 'Fits',
      TimeFitStatus.partial => 'Partial fit',
      TimeFitStatus.doesNotFit => 'Does not fit',
      TimeFitStatus.unknown => 'Time unknown',
    };

String _openingLabel(TimeFitEvaluation evaluation) =>
    switch (evaluation.openingStatus) {
      OpeningStatus.open => 'Open',
      OpeningStatus.closed => 'Closed',
      OpeningStatus.unknown => 'Hours unknown',
    };

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.extraActions = const <Widget>[],
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(message),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ...extraActions,
          ],
        ),
      ),
    );
  }
}
