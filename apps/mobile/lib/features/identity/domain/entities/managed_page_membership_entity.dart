enum ManagedPageMembershipStatus { invited, active, suspended, revoked }

enum ManagedPageRelationship { owner, manager, editor }

class ManagedPageMembershipEntity {
  const ManagedPageMembershipEntity({
    required this.pageId,
    required this.userId,
    required this.relationship,
    required this.status,
    required this.capabilities,
    required this.revision,
  });

  final String pageId;
  final String userId;
  final ManagedPageRelationship relationship;
  final ManagedPageMembershipStatus status;
  final Set<String> capabilities;
  final int revision;

  bool get isActive => status == ManagedPageMembershipStatus.active;
  bool get isOwner => relationship == ManagedPageRelationship.owner;

  bool hasCapability(String capability) {
    return capabilities.contains(capability);
  }
}
