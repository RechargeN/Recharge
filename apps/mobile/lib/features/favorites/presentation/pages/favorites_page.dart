import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../application/controllers/favorites_controller.dart';
import '../../application/favorites_providers.dart';
import '../../application/state/favorites_state.dart';
import '../../domain/entities/favorite_item_entity.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesControllerProvider).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final FavoritesController controller = ref.watch(favoritesControllerProvider);
    final FavoritesState state = controller.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
      ),
      body: switch (state.status) {
        FavoritesStatus.initial || FavoritesStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        FavoritesStatus.error => _StateMessage(
            message: state.message ?? 'Не удалось загрузить избранное',
            actionLabel: 'Повторить',
            onAction: controller.loadFavorites,
          ),
        FavoritesStatus.ready => state.items.isEmpty
            ? _StateMessage(
                message: 'Пока нет сохраненных событий',
                actionLabel: 'Открыть Discover',
                onAction: () async => context.go(RouteNames.discover),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemBuilder: (BuildContext context, int index) {
                  final FavoriteItemEntity item = state.items[index];
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.city} · ${item.distanceKm.toStringAsFixed(1)} км',
                    ),
                    trailing: IconButton(
                      tooltip: 'Удалить из избранного',
                      onPressed: () {
                        controller.removeFavorite(
                          item.id,
                          sourceScreen: 'favorites',
                        );
                      },
                      icon: const Icon(Icons.favorite),
                    ),
                    onTap: () => context.push('${RouteNames.discoverDetails}/${item.id}'),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: state.items.length,
              ),
      },
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
