enum ManagedPageKind {
  company,
  organization,
  representativeOffice,
  venueOperator,
  privateProfessional,
}

enum ManagedPageVerificationStatus {
  unverified,
  pending,
  verified,
  rejected,
  revoked,
}

enum ManagedPageLifecycle { draft, pendingReview, active, suspended, archived }

class ManagedPageEntity {
  const ManagedPageEntity({
    required this.id,
    required this.ownerUserId,
    required this.kind,
    required this.displayName,
    this.slug = '',
    required this.avatar,
    required this.verificationStatus,
    required this.lifecycle,
    required this.marketId,
    required this.countryCode,
    required this.defaultLocale,
    required this.timezone,
    required this.defaultCurrency,
    required this.supportedLocales,
    required this.createdAtUtc,
    required this.revision,
    this.verificationRevision = 1,
  });

  final String id;
  final String ownerUserId;
  final ManagedPageKind kind;
  final String displayName;
  final String slug;
  final String avatar;
  final ManagedPageVerificationStatus verificationStatus;
  final ManagedPageLifecycle lifecycle;
  final String marketId;
  final String countryCode;
  final String defaultLocale;
  final String timezone;
  final String defaultCurrency;
  final List<String> supportedLocales;
  final DateTime createdAtUtc;
  final int revision;

  /// Separate from [revision] by design (`PP-D48`): bumped only when
  /// `verificationStatus` transitions, never on an ordinary field edit. A
  /// `ManagedPageFieldModerationOverlay`'s `approvedForVerificationRevision`
  /// must match this exactly, so revoking and re-approving verification
  /// does not silently re-expose a value approved under an earlier
  /// verification. Nothing in the current bounded local/mock runtime moves
  /// `verificationStatus`, so this stays `1` for every page today.
  final int verificationRevision;

  bool get isActive => lifecycle == ManagedPageLifecycle.active;

  bool get isPubliclyVisible =>
      verificationStatus == ManagedPageVerificationStatus.verified &&
      lifecycle == ManagedPageLifecycle.active;

  static String localSlug({
    required String displayName,
    required String pageId,
  }) {
    final String stem = displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final String idSuffix = pageId
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();
    final String suffix = idSuffix.length <= 8
        ? idSuffix
        : idSuffix.substring(idSuffix.length - 8);
    final String safeStem = stem.isEmpty ? 'page' : stem;
    return suffix.isEmpty ? safeStem : '$safeStem-$suffix';
  }
}
