class SettingsEntity {
  const SettingsEntity({
    required this.language,
    required this.currency,
    required this.notificationsEnabled,
  });

  final String language;
  final String currency;
  final bool notificationsEnabled;

  SettingsEntity copyWith({
    String? language,
    String? currency,
    bool? notificationsEnabled,
  }) {
    return SettingsEntity(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  factory SettingsEntity.defaults() {
    return const SettingsEntity(
      language: 'ru',
      currency: 'EUR',
      notificationsEnabled: true,
    );
  }
}
