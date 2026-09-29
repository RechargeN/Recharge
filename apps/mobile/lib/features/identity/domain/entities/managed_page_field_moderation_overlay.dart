enum ManagedPageModeratedFieldKey {
  displayName,
  shortDescription,
  description,
  customActivityLabel,
  avatarMediaRef,
  coverMediaRef,
}

sealed class ManagedPageModeratedFieldValue {
  const ManagedPageModeratedFieldValue();
}

class ManagedPageLocalizedTextValue extends ManagedPageModeratedFieldValue {
  const ManagedPageLocalizedTextValue(this.valuesByLocale);

  final Map<String, String> valuesByLocale;
}

class ManagedPageShortTextValue extends ManagedPageModeratedFieldValue {
  const ManagedPageShortTextValue(this.value);

  final String value;
}

class ManagedPageMediaValue extends ManagedPageModeratedFieldValue {
  const ManagedPageMediaValue(this.mediaId);

  final String mediaId;
}

class ManagedPageActivityLabelValue extends ManagedPageModeratedFieldValue {
  const ManagedPageActivityLabelValue(this.value);

  final String value;
}

class ManagedPageFieldPendingSubmission {
  const ManagedPageFieldPendingSubmission({
    required this.submissionId,
    required this.value,
    required this.clearRequested,
    required this.submittedAtUtc,
    required this.basedOnOverlayRevision,
  }) : assert(clearRequested ? value == null : value != null);

  final String submissionId;
  final ManagedPageModeratedFieldValue? value;
  final bool clearRequested;
  final DateTime submittedAtUtc;
  final int basedOnOverlayRevision;
}

class ManagedPageFieldRejection {
  const ManagedPageFieldRejection({
    required this.submissionId,
    required this.rejectedValue,
    required this.rejectedAtUtc,
    required this.rejectionReasonCode,
  });

  final String submissionId;
  final ManagedPageModeratedFieldValue? rejectedValue;
  final DateTime rejectedAtUtc;
  final String rejectionReasonCode;
}

class ManagedPageFieldModerationOverlay {
  const ManagedPageFieldModerationOverlay({
    required this.pageId,
    required this.fieldKey,
    required this.revision,
    required this.schemaVersion,
    this.lastApprovedValue,
    this.lastApprovedAtUtc,
    this.approvedForVerificationRevision,
    this.pendingSubmission,
    this.latestRejection,
    this.clearedAtUtc,
  });

  final String pageId;
  final ManagedPageModeratedFieldKey fieldKey;
  final ManagedPageModeratedFieldValue? lastApprovedValue;
  final DateTime? lastApprovedAtUtc;
  final int? approvedForVerificationRevision;
  final ManagedPageFieldPendingSubmission? pendingSubmission;
  final ManagedPageFieldRejection? latestRejection;
  final DateTime? clearedAtUtc;
  final int revision;
  final int schemaVersion;

  ManagedPageModeratedFieldValue? effectiveValue({
    required int currentVerificationRevision,
  }) {
    if (clearedAtUtc != null ||
        approvedForVerificationRevision != currentVerificationRevision) {
      return null;
    }
    final ManagedPageModeratedFieldValue? value = lastApprovedValue;
    return value != null && accepts(fieldKey, value) ? value : null;
  }

  static bool accepts(
    ManagedPageModeratedFieldKey key,
    ManagedPageModeratedFieldValue value,
  ) {
    return switch (key) {
      ManagedPageModeratedFieldKey.displayName ||
      ManagedPageModeratedFieldKey.shortDescription ||
      ManagedPageModeratedFieldKey.description =>
        value is ManagedPageLocalizedTextValue,
      ManagedPageModeratedFieldKey.customActivityLabel =>
        value is ManagedPageActivityLabelValue,
      ManagedPageModeratedFieldKey.avatarMediaRef ||
      ManagedPageModeratedFieldKey.coverMediaRef =>
        value is ManagedPageMediaValue,
    };
  }
}
