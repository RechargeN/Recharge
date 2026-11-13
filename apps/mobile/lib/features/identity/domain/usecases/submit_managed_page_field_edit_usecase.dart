import '../entities/identity_access_snapshot.dart';
import '../entities/managed_page_entity.dart';
import '../entities/managed_page_field_moderation_overlay.dart';
import '../entities/managed_page_membership_entity.dart';
import '../repositories/identity_workspace_repository.dart';
import '../repositories/managed_page_field_moderation_repository.dart';

class SubmitManagedPageFieldEditException implements Exception {
  const SubmitManagedPageFieldEditException(this.code);

  final String code;

  @override
  String toString() => 'SubmitManagedPageFieldEditException($code)';
}

/// Submits an edit to one `ManagedPageFieldModerationOverlay` field
/// (`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §4.5, `PP-D48`) per
/// `MANAGED_PAGE_PROFILE_EDITOR_LOCAL_SLICE_SPEC.md` (`PP-01A`).
///
/// Production moderation (a human/queue review step between submission and
/// approval) is out of scope for the bounded local/mock exception, exactly
/// as real Team Invitation acceptance was for `PP-03A`. This use case
/// therefore resolves the submission to `approved` in the same call — a
/// local-only mock, documented and never to be mistaken for how production
/// moderation behaves.
class SubmitManagedPageFieldEditUseCase {
  SubmitManagedPageFieldEditUseCase({
    required IdentityWorkspaceRepository workspaceRepository,
    required ManagedPageFieldModerationRepository moderationRepository,
    DateTime Function()? utcNow,
  }) : _workspaceRepository = workspaceRepository,
       _moderationRepository = moderationRepository,
       _utcNow = utcNow ?? _systemUtcNow;

  static const String pageManageCapability = 'page.manage';
  static const int maxShortTextLength = 160;
  static const int maxLongTextLength = 2000;
  static const int maxActivityLabelLength = 60;

  final IdentityWorkspaceRepository _workspaceRepository;
  final ManagedPageFieldModerationRepository _moderationRepository;
  final DateTime Function() _utcNow;

  /// Pass `value: null` to request a clear (removes the approved value).
  Future<ManagedPageFieldModerationOverlay> call({
    required String actingUserId,
    required ManagedPageEntity page,
    required ManagedPageModeratedFieldKey fieldKey,
    required ManagedPageModeratedFieldValue? value,
    required int basedOnOverlayRevision,
  }) async {
    final String normalizedActor = actingUserId.trim();
    if (normalizedActor.isEmpty) {
      throw const SubmitManagedPageFieldEditException('actor_required');
    }
    if (value != null &&
        !ManagedPageFieldModerationOverlay.accepts(fieldKey, value)) {
      throw const SubmitManagedPageFieldEditException(
        'field_value_type_mismatch',
      );
    }
    if (value != null) {
      _validateValue(fieldKey, value, page);
    }

    final IdentityAccessSnapshot access = await _workspaceRepository
        .loadAccessSnapshot(normalizedActor);
    final ManagedPageMembershipEntity? membership = access.membershipFor(
      page.id,
    );
    if (membership == null || !membership.isActive) {
      throw const SubmitManagedPageFieldEditException(
        'actor_not_active_member',
      );
    }
    if (!membership.hasCapability(pageManageCapability)) {
      throw const SubmitManagedPageFieldEditException(
        'actor_missing_page_manage_capability',
      );
    }

    final List<ManagedPageFieldModerationOverlay> existing =
        await _moderationRepository.loadForPage(page.id);
    final ManagedPageFieldModerationOverlay current =
        existing.cast<ManagedPageFieldModerationOverlay?>().firstWhere(
          (ManagedPageFieldModerationOverlay? item) =>
              item?.fieldKey == fieldKey,
          orElse: () => null,
        ) ??
        ManagedPageFieldModerationOverlay(
          pageId: page.id,
          fieldKey: fieldKey,
          revision: 0,
          schemaVersion: 1,
        );
    if (current.revision != basedOnOverlayRevision) {
      throw const SubmitManagedPageFieldEditException('stale_overlay_revision');
    }

    final DateTime nowUtc = _utcNow().toUtc();
    // Mock auto-approve (PP-01A only): the submission and its approval are
    // one atomic step, so no standalone `pendingSubmission` record is ever
    // persisted. A future real-moderation slice would instead build and
    // save a `ManagedPageFieldPendingSubmission` here (with its own
    // generated id) and resolve it in a separate approve/reject use case,
    // without changing this overlay's stored shape.
    final ManagedPageFieldModerationOverlay resolved =
        ManagedPageFieldModerationOverlay(
          pageId: page.id,
          fieldKey: fieldKey,
          lastApprovedValue: value,
          lastApprovedAtUtc: value == null ? current.lastApprovedAtUtc : nowUtc,
          approvedForVerificationRevision: value == null
              ? current.approvedForVerificationRevision
              : page.verificationRevision,
          pendingSubmission: null,
          latestRejection: null,
          clearedAtUtc: value == null ? nowUtc : null,
          revision: current.revision + 1,
          schemaVersion: 1,
        );
    await _moderationRepository.saveOverlay(resolved);
    return resolved;
  }

  static void _validateValue(
    ManagedPageModeratedFieldKey fieldKey,
    ManagedPageModeratedFieldValue value,
    ManagedPageEntity page,
  ) {
    switch (value) {
      case ManagedPageLocalizedTextValue localized:
        if (localized.valuesByLocale.isEmpty ||
            !localized.valuesByLocale.containsKey(page.defaultLocale)) {
          throw const SubmitManagedPageFieldEditException(
            'default_locale_value_required',
          );
        }
        final int maxLength =
            fieldKey == ManagedPageModeratedFieldKey.description
            ? maxLongTextLength
            : maxShortTextLength;
        for (final MapEntry<String, String> entry
            in localized.valuesByLocale.entries) {
          if (!page.supportedLocales.contains(entry.key)) {
            throw const SubmitManagedPageFieldEditException(
              'unsupported_locale',
            );
          }
          final String trimmed = entry.value.trim();
          if (trimmed.isEmpty || trimmed.length > maxLength) {
            throw const SubmitManagedPageFieldEditException(
              'value_length_out_of_bounds',
            );
          }
        }
      case ManagedPageActivityLabelValue activityLabel:
        final String trimmed = activityLabel.value.trim();
        if (trimmed.isEmpty || trimmed.length > maxActivityLabelLength) {
          throw const SubmitManagedPageFieldEditException(
            'value_length_out_of_bounds',
          );
        }
      case ManagedPageMediaValue media:
        if (media.mediaId.trim().isEmpty) {
          throw const SubmitManagedPageFieldEditException(
            'value_length_out_of_bounds',
          );
        }
      case ManagedPageShortTextValue shortText:
        if (shortText.value.trim().isEmpty ||
            shortText.value.trim().length > maxShortTextLength) {
          throw const SubmitManagedPageFieldEditException(
            'value_length_out_of_bounds',
          );
        }
    }
  }

  static DateTime _systemUtcNow() => DateTime.now().toUtc();
}
