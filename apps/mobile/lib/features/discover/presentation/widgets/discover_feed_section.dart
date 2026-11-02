import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../../../core/localization/taxonomy_labels.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../application/state/discover_feed_state.dart';
import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/time_fit_evaluation.dart';
import '../discover_formats.dart';

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
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text(context.l10n.discoverFeedLoading),
              ],
            ),
          ),
        );
      case DiscoverFeedStatus.empty:
        return _StateCard(
          message:
              discoverFeedNoticeText(context.l10n, state.message) ??
              context.l10n.discoverFeedEmpty,
          actionLabel: context.l10n.discoverRefresh,
          onAction: controller.loadFeed,
          extraActions: state.appliedQuery.timeWindow == null
              ? const <Widget>[]
              : <Widget>[
                  TextButton(
                    onPressed: () => controller.applyTimeFitRelaxation(
                      TimeFitRelaxation.widenWindow,
                    ),
                    child: Text(context.l10n.discoverWidenTime),
                  ),
                  if (state.appliedQuery.travelContext?.includeReturnTrip ==
                      true)
                    TextButton(
                      onPressed: () => controller.applyTimeFitRelaxation(
                        TimeFitRelaxation.skipReturnTrip,
                      ),
                      child: Text(context.l10n.discoverNoReturnTrip),
                    ),
                  TextButton(
                    onPressed: () => controller.applyTimeFitRelaxation(
                      TimeFitRelaxation.removeTimeFilter,
                    ),
                    child: Text(context.l10n.discoverRemoveTime),
                  ),
                ],
        );
      case DiscoverFeedStatus.error:
        return _StateCard(
          message:
              discoverFeedNoticeText(context.l10n, state.message) ??
              context.l10n.discoverFeedFailed,
          actionLabel: context.l10n.discoverRetry,
          onAction: controller.loadFeed,
        );
      case DiscoverFeedStatus.permissionDenied:
        return _StateCard(
          message:
              discoverFeedNoticeText(context.l10n, state.message) ??
              context.l10n.discoverNoLocationAccess,
          actionLabel: context.l10n.discoverOpenSettings,
          onAction: () async {},
        );
      case DiscoverFeedStatus.ready:
      case DiscoverFeedStatus.denseCluster:
        final bool hasTimeWindow = state.appliedQuery.timeWindow != null;
        bool unknownHeaderAdded = false;
        final List<Widget> children = <Widget>[];
        if (hasTimeWindow) {
          children.add(
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                context.l10n.discoverMatchesYourTime,
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
              Padding(
                padding: EdgeInsets.fromLTRB(0, 12, 0, 8),
                child: Text(
                  context.l10n.discoverTimeNotConfirmed,
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
    final DateTime? start = item.startsAtUtc;
    // The object's zone when it has one; a legacy item without one keeps the
    // device zone it always had.
    final String dateLabel = start == null
        ? (item.activityCatalog == null
              ? context.l10n.discoverAnyTime
              : activityDurationLabel(context.l10n, item.activityCatalog!))
        : item.timezoneId.isEmpty
        ? RechargeFormats.deviceTime(start, context.l10n.localeName)
        : RechargeFormats.time(start, item.timezoneId, context.l10n.localeName);
    final String priceLabel = item.activityCatalog != null
        ? (item.activityCatalog!.contributionKind == null
              ? context.l10n.discoverNoContribution
              : context.l10n.discoverOptionalContribution)
        : item.isFree
        ? context.l10n.discoverFree
        : item.priceAmount == null
        ? '—'
        : RechargeFormats.money(item.priceAmount!, context.l10n.localeName);

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
                        _MetaChip(
                          label: taxonomyLabel(context.l10n, item.category),
                        ),
                        if (item.isFree)
                          _MetaChip(label: context.l10n.discoverFree),
                        if (item.timeFitEvaluation
                            case final evaluation?) ...<Widget>[
                          _MetaChip(
                            label: _timeFitLabel(context.l10n, evaluation),
                          ),
                          _MetaChip(
                            label: _openingLabel(context.l10n, evaluation),
                          ),
                          if (evaluation.travelMinutes != null)
                            _MetaChip(
                              label:
                                  evaluation.quality ==
                                          TravelEstimateQuality.fallback ||
                                      evaluation.quality ==
                                          TravelEstimateQuality.modeled
                                  ? context.l10n.discoverTravelMinutesEstimated(
                                      evaluation.travelMinutes!,
                                    )
                                  : context.l10n.discoverTravelMinutes(
                                      evaluation.travelMinutes!,
                                    ),
                            ),
                          if (evaluation.selectedSlotId != null)
                            // The slot id is a code; only the fact is shown.
                            _MetaChip(label: context.l10n.discoverSlotChosen),
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
                    discoverKm(context.l10n, item.distanceKm),
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

String _timeFitLabel(AppLocalizations l10n, TimeFitEvaluation evaluation) =>
    switch (evaluation.timeFitStatus) {
      TimeFitStatus.fits => l10n.discoverFits,
      TimeFitStatus.partial => l10n.discoverPartialFit,
      TimeFitStatus.doesNotFit => l10n.discoverDoesNotFit,
      TimeFitStatus.unknown => l10n.discoverTimeUnknown,
    };

String _openingLabel(AppLocalizations l10n, TimeFitEvaluation evaluation) =>
    switch (evaluation.openingStatus) {
      OpeningStatus.open => l10n.discoverOpen,
      OpeningStatus.closed => l10n.discoverClosed,
      OpeningStatus.unknown => l10n.discoverHoursUnknown,
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
