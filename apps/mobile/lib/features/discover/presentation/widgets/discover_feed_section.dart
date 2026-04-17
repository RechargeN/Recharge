import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../application/state/discover_feed_state.dart';
import '../../domain/entities/discover_item_entity.dart';

class DiscoverFeedSection extends ConsumerStatefulWidget {
  const DiscoverFeedSection({
    super.key,
    required this.onOpenDetails,
  });

  final ValueChanged<String> onOpenDetails;

  @override
  ConsumerState<DiscoverFeedSection> createState() => _DiscoverFeedSectionState();
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
    final DiscoverFeedController controller =
        ref.watch(discoverFeedControllerProvider);
    final DiscoverFeedState state = controller.state;

    switch (state.status) {
      case DiscoverFeedStatus.initial:
      case DiscoverFeedStatus.loading:
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
        );
      case DiscoverFeedStatus.error:
        return _StateCard(
          message: state.message ?? 'Не удалось загрузить ленту',
          actionLabel: 'Повторить',
          onAction: controller.loadFeed,
        );
      case DiscoverFeedStatus.success:
        return Column(
          children: state.items
              .map(
                (DiscoverItemEntity item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DiscoverFeedCard(
                    item: item,
                    onTap: () => widget.onOpenDetails(item.id),
                  ),
                ),
              )
              .toList(growable: false),
        );
    }
  }
}

class _DiscoverFeedCard extends StatelessWidget {
  const _DiscoverFeedCard({
    required this.item,
    required this.onTap,
  });

  final DiscoverItemEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String dateLabel =
        '${item.startsAtUtc.toLocal().hour.toString().padLeft(2, '0')}:${item.startsAtUtc.toLocal().minute.toString().padLeft(2, '0')}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(item.title),
        subtitle: Text('${item.subtitle}\n${item.city} · $dateLabel'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('${item.distanceKm.toStringAsFixed(1)} км'),
            Text(item.isFree ? 'Free' : 'Paid'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

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

