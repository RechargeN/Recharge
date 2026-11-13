import 'managed_page_membership_entity.dart';

enum TeamInvitationTargetType { userId, email, phone }

enum TeamInvitationStatus { pending, revoked, expired }

class TeamInvitationTarget {
  const TeamInvitationTarget({required this.type, required this.value});

  final TeamInvitationTargetType type;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is TeamInvitationTarget &&
      other.type == type &&
      other.value == value;

  @override
  int get hashCode => Object.hash(type, value);
}

/// `TeamInvitation` per `PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` §22.1
/// (`PP-D14`, Accepted core) and `PP-D28` (Accepted security-hardening
/// checklist). This is the pre-acceptance record only — acceptance itself
/// requires the invited person's own authenticated session on their own
/// device and is out of scope for this bounded local/mock slice, exactly
/// like Follow/Contact/Report were deferred in `PPP-01A`.
class TeamInvitationEntity {
  const TeamInvitationEntity({
    required this.id,
    required this.pageId,
    required this.target,
    required this.proposedRelationship,
    required this.proposedCapabilities,
    required this.invitedByUserId,
    required this.sentAtUtc,
    required this.expiresAtUtc,
    required this.status,
    required this.revision,
    this.resendCount = 0,
    this.lastResentAtUtc,
  });

  static const Duration defaultExpiry = Duration(days: 7);
  static const Duration resendCooldown = Duration(hours: 24);

  final String id;
  final String pageId;
  final TeamInvitationTarget target;
  final ManagedPageRelationship proposedRelationship;
  final Set<String> proposedCapabilities;
  final String invitedByUserId;
  final DateTime sentAtUtc;
  final DateTime expiresAtUtc;
  final TeamInvitationStatus status;
  final int resendCount;
  final DateTime? lastResentAtUtc;
  final int revision;

  bool isExpiredAt(DateTime nowUtc) =>
      status == TeamInvitationStatus.pending && !nowUtc.isBefore(expiresAtUtc);

  /// Effective status, folding time-based expiry into the persisted
  /// status without requiring a separate write on every read.
  TeamInvitationStatus effectiveStatusAt(DateTime nowUtc) {
    if (status == TeamInvitationStatus.pending && isExpiredAt(nowUtc)) {
      return TeamInvitationStatus.expired;
    }
    return status;
  }

  TeamInvitationEntity copyWith({
    TeamInvitationStatus? status,
    int? resendCount,
    DateTime? lastResentAtUtc,
    DateTime? expiresAtUtc,
    int? revision,
  }) {
    return TeamInvitationEntity(
      id: id,
      pageId: pageId,
      target: target,
      proposedRelationship: proposedRelationship,
      proposedCapabilities: proposedCapabilities,
      invitedByUserId: invitedByUserId,
      sentAtUtc: sentAtUtc,
      expiresAtUtc: expiresAtUtc ?? this.expiresAtUtc,
      status: status ?? this.status,
      resendCount: resendCount ?? this.resendCount,
      lastResentAtUtc: lastResentAtUtc ?? this.lastResentAtUtc,
      revision: revision ?? this.revision,
    );
  }
}
