import 'package:flutter/foundation.dart';

import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/profile_editable_entity.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/usecases/load_profile_editable_usecase.dart';
import '../../domain/usecases/load_settings_usecase.dart';
import '../../domain/usecases/save_profile_editable_usecase.dart';
import '../../domain/usecases/save_settings_usecase.dart';
import '../state/explore_state.dart';

class ExploreController extends ChangeNotifier {
  ExploreController({
    required LoadProfileEditableUseCase loadProfileEditableUseCase,
    required SaveProfileEditableUseCase saveProfileEditableUseCase,
    required LoadSettingsUseCase loadSettingsUseCase,
    required SaveSettingsUseCase saveSettingsUseCase,
    required AnalyticsService analyticsService,
  })  : _loadProfileEditableUseCase = loadProfileEditableUseCase,
        _saveProfileEditableUseCase = saveProfileEditableUseCase,
        _loadSettingsUseCase = loadSettingsUseCase,
        _saveSettingsUseCase = saveSettingsUseCase,
        _analyticsService = analyticsService;

  final LoadProfileEditableUseCase _loadProfileEditableUseCase;
  final SaveProfileEditableUseCase _saveProfileEditableUseCase;
  final LoadSettingsUseCase _loadSettingsUseCase;
  final SaveSettingsUseCase _saveSettingsUseCase;
  final AnalyticsService _analyticsService;

  ExploreState _state = ExploreState.initial();
  ExploreState get state => _state;

  String? _loadedUserId;

  Future<void> ensureLoaded({
    required String userId,
    required String email,
    required String role,
    required int favoritesCount,
  }) async {
    if (_loadedUserId == userId && _state.isLoaded) {
      if (_state.favoritesCount != favoritesCount) {
        _setState(_state.copyWith(favoritesCount: favoritesCount));
      }
      return;
    }

    _setState(
      _state.copyWith(
        status: ExploreStatus.loading,
        clearMessage: true,
      ),
    );

    try {
      final ProfileEditableEntity profile = await _loadProfileEditableUseCase(userId) ??
          ProfileEditableEntity.defaults(email: email);
      final SettingsEntity settings =
          await _loadSettingsUseCase(userId) ?? SettingsEntity.defaults();

      _loadedUserId = userId;
      _setState(
        _state.copyWith(
          status: ExploreStatus.ready,
          userId: userId,
          email: email,
          currentRole: role,
          favoritesCount: favoritesCount,
          profile: profile,
          settings: settings,
          clearMessage: true,
        ),
      );
      _analyticsService.track(
        'explore_profile_loaded',
        params: <String, Object?>{
          'user_id': userId,
          'favorites_count': favoritesCount,
        },
      );
    } on Exception {
      _setState(
        _state.copyWith(
          status: ExploreStatus.error,
          message: 'Не удалось загрузить профиль',
        ),
      );
    }
  }

  void updateDisplayName(String value) {
    _setState(
      _state.copyWith(
        profile: _state.profile.copyWith(displayName: value),
      ),
    );
  }

  void updateAbout(String value) {
    _setState(
      _state.copyWith(
        profile: _state.profile.copyWith(about: value),
      ),
    );
  }

  void updateCity(String value) {
    _setState(
      _state.copyWith(
        profile: _state.profile.copyWith(city: value),
      ),
    );
  }

  void updateAvatar(String value) {
    _setState(
      _state.copyWith(
        profile: _state.profile.copyWith(avatar: value),
      ),
    );
  }

  Future<void> saveProfile() async {
    if (_state.userId.isEmpty) return;
    _setState(_state.copyWith(status: ExploreStatus.saving, clearMessage: true));
    await _saveProfileEditableUseCase(
      userId: _state.userId,
      profile: _state.profile,
    );
    _setState(
      _state.copyWith(
        status: ExploreStatus.ready,
        message: 'Профиль сохранен',
      ),
    );
    _analyticsService.track(
      'explore_profile_saved',
      params: <String, Object?>{'user_id': _state.userId},
    );
  }

  Future<void> updateLanguage(String value) async {
    final SettingsEntity next = _state.settings.copyWith(language: value);
    _setState(_state.copyWith(settings: next));
    await _saveSettings(next);
  }

  Future<void> updateCurrency(String value) async {
    final SettingsEntity next = _state.settings.copyWith(currency: value);
    _setState(_state.copyWith(settings: next));
    await _saveSettings(next);
  }

  Future<void> updateNotifications(bool enabled) async {
    final SettingsEntity next =
        _state.settings.copyWith(notificationsEnabled: enabled);
    _setState(_state.copyWith(settings: next));
    await _saveSettings(next);
  }

  Future<void> _saveSettings(SettingsEntity next) async {
    if (_state.userId.isEmpty) return;
    await _saveSettingsUseCase(
      userId: _state.userId,
      settings: next,
    );
    _analyticsService.track(
      'explore_settings_updated',
      params: <String, Object?>{
        'user_id': _state.userId,
        'language': next.language,
        'currency': next.currency,
        'notifications_enabled': next.notificationsEnabled,
      },
    );
  }

  void _setState(ExploreState state) {
    _state = state;
    notifyListeners();
  }
}
