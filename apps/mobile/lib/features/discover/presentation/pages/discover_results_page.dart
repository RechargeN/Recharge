import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/discover_providers.dart';
import '../../application/state/discover_feed_state.dart';
import '../../domain/entities/discover_item_entity.dart';

class DiscoverResultsPage extends ConsumerWidget {
  const DiscoverResultsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DiscoverFeedState state = ref.watch(discoverFeedControllerProvider).state;

    return Scaffold(
      appBar: AppBar(
        title: Text('Results (${state.resultCount})'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (BuildContext context, int index) {
          final DiscoverItemEntity item = state.items[index];
          return ListTile(
            onTap: () => context.push('${RouteNames.discoverDetails}/${item.id}'),
            title: Text(item.title),
            subtitle: Text(
              '${item.city} · ${item.category} · ${item.distanceKm.toStringAsFixed(1)} км',
            ),
            trailing: Text(item.isFree ? 'Free' : '${item.priceAmount.toStringAsFixed(0)} €'),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: state.items.length,
      ),
    );
  }
}

