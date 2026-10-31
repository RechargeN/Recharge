enum ProfileRoleTier { user, creator, proGenerator }

class ProfileRoleSummary {
  const ProfileRoleSummary({
    required this.tier,
    required this.titleId,
    required this.subtitleId,
    required this.primaryActionId,
    required this.capabilities,
    required this.canCreate,
    required this.canGenerate,
  });

  final ProfileRoleTier tier;
  // L4.6: stable ids; the profile turns them into text.
  final String titleId;
  final String subtitleId;
  final String primaryActionId;
  final List<String> capabilities;
  final bool canCreate;
  final bool canGenerate;

  bool get isUser => tier == ProfileRoleTier.user;
  bool get isCreator => tier == ProfileRoleTier.creator;
  bool get isProGenerator => tier == ProfileRoleTier.proGenerator;
}

ProfileRoleSummary profileRoleSummaryFor({
  required String? role,
  required List<String>? capabilities,
}) {
  if (role == null || capabilities == null) {
    return profileRoleSummaryForTier(ProfileRoleTier.user);
  }
  final String normalizedRole = role.trim().toLowerCase();
  final Set<String> capabilitySet = capabilities
      .map((String capability) => capability.trim().toLowerCase())
      .where((String capability) => capability.isNotEmpty)
      .toSet();
  final bool isCreatorRole =
      normalizedRole == 'creator' ||
      normalizedRole == 'pro_generator' ||
      normalizedRole == 'pro';
  final bool canCreate = isCreatorRole;
  final bool canGenerate =
      isCreatorRole &&
      (normalizedRole == 'pro_generator' ||
          normalizedRole == 'pro' ||
          capabilitySet.contains('pro.generator') ||
          capabilitySet.contains('scenario.generate') ||
          capabilitySet.contains('route.generate') ||
          capabilitySet.contains('ai.generate.scenarios'));

  if (canGenerate) {
    return profileRoleSummaryForTier(ProfileRoleTier.proGenerator);
  }

  if (canCreate) {
    return profileRoleSummaryForTier(ProfileRoleTier.creator);
  }

  return profileRoleSummaryForTier(ProfileRoleTier.user);
}

ProfileRoleSummary profileRoleSummaryForTier(ProfileRoleTier tier) {
  switch (tier) {
    case ProfileRoleTier.proGenerator:
      return const ProfileRoleSummary(
        tier: ProfileRoleTier.proGenerator,
        titleId: 'pro_generator',
        subtitleId: 'pro_generator',
        primaryActionId: 'open_builder',
        capabilities: <String>[
          'smart_prompts',
          'route_generation',
          'creator_tools',
        ],
        canCreate: true,
        canGenerate: true,
      );
    case ProfileRoleTier.creator:
      return const ProfileRoleSummary(
        tier: ProfileRoleTier.creator,
        titleId: 'creator',
        subtitleId: 'creator',
        primaryActionId: 'open_create_hub',
        capabilities: <String>['drafts', 'moderation', 'organizer_profile'],
        canCreate: true,
        canGenerate: false,
      );
    case ProfileRoleTier.user:
      return const ProfileRoleSummary(
        tier: ProfileRoleTier.user,
        titleId: 'user',
        subtitleId: 'user',
        primaryActionId: 'open_saved',
        capabilities: <String>['discover', 'favorites', 'personal_profile'],
        canCreate: false,
        canGenerate: false,
      );
  }
}

bool profileRoleTierUnlocked({
  required ProfileRoleTier tier,
  required ProfileRoleSummary accessSummary,
}) {
  return switch (tier) {
    ProfileRoleTier.user => true,
    ProfileRoleTier.creator => accessSummary.canCreate,
    ProfileRoleTier.proGenerator => accessSummary.canGenerate,
  };
}

/// The personal surface is presentation, never a verification or mutation grant.
/// Tool hints reuse the current account summary; each operation keeps its guard.
enum ProfilePersonalLayout { personal }

class ProfilePersonalPresentation {
  const ProfilePersonalPresentation({this.accessSummary});

  final ProfileRoleSummary? accessSummary;

  /// The one personal profile title id (glossary term Creator).
  String get titleId => 'creator';
  ProfilePersonalLayout get layout => ProfilePersonalLayout.personal;
  bool get canShowCreatorTools => accessSummary?.canCreate ?? false;
  bool get canShowGeneratorTools => accessSummary?.canGenerate ?? false;
}

/// Legacy compatibility projection; unified Profile uses ProfilePersonalPresentation.
/// A selected/preview tier changes labels/layout only, retaining actual hints.
ProfileRoleSummary profileRoleSummaryForPresentation({
  required ProfileRoleTier tier,
  required ProfileRoleSummary accessSummary,
}) {
  final ProfileRoleSummary presentation = profileRoleSummaryForTier(tier);
  return ProfileRoleSummary(
    tier: presentation.tier,
    titleId: presentation.titleId,
    subtitleId: presentation.subtitleId,
    primaryActionId: presentation.primaryActionId,
    capabilities: accessSummary.capabilities,
    canCreate: accessSummary.canCreate,
    canGenerate: accessSummary.canGenerate,
  );
}
