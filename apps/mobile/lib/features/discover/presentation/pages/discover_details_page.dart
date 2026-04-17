import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/telemetry/analytics_service.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/application/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_gate_sheet.dart';
import '../../../favorites/application/controllers/favorites_controller.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../../favorites/domain/entities/favorite_item_entity.dart';
import '../../application/discover_providers.dart';
import '../../domain/entities/discover_item_entity.dart';

class DiscoverDetailsPage extends ConsumerStatefulWidget {
  const DiscoverDetailsPage({
    super.key,
    required this.itemId,
    required this.favoriteApplied,
  });

  final String itemId;
  final bool favoriteApplied;

  @override
  ConsumerState<DiscoverDetailsPage> createState() => _DiscoverDetailsPageState();
}

class _DiscoverDetailsPageState extends ConsumerState<DiscoverDetailsPage> {
  late final AnalyticsService _analyticsService;
  bool _viewTracked = false;
  bool _errorTracked = false;
  bool _favoriteHandled = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesControllerProvider).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.watch(authControllerProvider);
    final isAuthenticated = authController.state.isAuthenticated;
    final favoritesController = ref.watch(favoritesControllerProvider);
    final isFavorite = favoritesController.isFavorite(widget.itemId);
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
          _tryAutoApplyFavorite(
            item: item,
            isAuthenticated: isAuthenticated,
            favoritesController: favoritesController,
          );
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _onFavoriteTap(
                  item: item,
                  isAuthenticated: isAuthenticated,
                  authController: authController,
                  favoritesController: favoritesController,
                ),
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                label: Text(
                  isFavorite ? 'Убрать из избранного' : 'Добавить в избранное',
                ),
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

  void _tryAutoApplyFavorite({
    required DiscoverItemEntity item,
    required bool isAuthenticated,
    required FavoritesController favoritesController,
  }) {
    if (!widget.favoriteApplied || _favoriteHandled || !isAuthenticated) {
      return;
    }
    _favoriteHandled = true;
    if (favoritesController.isFavorite(item.id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await favoritesController.addFavorite(
        _toFavorite(item),
        sourceScreen: 'discover_details',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено в избранное')),
      );
    });
  }

  Future<void> _onFavoriteTap({
    required DiscoverItemEntity item,
    required bool isAuthenticated,
    required AuthController authController,
    required FavoritesController favoritesController,
  }) async {
    if (!isAuthenticated) {
      authController.trackAuthGateViewed(
        sourceScreen: 'discover_details',
        sourceAction: 'favorite_tap',
      );
      await showAuthGateSheet(
        context,
        action: ProtectedAction.favorite,
        sourceScreen: 'discover_details',
        sourceAction: 'favorite_tap',
        originRoute: '${RouteNames.discoverDetails}/${item.id}',
        onContinueAsGuest: () {
          authController.trackGuestContinueClicked(
            sourceScreen: 'discover_details',
            sourceAction: 'favorite_tap',
          );
        },
      );
      return;
    }

    await favoritesController.toggleFavorite(
      _toFavorite(item),
      sourceScreen: 'discover_details',
    );
  }

  FavoriteItemEntity _toFavorite(DiscoverItemEntity item) {
    return FavoriteItemEntity(
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      city: item.city,
      category: item.category,
      startsAtUtc: item.startsAtUtc,
      distanceKm: item.distanceKm,
      priceAmount: item.priceAmount,
      isFree: item.isFree,
      savedAtUtc: DateTime.now().toUtc(),
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
