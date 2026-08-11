import 'managed_page_entity.dart';
import 'managed_page_membership_entity.dart';

enum CreatorVerificationStatus {
  notStarted,
  pending,
  verified,
  rejected,
  expired,
  revoked,
}

class IdentityAccessSnapshot {
  const IdentityAccessSnapshot({
    required this.userId,
    required this.globalRole,
    required this.creatorVerificationStatus,
    required this.globalCapabilities,
    required this.pages,
    required this.memberships,
    required this.revision,
  });

  final String userId;
  final String globalRole;
  final CreatorVerificationStatus creatorVerificationStatus;
  final Set<String> globalCapabilities;
  final List<ManagedPageEntity> pages;
  final List<ManagedPageMembershipEntity> memberships;
  final int revision;

  bool get isVerifiedCreator =>
      creatorVerificationStatus == CreatorVerificationStatus.verified;

  bool hasGlobalCapability(String capability) {
    return globalCapabilities.contains(capability);
  }

  ManagedPageEntity? pageById(String pageId) {
    for (final ManagedPageEntity page in pages) {
      if (page.id == pageId) return page;
    }
    return null;
  }

  ManagedPageMembershipEntity? membershipFor(String pageId) {
    for (final ManagedPageMembershipEntity membership in memberships) {
      if (membership.pageId == pageId && membership.userId == userId) {
        return membership;
      }
    }
    return null;
  }

  bool canActivatePage(String pageId) {
    final ManagedPageEntity? page = pageById(pageId);
    final ManagedPageMembershipEntity? membership = membershipFor(pageId);
    return isVerifiedCreator &&
        page != null &&
        page.isActive &&
        membership != null &&
        membership.isActive;
  }

  List<ManagedPageEntity> get availablePages {
    return pages
        .where((ManagedPageEntity page) => canActivatePage(page.id))
        .toList(growable: false);
  }

  List<ManagedPageEntity> get ownedPages {
    return availablePages
        .where((ManagedPageEntity page) {
          final ManagedPageMembershipEntity? membership = membershipFor(
            page.id,
          );
          return page.ownerUserId == userId && (membership?.isOwner ?? false);
        })
        .toList(growable: false);
  }
}
