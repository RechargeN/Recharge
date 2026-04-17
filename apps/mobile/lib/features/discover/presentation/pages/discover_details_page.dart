import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/telemetry/analytics_service.dart';
import '../../application/discover_providers.dart';
import '../../domain/entities/discover_item_entity.dart';

class DiscoverDetailsPage extends ConsumerStatefulWidget {
  const DiscoverDetailsPage({
    super.key,
    required this.itemId,
  });

  final String itemId;

  @override
  ConsumerState<DiscoverDetailsPage> createState() => _DiscoverDetailsPageState();
}

class _DiscoverDetailsPageState extends ConsumerState<DiscoverDetailsPage> {
  late final AnalyticsService _analyticsService;
  bool _viewTracked = false;
  bool _errorTracked = false;

  @override
  void initState() {
    super.initState();
    _analyticsService = sl<AnalyticsService>();
    _analyticsService.track(
      'discover_details_load_started',
      params: <String, Object?>{
        'item_id': widget.itemId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(discoverDetailsProvider(widget.itemId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
      ),
      body: details.when(
        data: (DiscoverItemEntity item) {
          if (!_viewTracked) {
            _viewTracked = true;
            _analyticsService.track(
              'discover_details_viewed',
              params: <String, Object?>{
                'item_id': item.id,
                'category': item.category,
                'city': item.city,
              },
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(item.subtitle),
              const SizedBox(height: 20),
              _RowLabel(label: 'Город', value: item.city),
              _RowLabel(label: 'Категория', value: item.category),
              _RowLabel(
                label: 'Время',
                value: item.startsAtUtc.toLocal().toString(),
              ),
              _RowLabel(
                label: 'Дистанция',
                value: '${item.distanceKm.toStringAsFixed(1)} км',
              ),
              _RowLabel(
                label: 'Стоимость',
                value: item.isFree ? 'Бесплатно' : 'Платно',
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (_, __) {
          if (!_errorTracked) {
            _errorTracked = true;
            _analyticsService.track(
              'discover_details_load_failed',
              params: <String, Object?>{
                'item_id': widget.itemId,
              },
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Не удалось загрузить details'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      _errorTracked = false;
                      ref.invalidate(discoverDetailsProvider(widget.itemId));
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label: $value'),
    );
  }
}
