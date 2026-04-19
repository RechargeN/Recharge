import 'package:flutter/foundation.dart';

import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/usecases/load_create_draft_usecase.dart';
import '../../domain/usecases/publish_create_draft_usecase.dart';
import '../../domain/usecases/save_create_draft_usecase.dart';
import '../state/create_state.dart';

class CreateController extends ChangeNotifier {
  CreateController({
    required LoadCreateDraftUseCase loadCreateDraftUseCase,
    required SaveCreateDraftUseCase saveCreateDraftUseCase,
    required PublishCreateDraftUseCase publishCreateDraftUseCase,
    required AnalyticsService analyticsService,
  })  : _loadCreateDraftUseCase = loadCreateDraftUseCase,
        _saveCreateDraftUseCase = saveCreateDraftUseCase,
        _publishCreateDraftUseCase = publishCreateDraftUseCase,
        _analyticsService = analyticsService;

  final LoadCreateDraftUseCase _loadCreateDraftUseCase;
  final SaveCreateDraftUseCase _saveCreateDraftUseCase;
  final PublishCreateDraftUseCase _publishCreateDraftUseCase;
  final AnalyticsService _analyticsService;

  CreateState _state = CreateState.initial();
  CreateState get state => _state;

  String? _loadedUserId;

  Future<void> ensureLoaded({
    required String userId,
    required String organizerEmail,
    required String organizerName,
  }) async {
    if (_loadedUserId == userId && _state.isLoaded) return;
    _loadedUserId = userId;

    _setState(
      _state.copyWith(
        status: CreateStatus.loading,
        clearMessage: true,
        clearValidationErrors: true,
      ),
    );

    final CreateDraftEntity? saved = await _loadCreateDraftUseCase(userId);
    final CreateDraftEntity draft = saved ??
        CreateDraftEntity.defaults(
          organizerId: userId,
          organizerEmail: organizerEmail,
          organizerName: organizerName,
        );

    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        userId: userId,
        draft: draft,
        clearMessage: true,
        clearValidationErrors: true,
      ),
    );
    _analyticsService.track(
      'create_draft_loaded',
      params: <String, Object?>{
        'object_type': draft.objectType.name,
        'user_id': userId,
      },
    );
  }

  void setObjectType(CreateObjectType type) {
    _updateDraft(
      _state.draft.copyWith(
        objectType: type,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateTitle(String value) => _updateDraft(
        _state.draft.copyWith(
          title: value.trim(),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

  void updateMainCategory(String value) => _updateDraft(
        _state.draft.copyWith(
          mainCategory: value.trim(),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

  void updateSubcategory(String value) => _updateDraft(
        _state.draft.copyWith(
          subcategory: value.trim(),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

  void updateShortDescription(String value) => _updateDraft(
        _state.draft.copyWith(
          shortDescription: value.trim(),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

  void updateFullDescription(String value) => _updateDraft(
        _state.draft.copyWith(
          fullDescription: value.trim(),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

  void updateCity(String value) => _updateDraft(
        _state.draft.copyWith(
          city: value.trim(),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

  void updateVenueName(String value) => _updateDraft(
        _state.draft.copyWith(
          venueName: value.trim(),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

  void updateAddress(String value) => _updateDraft(
        _state.draft.copyWith(
          addressLine1: value.trim(),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

  void updateCoverImage(String value) => _updateDraft(
        _state.draft.copyWith(
          media: _state.draft.media.copyWith(coverImage: value.trim()),
          updatedAtUtc: DateTime.now().toUtc(),
        ),
      );

  void addGalleryImage(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final List<String> gallery = <String>[
      ..._state.draft.media.gallery,
      trimmed,
    ];
    _updateDraft(
      _state.draft.copyWith(
        media: _state.draft.media.copyWith(gallery: gallery),
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void removeGalleryImageAt(int index) {
    if (index < 0 || index >= _state.draft.media.gallery.length) return;
    final List<String> gallery = List<String>.from(_state.draft.media.gallery)
      ..removeAt(index);
    _updateDraft(
      _state.draft.copyWith(
        media: _state.draft.media.copyWith(gallery: gallery),
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateIsFree(bool isFree) {
    _updateDraft(
      _state.draft.copyWith(
        isFree: isFree,
        clearBasePrice: isFree,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateBasePrice(String value) {
    final double? parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    _updateDraft(
      _state.draft.copyWith(
        basePrice: parsed,
        clearBasePrice: parsed == null,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateStartDateTime(String value) {
    final DateTime? parsed = DateTime.tryParse(value.trim())?.toUtc();
    _updateDraft(
      _state.draft.copyWith(
        startDateTimeUtc: parsed,
        clearStartDateTimeUtc: parsed == null,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> saveDraft() async {
    if (_state.userId.isEmpty) return;
    _setState(
      _state.copyWith(
        status: CreateStatus.saving,
        clearMessage: true,
      ),
    );
    await _saveCreateDraftUseCase(
      userId: _state.userId,
      draft: _state.draft,
    );
    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        message: 'Черновик сохранен',
      ),
    );
    _analyticsService.track(
      'create_draft_saved',
      params: <String, Object?>{
        'object_type': _state.draft.objectType.name,
      },
    );
  }

  Future<bool> publishDraft() async {
    if (_state.userId.isEmpty) return false;
    final Map<String, String> errors = _validate(_state.draft);
    if (errors.isNotEmpty) {
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          validationErrors: errors,
          message: 'Заполните обязательные поля',
          clearPublishedDraft: true,
        ),
      );
      return false;
    }

    _setState(
      _state.copyWith(
        status: CreateStatus.publishing,
        clearMessage: true,
        clearValidationErrors: true,
      ),
    );

    final CreateDraftEntity published = await _publishCreateDraftUseCase(
      userId: _state.userId,
      draft: _state.draft,
    );

    _setState(
      _state.copyWith(
        status: CreateStatus.publishSuccess,
        draft: published,
        publishedDraft: published,
        message: 'Отправлено на модерацию',
      ),
    );
    _analyticsService.track(
      'create_publish_succeeded',
      params: <String, Object?>{
        'object_type': published.objectType.name,
        'publish_status': published.publishStatus.name,
      },
    );
    return true;
  }

  void resetToFreshDraft({
    required String organizerId,
    required String organizerEmail,
    required String organizerName,
  }) {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: organizerId,
      organizerEmail: organizerEmail,
      organizerName: organizerName,
    );
    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        draft: draft,
        clearMessage: true,
        clearValidationErrors: true,
        clearPublishedDraft: true,
      ),
    );
  }

  Map<String, String> _validate(CreateDraftEntity draft) {
    final Map<String, String> errors = <String, String>{};
    if (draft.title.trim().isEmpty) {
      errors['title'] = 'Введите title';
    }
    if (draft.mainCategory.trim().isEmpty) {
      errors['mainCategory'] = 'Введите category';
    }
    if (draft.city.trim().isEmpty) {
      errors['city'] = 'Введите city';
    }
    if (draft.media.coverImage.trim().isEmpty) {
      errors['coverImage'] = 'Cover image обязательна';
    }
    if (draft.objectType == CreateObjectType.event &&
        draft.startDateTimeUtc == null) {
      errors['startDateTimeUtc'] = 'Для event укажите start datetime';
    }
    return errors;
  }

  void _updateDraft(CreateDraftEntity next) {
    _setState(
      _state.copyWith(
        draft: next,
        clearMessage: true,
        clearValidationErrors: true,
      ),
    );
  }

  void _setState(CreateState state) {
    _state = state;
    notifyListeners();
  }
}
