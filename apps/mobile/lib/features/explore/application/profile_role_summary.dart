enum ProfileRoleTier {
  user,
  creator,
  proGenerator,
}

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
  required String role,
  required List<String> capabilities,
}) {
  final String normalizedRole = role.trim().toLowerCase();
  final Set<String> capabilitySet = capabilities
      .map((String capability) => capability.trim().toLowerCase())
      .where((String capability) => capability.isNotEmpty)
      .toSet();
  final bool canCreate = normalizedRole == 'creator' ||
      normalizedRole == 'pro_generator' ||
      normalizedRole == 'pro' ||
      capabilitySet.any((String capability) => capability.startsWith('create.'));
  final bool canGenerate = normalizedRole == 'pro_generator' ||
      normalizedRole == 'pro' ||
      normalizedRole == 'generator' ||
      capabilitySet.contains('pro.generator') ||
      capabilitySet.contains('scenario.generate') ||
      capabilitySet.contains('route.generate') ||
      capabilitySet.contains('ai.generate.scenarios');

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
