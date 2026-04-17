import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../application/controllers/explore_controller.dart';
import '../../application/explore_providers.dart';
import '../../application/state/explore_state.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();

  String? _loadKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesControllerProvider).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _aboutController.dispose();
    _cityController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).state;
    final favoritesState = ref.watch(favoritesControllerProvider).state;
    final ExploreController exploreController = ref.watch(exploreControllerProvider);
    final ExploreState state = exploreController.state;

    final user = authState.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Требуется авторизация')),
      );
    }

    _scheduleLoad(
      userId: user.id,
      email: user.email,
      role: user.role,
      favoritesCount: favoritesState.items.length,
    );
    _syncControllers(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Настройки',
            onPressed: () => context.push(RouteNames.settings),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: switch (state.status) {
        ExploreStatus.initial || ExploreStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        ExploreStatus.error => _StateMessage(
            text: state.message ?? 'Не удалось загрузить профиль',
            actionLabel: 'Повторить',
            onTap: () {
              _loadKey = null;
              _scheduleLoad(
                userId: user.id,
                email: user.email,
                role: user.role,
                favoritesCount: favoritesState.items.length,
                force: true,
              );
            },
          ),
        ExploreStatus.ready || ExploreStatus.saving => ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                'Read-only',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _ReadOnlyRow(label: 'User ID', value: state.userId),
              _ReadOnlyRow(label: 'Email', value: state.email),
              _ReadOnlyRow(label: 'Role', value: state.currentRole),
              _ReadOnlyRow(
                label: 'Favorites',
                value: state.favoritesCount.toString(),
              ),
              const SizedBox(height: 16),
              Text(
                'Редактирование',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
                onChanged: exploreController.updateDisplayName,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aboutController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'About',
                  border: OutlineInputBorder(),
                ),
                onChanged: exploreController.updateAbout,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                onChanged: exploreController.updateCity,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _avatarController,
                decoration: const InputDecoration(
                  labelText: 'Avatar URL/Path',
                  border: OutlineInputBorder(),
                ),
                onChanged: exploreController.updateAvatar,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.status == ExploreStatus.saving
                    ? null
                    : exploreController.saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  state.status == ExploreStatus.saving
                      ? 'Сохраняем...'
                      : 'Сохранить профиль',
                ),
              ),
              if (state.message != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  state.message!,
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ],
          ),
      },
    );
  }

  void _scheduleLoad({
    required String userId,
    required String email,
    required String role,
    required int favoritesCount,
    bool force = false,
  }) {
    final String key = '$userId:$favoritesCount';
    if (!force && _loadKey == key) return;
    _loadKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(exploreControllerProvider).ensureLoaded(
            userId: userId,
            email: email,
            role: role,
            favoritesCount: favoritesCount,
          );
    });
  }

  void _syncControllers(ExploreState state) {
    if (!state.isLoaded) return;
    if (_displayNameController.text != state.profile.displayName) {
      _displayNameController.text = state.profile.displayName;
    }
    if (_aboutController.text != state.profile.about) {
      _aboutController.text = state.profile.about;
    }
    if (_cityController.text != state.profile.city) {
      _cityController.text = state.profile.city;
    }
    if (_avatarController.text != state.profile.avatar) {
      _avatarController.text = state.profile.avatar;
    }
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(text),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onTap,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
