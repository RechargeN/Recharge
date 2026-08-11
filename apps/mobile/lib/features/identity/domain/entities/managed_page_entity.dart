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
  });

  final String id;
  final String ownerUserId;
  final ManagedPageKind kind;
  final String displayName;
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

  bool get isActive => lifecycle == ManagedPageLifecycle.active;
}
