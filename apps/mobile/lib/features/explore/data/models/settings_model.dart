import '../../domain/entities/settings_entity.dart';

class SettingsModel {
  const SettingsModel({
    required this.language,
    required this.currency,
    required this.notificationsEnabled,
  });

  final String language;
  final String currency;
  final bool notificationsEnabled;

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      language: json['language'] as String? ?? 'ru',
      currency: json['currency'] as String? ?? 'EUR',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'language': language,
      'currency': currency,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  factory SettingsModel.fromEntity(SettingsEntity entity) {
    return SettingsModel(
      language: entity.language,
      currency: entity.currency,
      notificationsEnabled: entity.notificationsEnabled,
    );
  }

  SettingsEntity toEntity() {
    return SettingsEntity(
      language: language,
      currency: currency,
      notificationsEnabled: notificationsEnabled,
    );
  }
}
