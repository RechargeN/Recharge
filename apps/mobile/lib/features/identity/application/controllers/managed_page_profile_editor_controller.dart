import 'package:flutter/foundation.dart';

import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_field_moderation_overlay.dart';
import '../../domain/repositories/managed_page_field_moderation_repository.dart';
import '../../domain/usecases/submit_managed_page_field_edit_usecase.dart';
import '../state/managed_page_profile_editor_state.dart';

/// Drives the owner/team side of the `PP-01A` profile editor: load this
/// page's field overlays and submit an edit (mock-auto-approved in the same
/// call — see `SubmitManagedPageFieldEditUseCase`).
class ManagedPageProfileEditorController extends ChangeNotifier {
  ManagedPageProfileEditorController({
    required ManagedPageFieldModerationRepository moderationRepository,
    required SubmitManagedPageFieldEditUseCase submitUseCase,
  }) : _moderationRepository = moderationRepository,
       _submitUseCase = submitUseCase;

  final ManagedPageFieldModerationRepository _moderationRepository;
  final SubmitManagedPageFieldEditUseCase _submitUseCase;

  ManagedPageProfileEditorState _state =
      const ManagedPageProfileEditorState.initial();
  ManagedPageProfileEditorState get state => _state;

  int _operationRevision = 0;

  Future<void> ensureLoaded(String pageId) async {
    final String normalized = pageId.trim();
    if (normalized.isEmpty) return;
    if (_state.pageId == normalized &&
        (_state.status == ManagedPageProfileEditorStatusFlag.ready ||
            _state.status == ManagedPageProfileEditorStatusFlag.submitting)) {
      return;
    }
    final int operation = ++_operationRevision;
    _setState(
      _state.copyWith(
        status: ManagedPageProfileEditorStatusFlag.loading,
        pageId: normalized,
        clearMessage: true,
      ),
    );
    try {
      final List<ManagedPageFieldModerationOverlay> overlays =
          await _moderationRepository.loadForPage(normalized);
      if (operation != _operationRevision) return;
      _setState(
        ManagedPageProfileEditorState(
          status: ManagedPageProfileEditorStatusFlag.ready,
          pageId: normalized,
          overlays: overlays,
        ),
      );
    } on Exception {
      if (operation != _operationRevision) return;
      _setState(
        _state.copyWith(
          status: ManagedPageProfileEditorStatusFlag.error,
          message: 'Unable to load the page profile.',
        ),
      );
    }
  }

  /// Pass `value: null` to request a clear.
  Future<bool> submit({
    required String actingUserId,
    required ManagedPageEntity page,
    required ManagedPageModeratedFieldKey fieldKey,
    required ManagedPageModeratedFieldValue? value,
  }) async {
    final int basedOnOverlayRevision =
        _state.overlayFor(fieldKey)?.revision ?? 0;
    final int operation = ++_operationRevision;
    _setState(
      _state.copyWith(
        status: ManagedPageProfileEditorStatusFlag.submitting,
        clearMessage: true,
      ),
    );
    try {
      await _submitUseCase(
        actingUserId: actingUserId,
        page: page,
        fieldKey: fieldKey,
        value: value,
        basedOnOverlayRevision: basedOnOverlayRevision,
      );
      if (operation != _operationRevision) return false;
      final List<ManagedPageFieldModerationOverlay> overlays =
          await _moderationRepository.loadForPage(page.id);
      if (operation != _operationRevision) return false;
      _setState(
        ManagedPageProfileEditorState(
          status: ManagedPageProfileEditorStatusFlag.ready,
          pageId: page.id,
          overlays: overlays,
          message: 'Profile updated.',
        ),
      );
      return true;
    } on SubmitManagedPageFieldEditException catch (error) {
      if (operation != _operationRevision) return false;
      if (error.code == 'stale_overlay_revision') {
        // Refresh so the next attempt carries the current revision.
        final List<ManagedPageFieldModerationOverlay> overlays =
            await _moderationRepository.loadForPage(page.id);
        if (operation != _operationRevision) return false;
        _setState(
          ManagedPageProfileEditorState(
            status: ManagedPageProfileEditorStatusFlag.ready,
            pageId: page.id,
            overlays: overlays,
            message: _errorMessage(error.code),
          ),
        );
        return false;
      }
      _setState(
        _state.copyWith(
          status: ManagedPageProfileEditorStatusFlag.ready,
          message: _errorMessage(error.code),
        ),
      );
      return false;
    } on Exception {
      if (operation != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: ManagedPageProfileEditorStatusFlag.ready,
          message: 'Unable to update the profile.',
        ),
      );
      return false;
    }
  }

  static String _errorMessage(String code) {
    switch (code) {
      case 'default_locale_value_required':
        return 'Enter a value for the page\'s default language.';
      case 'unsupported_locale':
        return 'That language is not supported by this page.';
      case 'value_length_out_of_bounds':
        return 'That text is empty or too long.';
      case 'actor_not_active_member':
        return 'Only an active team member can edit the profile.';
      case 'actor_missing_page_manage_capability':
        return 'You do not have permission to edit the page profile.';
      case 'stale_overlay_revision':
        return 'This field changed elsewhere. Reload and try again.';
      default:
        return 'Unable to update the profile.';
    }
  }

  void _setState(ManagedPageProfileEditorState value) {
    _state = value;
    notifyListeners();
  }
}
