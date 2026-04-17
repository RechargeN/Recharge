import '../../domain/entities/profile_editable_entity.dart';
import '../../domain/entities/settings_entity.dart';

enum ExploreStatus {
  initial,
  loading,
  ready,
  saving,
  error,
}

class ExploreState {
  const ExploreState({
    required this.status,
    required this.userId,
    required this.email,
    required this.currentRole,
    required this.favoritesCount,
    required this.profile,
    required this.settings,
    required this.message,
  });

  factory ExploreState.initial() {
    return ExploreState(
      status: ExploreStatus.initial,
      userId: '',
      email: '',
      currentRole: '',
      favoritesCount: 0,
      profile: ProfileEditableEntity.defaults(email: 'user@example.com'),
      settings: SettingsEntity.defaults(),
      message: null,
    );
  }

  final ExploreStatus status;
  final String userId;
  final String email;
  final String currentRole;
  final int favoritesCount;
  final ProfileEditableEntity profile;
  final SettingsEntity settings;
  final String? message;

  bool get isLoaded => status == ExploreStatus.ready || status == ExploreStatus.saving;

  ExploreState copyWith({
    ExploreStatus? status,
    String? userId,
    String? email,
    String? currentRole,
    int? favoritesCount,
    ProfileEditableEntity? profile,
    SettingsEntity? settings,
    String? message,
    bool clearMessage = false,
  }) {
    return ExploreState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      currentRole: currentRole ?? this.currentRole,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      profile: profile ?? this.profile,
      settings: settings ?? this.settings,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
