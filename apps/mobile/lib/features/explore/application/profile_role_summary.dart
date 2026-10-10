enum ProfileRoleTier { user, creator, proGenerator }

class ProfileRoleSummary {
  const ProfileRoleSummary({
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.capabilities,
    required this.canCreate,
    required this.canGenerate,
  });

  final ProfileRoleTier tier;
  final String title;
  final String subtitle;
  final String primaryActionLabel;
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
        title: 'Pro generator',
        subtitle: 'Build scenarios and routes from intent',
        primaryActionLabel: 'Open Builder',
        capabilities: <String>[
          'Smart scenario prompts',
          'Route and plan generation',
          'Creator publishing tools',
        ],
        canCreate: true,
        canGenerate: true,
      );
    case ProfileRoleTier.creator:
      return const ProfileRoleSummary(
        tier: ProfileRoleTier.creator,
        title: 'Creator',
        subtitle: 'Publish events and places for the community',
        primaryActionLabel: 'Open Create Hub',
        capabilities: <String>[
          'Create event and place drafts',
          'Publish to moderation',
          'Manage organizer profile',
        ],
        canCreate: true,
        canGenerate: false,
      );
    case ProfileRoleTier.user:
      return const ProfileRoleSummary(
        tier: ProfileRoleTier.user,
        title: 'User',
        subtitle: 'Discover, save, and join recharge moments',
        primaryActionLabel: 'Open Saved',
        capabilities: <String>[
          'Discover activities',
          'Save favorites',
          'Manage personal profile',
        ],
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

  String get title => 'Creator';
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
    title: presentation.title,
    subtitle: presentation.subtitle,
    primaryActionLabel: presentation.primaryActionLabel,
    capabilities: accessSummary.capabilities,
    canCreate: accessSummary.canCreate,
    canGenerate: accessSummary.canGenerate,
  );
}
