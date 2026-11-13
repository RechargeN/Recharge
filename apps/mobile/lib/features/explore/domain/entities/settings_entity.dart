/// L4.9.4: the old `language` and `currency` settings are gone. The UI language
/// belongs to `LocaleController`; a currency always comes from the data.
class SettingsEntity {
  const SettingsEntity({required this.notificationsEnabled});

  final bool notificationsEnabled;

  SettingsEntity copyWith({bool? notificationsEnabled}) {
    return SettingsEntity(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  factory SettingsEntity.defaults() {
    return const SettingsEntity(notificationsEnabled: true);
  }
}
