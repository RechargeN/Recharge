import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/config/legal_links.dart';
import '../../../../core/localization/app_locale_policy.dart';
import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/localization/locale_providers.dart';
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
    final LocaleController localeController = ref.watch(
      localeControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    if (user == null) {
      return Scaffold(body: Center(child: Text(l10n.commonSignInRequired)));
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
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: switch (state.status) {
        ExploreStatus.initial || ExploreStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        ExploreStatus.error => _StateMessage(
          text: l10n.settingsLoadFailed,
          actionLabel: l10n.commonRetry,
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
            _SettingsSectionTitle(l10n.settingsSectionAccount),
            const SizedBox(height: 8),
            widget.workspaceSectionBuilder?.call(user.id) ??
                ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: Text(l10n.settingsSwitchWorkspace),
                  subtitle: Text(l10n.settingsSwitchWorkspaceHint),
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
              saved: state.message == ExploreController.profileSavedMessage,
            ),
            const Divider(height: 28),
            _SettingsSectionTitle(l10n.settingsSectionContent),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: Text(l10n.settingsSavedPlans),
              subtitle: Text(l10n.settingsSavedPlansHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.favorites),
            ),
            ListTile(
              leading: const Icon(Icons.search_outlined),
              title: Text(l10n.settingsSearch),
              subtitle: Text(l10n.settingsSearchHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.search),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: Text(l10n.navNotifications),
              subtitle: Text(l10n.settingsNotificationsHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.notifications),
            ),
            const Divider(height: 28),
            _SettingsSectionTitle(l10n.settingsSectionPreferences),
            // L4: the device-scoped UI language. It changes text only, never
            // the market, currency, coordinates or event times.
            DropdownButtonFormField<AppLocaleChoice>(
              key: const Key('settings-language'),
              initialValue: localeController.choice,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.languageSectionTitle,
                helperText: l10n.languageHint,
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<AppLocaleChoice>>[
                DropdownMenuItem<AppLocaleChoice>(
                  value: AppLocaleChoice.system,
                  child: Text(l10n.languageSystem),
                ),
                DropdownMenuItem<AppLocaleChoice>(
                  value: AppLocaleChoice.en,
                  child: Text(l10n.languageNameEn),
                ),
                DropdownMenuItem<AppLocaleChoice>(
                  value: AppLocaleChoice.lv,
                  child: Text(l10n.languageNameLv),
                ),
                DropdownMenuItem<AppLocaleChoice>(
                  value: AppLocaleChoice.ru,
                  child: Text(l10n.languageNameRu),
                ),
              ],
              onChanged: (AppLocaleChoice? value) {
                if (value != null) localeController.select(value);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(l10n.settingsNotificationPreferences),
              value: state.settings.notificationsEnabled,
              onChanged: exploreController.updateNotifications,
            ),
            const Divider(height: 28),
            ListTile(
              title: Text(l10n.settingsSupport),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _showLinkDialog(
                context,
                title: l10n.settingsSupport,
                url: LegalLinks.support,
              ),
            ),
            ListTile(
              title: Text(l10n.settingsPrivacyPolicy),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _showLinkDialog(
                context,
                title: l10n.settingsPrivacyPolicy,
                url: LegalLinks.privacyPolicy,
              ),
            ),
            ListTile(
              title: Text(l10n.settingsTerms),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _showLinkDialog(
                context,
                title: l10n.settingsTerms,
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
              child: Text(l10n.settingsSignOut),
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
            child: Text(context.l10n.commonOk),
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
    required this.saved,
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
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.settingsProfileInformation,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _LabeledField(
          label: l10n.settingsDisplayName,
          controller: displayNameController,
          onChanged: onDisplayNameChanged,
        ),
        _LabeledField(
          label: l10n.settingsAbout,
          controller: aboutController,
          onChanged: onAboutChanged,
          maxLines: 4,
        ),
        _LabeledField(
          label: l10n.settingsCity,
          controller: cityController,
          onChanged: onCityChanged,
        ),
        _LabeledField(
          label: l10n.settingsAvatar,
          controller: avatarController,
          onChanged: onAvatarChanged,
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? l10n.settingsSaving : l10n.settingsSaveProfile),
        ),
        if (saved) ...<Widget>[
          const SizedBox(height: 6),
          Text(l10n.settingsProfileSaved),
        ],
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
