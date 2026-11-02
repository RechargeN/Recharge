import '../../domain/entities/settings_entity.dart';

class SettingsModel {
  const SettingsModel({required this.notificationsEnabled});

  final bool notificationsEnabled;

  /// L4.9.4: old records may also hold `language` and `currency`; they read
  /// fine and have no effect.
  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'notificationsEnabled': notificationsEnabled};
  }

  factory SettingsModel.fromEntity(SettingsEntity entity) {
    return SettingsModel(notificationsEnabled: entity.notificationsEnabled);
  }

  SettingsEntity toEntity() {
    return SettingsEntity(notificationsEnabled: notificationsEnabled);
  }
}
