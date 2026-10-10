import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/config/legal_links.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/controllers/explore_controller.dart';
import '../../application/explore_providers.dart';
import '../../application/state/explore_state.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.workspaceSectionBuilder});

  final Widget Function(String userId)? workspaceSectionBuilder;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();
  String? _loadKey;

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
    final authController = ref.watch(authControllerProvider);
    final user = authController.state.user;
    final ExploreController exploreController = ref.watch(
      exploreControllerProvider,
    );
    final ExploreState state = exploreController.state;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Требуется авторизация')));
    }

    if (!state.isLoaded || state.userId != user.id) {
      _scheduleLoad(
        userId: user.id,
        email: user.email,
        role: user.role,
        favoritesCount: state.favoritesCount,
      );
    }
    _syncControllers(state);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: switch (state.status) {
        ExploreStatus.initial || ExploreStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        ExploreStatus.error => _StateMessage(
          text: state.message ?? 'Не удалось загрузить настройки',
          actionLabel: 'Повторить',
          onTap: () {
            _loadKey = null;
            _scheduleLoad(
              userId: user.id,
              email: user.email,
              role: user.role,
              favoritesCount: state.favoritesCount,
              force: true,
            );
          },
        ),
        ExploreStatus.ready || ExploreStatus.saving => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const _SettingsSectionTitle('ACCOUNT AND WORKSPACE'),
            const SizedBox(height: 8),
            widget.workspaceSectionBuilder?.call(user.id) ??
                const ListTile(
                  leading: Icon(Icons.account_tree_outlined),
                  title: Text('Switch workspace'),
                  subtitle: Text(
                    'Personal profile, Professional Pages and Admin access',
                  ),
                ),
            const Divider(height: 28),
            _ProfileEditSection(
              displayNameController: _displayNameController,
              aboutController: _aboutController,
              cityController: _cityController,
              avatarController: _avatarController,
              onDisplayNameChanged: exploreController.updateDisplayName,
              onAboutChanged: exploreController.updateAbout,
              onCityChanged: exploreController.updateCity,
              onAvatarChanged: exploreController.updateAvatar,
              onSave: state.status == ExploreStatus.saving
                  ? null
                  : exploreController.saveProfile,
              saving: state.status == ExploreStatus.saving,
            ),
            const Divider(height: 28),
            const _SettingsSectionTitle('CONTENT & ACTIVITY'),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('Saved plans'),
              subtitle: const Text('Saved ideas and personal plans'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.favorites),
            ),
            ListTile(
              leading: const Icon(Icons.search_outlined),
              title: const Text('Search and conditions'),
              subtitle: const Text('Saved searches and discovery filters'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.search),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Notifications'),
              subtitle: const Text('Inbox and route updates'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.notifications),
            ),
            const Divider(height: 28),
            const _SettingsSectionTitle('PREFERENCES'),
            DropdownButtonFormField<String>(
              initialValue: state.settings.language,
              decoration: const InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'ru', child: Text('Русский')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'lv', child: Text('Latviešu')),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  exploreController.updateLanguage(value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: state.settings.currency,
              decoration: const InputDecoration(
                labelText: 'Currency',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  exploreController.updateCurrency(value);
                }
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Notification preferences'),
              value: state.settings.notificationsEnabled,
              onChanged: exploreController.updateNotifications,
            ),
            const Divider(height: 28),
            ListTile(
              title: const Text('Support / Help'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _showLinkDialog(
                context,
                title: 'Support / Help',
                url: LegalLinks.support,
              ),
            ),
            ListTile(
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _showLinkDialog(
                context,
                title: 'Privacy Policy',
                url: LegalLinks.privacyPolicy,
              ),
            ),
            ListTile(
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _showLinkDialog(
                context,
                title: 'Terms of Service',
                url: LegalLinks.termsOfService,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                await authController.signOut();
                if (context.mounted) {
                  context.go(RouteNames.discover);
                }
              },
              child: const Text('Выйти'),
            ),
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
    final String key = '$userId:$role:$favoritesCount';
    if (!force && _loadKey == key) return;
    _loadKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(exploreControllerProvider)
          .ensureLoaded(
            userId: userId,
            email: email,
            role: role,
            favoritesCount: favoritesCount,
          );
    });
  }

  void _syncControllers(ExploreState state) {
    if (!state.isLoaded) return;
    _syncController(_displayNameController, state.profile.displayName);
    _syncController(_aboutController, state.profile.about);
    _syncController(_cityController, state.profile.city);
    _syncController(_avatarController, state.profile.avatar);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  void _showLinkDialog(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(url),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
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
            OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF5E6F68),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ProfileEditSection extends StatelessWidget {
  const _ProfileEditSection({
    required this.displayNameController,
    required this.aboutController,
    required this.cityController,
    required this.avatarController,
    required this.onDisplayNameChanged,
    required this.onAboutChanged,
    required this.onCityChanged,
    required this.onAvatarChanged,
    required this.onSave,
    required this.saving,
  });

  final TextEditingController displayNameController;
  final TextEditingController aboutController;
  final TextEditingController cityController;
  final TextEditingController avatarController;
  final ValueChanged<String> onDisplayNameChanged;
  final ValueChanged<String> onAboutChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onAvatarChanged;
  final Future<void> Function()? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Profile information',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Display name',
          controller: displayNameController,
          onChanged: onDisplayNameChanged,
        ),
        _LabeledField(
          label: 'About',
          controller: aboutController,
          onChanged: onAboutChanged,
          maxLines: 4,
        ),
        _LabeledField(
          label: 'City',
          controller: cityController,
          onChanged: onCityChanged,
        ),
        _LabeledField(
          label: 'Avatar URL/Path',
          controller: avatarController,
          onChanged: onAvatarChanged,
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Сохраняем...' : 'Сохранить профиль'),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        minLines: maxLines > 1 ? 2 : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
