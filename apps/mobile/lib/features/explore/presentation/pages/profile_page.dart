import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/entities/auth_user_entity.dart';
import '../../../create/application/create_providers.dart';
import '../../../create/application/create_taxonomy.dart';
import '../../../create/domain/entities/create_draft_entity.dart';
import '../../../discover/application/discover_providers.dart';
import '../../../discover/application/queries/discover_query.dart';
import '../../../discover/application/smart_search_parser.dart';
import '../../../discover/domain/entities/saved_search_entity.dart';
import '../../../discover/domain/entities/smart_search_history_entity.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../../favorites/domain/entities/favorite_item_entity.dart';
import '../../application/controllers/explore_controller.dart';
import '../../application/explore_providers.dart';
import '../../application/profile_role_summary.dart';
import '../../application/state/explore_state.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();

  String? _loadKey;
  String? _createLoadKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesControllerProvider).ensureLoaded();
      ref.read(discoverFeedControllerProvider).ensureSavedSearchesLoaded();
      ref.read(discoverFeedControllerProvider).ensureSmartSearchHistoryLoaded();
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _aboutController.dispose();
    _cityController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).state;
    final favoritesState = ref.watch(favoritesControllerProvider).state;
    final createState = ref.watch(createControllerProvider).state;
    final discoverState = ref.watch(discoverFeedControllerProvider).state;
    final savedSearches = discoverState.savedSearches;
    final smartSearchHistory = discoverState.smartSearchHistory;
    final ExploreController exploreController =
        ref.watch(exploreControllerProvider);
    final ExploreState state = exploreController.state;

    final AuthUserEntity? user = authState.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Требуется авторизация')),
      );
    }

    _scheduleLoad(
      userId: user.id,
      email: user.email,
      role: user.role,
      favoritesCount: favoritesState.items.length,
    );
    _scheduleCreateLoad(user);
    _syncControllers(state);

    final ProfileRoleSummary roleSummary = profileRoleSummaryFor(
      role: user.role,
      capabilities: user.capabilities,
    );
    final _ProfileWorkspaceData workspaceData = _profileWorkspaceDataFor(
      favoritesState.items,
      savedSearches,
      smartSearchHistory,
      createState.publishedDraft,
      createState.draft,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Настройки',
            onPressed: () => context.push(RouteNames.settings),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: switch (state.status) {
        ExploreStatus.initial || ExploreStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        ExploreStatus.error => _StateMessage(
            text: state.message ?? 'Не удалось загрузить профиль',
            actionLabel: 'Повторить',
            onTap: () {
              _loadKey = null;
              _scheduleLoad(
                userId: user.id,
                email: user.email,
                role: user.role,
                favoritesCount: favoritesState.items.length,
                force: true,
              );
            },
          ),
        ExploreStatus.ready || ExploreStatus.saving => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _ProfileHero(
                displayName: state.profile.displayName,
                email: state.email,
                avatar: state.profile.avatar,
                city: state.profile.city,
                roleSummary: roleSummary,
                favoritesCount: workspaceData.savedCount,
                onPrimaryAction: () => _openPrimaryRoleAction(roleSummary),
              ),
              const SizedBox(height: 14),
              _RoleTrack(roleSummary: roleSummary),
              const SizedBox(height: 14),
              _QuickActions(
                roleSummary: roleSummary,
                onFavorites: () => context.go(RouteNames.favorites),
                onCreate: () => context.go(RouteNames.create),
                onScenario: () => context.go(RouteNames.scenarioBuilder),
                onSettings: () => context.push(RouteNames.settings),
              ),
              const SizedBox(height: 14),
              _RoleWorkspace(
                roleSummary: roleSummary,
                data: workspaceData,
                onSaved: () => context.go(RouteNames.favorites),
                onSearch: () => context.go(RouteNames.search),
                onCreate: () => context.go(RouteNames.create),
                onScenario: () => context.go(RouteNames.scenarioBuilder),
                onEditScenario: workspaceData.latestScenario == null
                    ? null
                    : () => _openSavedScenario(workspaceData.latestScenario!),
                onRouteScenario: workspaceData.latestScenario == null
                    ? null
                    : () => _openSavedScenarioMap(
                          workspaceData.latestScenario!,
                        ),
                onResumeSearch: workspaceData.latestSearch == null
                    ? null
                    : () => _openSavedSearch(workspaceData.latestSearch!),
                onMapSearch: workspaceData.latestSearch == null
                    ? null
                    : () => _openSavedSearchMap(workspaceData.latestSearch!),
                onRouteSearch: workspaceData.latestSearch == null
                    ? null
                    : () => _openSavedSearchRoute(workspaceData.latestSearch!),
                onCreateFromSearch: workspaceData.latestSearch == null
                    ? null
                    : () => _openSavedSearchCreate(workspaceData.latestSearch!),
                onResumeSmartSearch: workspaceData.latestSmartSearch == null
                    ? null
                    : () => _openSmartSearch(workspaceData.latestSmartSearch!),
                onMapSmartSearch: workspaceData.latestSmartSearch == null
                    ? null
                    : () => _openSmartSearchMap(
                          workspaceData.latestSmartSearch!,
                        ),
                onRouteSmartSearch: workspaceData.latestSmartSearch == null
                    ? null
                    : () => _openSmartSearchRoute(
                          workspaceData.latestSmartSearch!,
                        ),
                onCreateFromSmartSearch: workspaceData.latestSmartSearch == null
                    ? null
                    : () => _openSmartSearchCreate(
                          workspaceData.latestSmartSearch!,
                        ),
                onOpenListing: (_) => context.go(RouteNames.create),
                onSearchListing: (listing) => context.go(
                  _searchRouteForCreateListing(listing),
                ),
                onMapListing: (listing) => context.go(
                  _mapRouteForCreateListing(listing),
                ),
                onEditListingRoute: (listing) => context.go(
                  listing.routeContext!.builderLocation,
                ),
                onMapListingRoute: (listing) => context.go(
                  listing.routeContext!.mapLocation,
                ),
              ),
              const SizedBox(height: 18),
              _ProfileEditSection(
                displayNameController: _displayNameController,
                aboutController: _aboutController,
                cityController: _cityController,
                avatarController: _avatarController,
                onDisplayNameChanged: exploreController.updateDisplayName,
                onAboutChanged: exploreController.updateAbout,
                onCityChanged: exploreController.updateCity,
                onAvatarChanged: exploreController.updateAvatar,
                onSave: state.status == ExploreStatus.saving
                    ? null
                    : exploreController.saveProfile,
                saving: state.status == ExploreStatus.saving,
              ),
              if (state.message != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  state.message!,
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ],
          ),
      },
    );
  }

  void _openPrimaryRoleAction(ProfileRoleSummary roleSummary) {
    if (roleSummary.isProGenerator) {
      context.go(RouteNames.scenarioBuilder);
      return;
    }
    if (roleSummary.isCreator) {
      context.go(RouteNames.create);
      return;
    }
    context.go(RouteNames.favorites);
  }

  void _openSavedScenario(FavoriteItemEntity scenario) {
    final String? targetRoute = scenario.targetRoute;
    if (targetRoute == null || targetRoute.trim().isEmpty) {
      context.go(RouteNames.scenarioBuilder);
      return;
    }
    context.go(targetRoute);
  }

  void _openSavedScenarioMap(FavoriteItemEntity scenario) {
    context.go(_mapRouteForSavedScenario(scenario));
  }

  void _openSavedSearch(SavedSearchEntity search) {
    context.go(_searchRouteForSavedSearch(search));
  }

  void _openSavedSearchMap(SavedSearchEntity search) {
    context.go(_mapRouteForSavedSearch(search));
  }

  void _openSavedSearchRoute(SavedSearchEntity search) {
    context.go(_scenarioBuilderRouteForSavedSearch(search));
  }

  void _openSavedSearchCreate(SavedSearchEntity search) {
    context.go(_createRouteForSavedSearch(search));
  }

  void _openSmartSearch(SmartSearchHistoryEntity item) {
    context.go(_searchRouteForSmartSearch(item));
  }

  void _openSmartSearchMap(SmartSearchHistoryEntity item) {
    context.go(_mapRouteForSmartSearch(item));
  }

  void _openSmartSearchRoute(SmartSearchHistoryEntity item) {
    context.go(_scenarioBuilderRouteForSmartSearch(item));
  }

  void _openSmartSearchCreate(SmartSearchHistoryEntity item) {
    context.go(_createRouteForSmartSearch(item));
  }

  void _scheduleLoad({
    required String userId,
    required String email,
    required String role,
    required int favoritesCount,
    bool force = false,
  }) {
    final String key = '$userId:$role:$favoritesCount';
    if (!force && _loadKey == key) return;
    _loadKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(exploreControllerProvider).ensureLoaded(
            userId: userId,
            email: email,
            role: role,
            favoritesCount: favoritesCount,
          );
    });
  }

  void _scheduleCreateLoad(AuthUserEntity user) {
    final String key = user.id;
    if (_createLoadKey == key) return;
    _createLoadKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(createControllerProvider).ensureLoaded(
            userId: user.id,
            organizerEmail: user.email,
            organizerName: user.email.split('@').first,
          );
    });
  }

  void _syncControllers(ExploreState state) {
    if (!state.isLoaded) return;
    _syncController(_displayNameController, state.profile.displayName);
    _syncController(_aboutController, state.profile.about);
    _syncController(_cityController, state.profile.city);
    _syncController(_avatarController, state.profile.avatar);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.email,
    required this.avatar,
    required this.city,
    required this.roleSummary,
    required this.favoritesCount,
    required this.onPrimaryAction,
  });

  final String displayName;
  final String email;
  final String avatar;
  final String city;
  final ProfileRoleSummary roleSummary;
  final int favoritesCount;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Avatar(avatar: avatar, displayName: displayName),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              roleSummary.subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _HeroPill(label: roleSummary.title),
                _HeroPill(label: '$favoritesCount saved'),
                if (city.trim().isNotEmpty) _HeroPill(label: city),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: Icon(_primaryIcon(roleSummary)),
              label: Text(roleSummary.primaryActionLabel),
            ),
          ],
        ),
      ),
    );
  }

  IconData _primaryIcon(ProfileRoleSummary roleSummary) {
    if (roleSummary.isProGenerator) return Icons.auto_awesome;
    if (roleSummary.isCreator) return Icons.add_circle;
    return Icons.bookmark;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.avatar,
    required this.displayName,
  });

  final String avatar;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final String trimmedName = displayName.trim();
    final String initials = trimmedName.isEmpty
        ? 'R'
        : trimmedName.substring(0, 1).toUpperCase();
    if (avatar.trim().isEmpty) {
      return CircleAvatar(
        radius: 32,
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
    }
    return CircleAvatar(
      radius: 32,
      backgroundImage: NetworkImage(avatar.trim()),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _RoleTrack extends StatelessWidget {
  const _RoleTrack({
    required this.roleSummary,
  });

  final ProfileRoleSummary roleSummary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Role track',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        _RoleCard(
          title: 'User',
          description: 'Discover, save, and join activities.',
          active: roleSummary.tier == ProfileRoleTier.user,
          unlocked: true,
          icon: Icons.person,
        ),
        const SizedBox(height: 10),
        _RoleCard(
          title: 'Creator',
          description: 'Create events and places for others.',
          active: roleSummary.tier == ProfileRoleTier.creator,
          unlocked: roleSummary.canCreate,
          icon: Icons.edit_calendar,
        ),
        const SizedBox(height: 10),
        _RoleCard(
          title: 'Pro generator',
          description: 'Generate scenarios, routes, and smart plans.',
          active: roleSummary.tier == ProfileRoleTier.proGenerator,
          unlocked: roleSummary.canGenerate,
          icon: Icons.auto_awesome,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.active,
    required this.unlocked,
    required this.icon,
  });

  final String title;
  final String description;
  final bool active;
  final bool unlocked;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? colorScheme.primaryContainer
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(icon, color: active ? colorScheme.primary : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(description),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _RoleStatusBadge(active: active, unlocked: unlocked),
          ],
        ),
      ),
    );
  }
}

class _RoleStatusBadge extends StatelessWidget {
  const _RoleStatusBadge({
    required this.active,
    required this.unlocked,
  });

  final bool active;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String label = active ? 'Active' : (unlocked ? 'Unlocked' : 'Locked');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? colorScheme.primary
            : colorScheme.secondaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active
                    ? colorScheme.onPrimary
                    : colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.roleSummary,
    required this.onFavorites,
    required this.onCreate,
    required this.onScenario,
    required this.onSettings,
  });

  final ProfileRoleSummary roleSummary;
  final VoidCallback onFavorites;
  final VoidCallback onCreate;
  final VoidCallback onScenario;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Role tools',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: <Widget>[
            _ActionTile(
              icon: Icons.bookmark,
              label: 'Saved',
              value: 'Favorites',
              onTap: onFavorites,
            ),
            _ActionTile(
              icon: Icons.add_circle,
              label: 'Create',
              value: roleSummary.canCreate ? 'Enabled' : 'Starter',
              onTap: onCreate,
            ),
            _ActionTile(
              icon: Icons.auto_awesome,
              label: 'Generator',
              value: roleSummary.canGenerate ? 'Enabled' : 'Builder',
              onTap: onScenario,
            ),
            _ActionTile(
              icon: Icons.settings,
              label: 'Settings',
              value: 'Profile',
              onTap: onSettings,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: roleSummary.capabilities
              .map(
                (String capability) => _CapabilityChip(label: capability),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colorScheme.primary),
            const Spacer(),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _RoleWorkspace extends StatelessWidget {
  const _RoleWorkspace({
    required this.roleSummary,
    required this.data,
    required this.onSaved,
    required this.onSearch,
    required this.onCreate,
    required this.onScenario,
    required this.onEditScenario,
    required this.onRouteScenario,
    required this.onResumeSearch,
    required this.onMapSearch,
    required this.onRouteSearch,
    required this.onCreateFromSearch,
    required this.onResumeSmartSearch,
    required this.onMapSmartSearch,
    required this.onRouteSmartSearch,
    required this.onCreateFromSmartSearch,
    required this.onOpenListing,
    required this.onSearchListing,
    required this.onMapListing,
    required this.onEditListingRoute,
    required this.onMapListingRoute,
  });

  final ProfileRoleSummary roleSummary;
  final _ProfileWorkspaceData data;
  final VoidCallback onSaved;
  final VoidCallback onSearch;
  final VoidCallback onCreate;
  final VoidCallback onScenario;
  final VoidCallback? onEditScenario;
  final VoidCallback? onRouteScenario;
  final VoidCallback? onResumeSearch;
  final VoidCallback? onMapSearch;
  final VoidCallback? onRouteSearch;
  final VoidCallback? onCreateFromSearch;
  final VoidCallback? onResumeSmartSearch;
  final VoidCallback? onMapSmartSearch;
  final VoidCallback? onRouteSmartSearch;
  final VoidCallback? onCreateFromSmartSearch;
  final ValueChanged<_CreatorListingData>? onOpenListing;
  final ValueChanged<_CreatorListingData>? onSearchListing;
  final ValueChanged<_CreatorListingData>? onMapListing;
  final ValueChanged<_CreatorListingData>? onEditListingRoute;
  final ValueChanged<_CreatorListingData>? onMapListingRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Workspace',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.08,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: <Widget>[
            _WorkspaceMetric(
              label: 'Saved',
              value: data.savedCount.toString(),
              icon: Icons.bookmark,
            ),
            _WorkspaceMetric(
              label: 'Routes',
              value: data.scenarioCount.toString(),
              icon: Icons.route,
            ),
            _WorkspaceMetric(
              label: 'Searches',
              value: data.searchCount.toString(),
              icon: Icons.tune,
            ),
          ],
        ),
        if (data.latestScenario != null) ...<Widget>[
          const SizedBox(height: 10),
          _LatestScenarioCard(
            scenario: data.latestScenario!,
            onEdit: onEditScenario,
            onRoute: onRouteScenario,
          ),
        ],
        if (data.latestSearch != null) ...<Widget>[
          const SizedBox(height: 10),
          _LatestSearchCard(
            search: data.latestSearch!,
            onResume: onResumeSearch,
            onMap: onMapSearch,
            onRoute: onRouteSearch,
            onCreate: onCreateFromSearch,
          ),
        ],
        if (data.latestSmartSearch != null) ...<Widget>[
          const SizedBox(height: 10),
          _LatestSmartSearchCard(
            item: data.latestSmartSearch!,
            onResume: onResumeSmartSearch,
            onMap: onMapSmartSearch,
            onRoute: onRouteSmartSearch,
            onCreate: onCreateFromSmartSearch,
          ),
        ],
        if ((roleSummary.isCreator || roleSummary.isProGenerator) &&
            data.hasCreatorPublications) ...<Widget>[
          const SizedBox(height: 10),
          _CreatorPublicationsPanel(
            data: data,
            onCreate: onCreate,
            onScenario: onScenario,
            onOpenListing: onOpenListing,
            onSearchListing: onSearchListing,
            onMapListing: onMapListing,
            onEditListingRoute: onEditListingRoute,
            onMapListingRoute: onMapListingRoute,
          ),
          const SizedBox(height: 10),
          _CreatorNextStepsPanel(
            roleSummary: roleSummary,
            data: data,
            onScenario: onScenario,
            onOpenListing: onOpenListing,
            onSearchListing: onSearchListing,
            onMapListing: onMapListing,
            onEditListingRoute: onEditListingRoute,
            onMapListingRoute: onMapListingRoute,
          ),
        ],
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: _workspaceActions(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _workspaceActions() {
    if (roleSummary.isProGenerator) {
      return <Widget>[
        _WorkspaceActionRow(
          icon: Icons.auto_awesome,
          title: 'Generate scenario',
          subtitle: 'Open Builder with route controls',
          onTap: onScenario,
        ),
        _WorkspaceDivider(),
        _WorkspaceActionRow(
          icon: Icons.psychology,
          title: 'Smart prompt',
          subtitle: data.latestSmartSearch == null
              ? '${data.searchCount} search continuations'
              : data.latestSmartSearch!.prompt,
          onTap: onSearch,
        ),
        _WorkspaceDivider(),
        _WorkspaceActionRow(
          icon: Icons.add_circle,
          title: 'Publish idea',
          subtitle: 'Move from route idea to Create Hub',
          onTap: onCreate,
        ),
      ];
    }
    if (roleSummary.isCreator) {
      return <Widget>[
        _WorkspaceActionRow(
          icon: Icons.add_circle,
          title: 'Create Hub',
          subtitle: 'Draft event or place from taxonomy',
          onTap: onCreate,
        ),
        _WorkspaceDivider(),
        _WorkspaceActionRow(
          icon: Icons.route,
          title: 'Build route idea',
          subtitle: 'Use saved searches and scenarios as inspiration',
          onTap: onScenario,
        ),
        _WorkspaceDivider(),
        _WorkspaceActionRow(
          icon: Icons.favorite,
          title: 'Review saved plan',
          subtitle: '${data.activityCount} activities, ${data.scenarioCount} routes',
          onTap: onSaved,
        ),
      ];
    }
    return <Widget>[
      _WorkspaceActionRow(
        icon: Icons.favorite,
        title: 'Saved plan',
        subtitle: '${data.savedCount} saved ideas ready',
        onTap: onSaved,
      ),
      _WorkspaceDivider(),
      _WorkspaceActionRow(
        icon: Icons.search,
        title: 'Find next activity',
        subtitle: data.latestSmartSearch != null
            ? 'Resume ${data.latestSmartSearch!.prompt}'
            : data.latestSearch == null
                ? 'Use Search and Map conditions'
                : 'Resume ${data.latestSearch!.title}',
        onTap: onSearch,
      ),
      _WorkspaceDivider(),
      _WorkspaceActionRow(
        icon: Icons.route,
        title: 'Build a route',
        subtitle: 'Create a personal recharge scenario',
        onTap: onScenario,
      ),
    ];
  }
}

class _WorkspaceMetric extends StatelessWidget {
  const _WorkspaceMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colorScheme.primary, size: 20),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestScenarioCard extends StatelessWidget {
  const _LatestScenarioCard({
    required this.scenario,
    required this.onEdit,
    required this.onRoute,
  });

  final FavoriteItemEntity scenario;
  final VoidCallback? onEdit;
  final VoidCallback? onRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.route, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Latest route',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _WorkspacePill(label: 'Scenario'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              scenario.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              scenario.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_location_alt),
                    label: const Text('Edit route'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRoute,
                    icon: const Icon(Icons.map),
                    label: const Text('Map route'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestSearchCard extends StatelessWidget {
  const _LatestSearchCard({
    required this.search,
    required this.onResume,
    required this.onMap,
    required this.onRoute,
    required this.onCreate,
  });

  final SavedSearchEntity search;
  final VoidCallback? onResume;
  final VoidCallback? onMap;
  final VoidCallback? onRoute;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.tune, color: colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Latest search',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _WorkspacePill(label: 'Conditions'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              search.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              search.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _WorkspacePill(
                  label: search.query.selectedCategoryIds.isEmpty
                      ? 'All'
                      : search.query.selectedCategoryIds.first,
                ),
                _WorkspacePill(
                  label: search.query.unlimitedRadius
                      ? 'Any area'
                      : '${(search.query.radiusMeters / 1000).round()} km',
                ),
                if (search.query.freeOnly) _WorkspacePill(label: 'Free'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.search),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Resume search'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Map search'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Build route from latest search',
                  onPressed: onRoute,
                  icon: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Create listing from latest search',
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestSmartSearchCard extends StatelessWidget {
  const _LatestSmartSearchCard({
    required this.item,
    required this.onResume,
    required this.onMap,
    required this.onRoute,
    required this.onCreate,
  });

  final SmartSearchHistoryEntity item;
  final VoidCallback? onResume;
  final VoidCallback? onMap;
  final VoidCallback? onRoute;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final SmartRouteIntent? routeIntent =
        parseSmartSearch(item.prompt).routeIntent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_awesome, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Latest smart search',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _WorkspacePill(label: 'Smart'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _WorkspacePill(
                  label: item.query.selectedCategoryIds.isEmpty
                      ? 'All'
                      : item.query.selectedCategoryIds.first,
                ),
                if (routeIntent != null) ...<Widget>[
                  const _WorkspacePill(label: 'Smart route'),
                  _WorkspacePill(label: '${routeIntent.durationMinutes} min'),
                  _WorkspacePill(
                    label: '${routeIntent.stepCategories.length} stops',
                  ),
                ],
                _WorkspacePill(
                  label: item.query.unlimitedRadius
                      ? 'Any area'
                      : '${(item.query.radiusMeters / 1000).round()} km',
                ),
                if (item.query.budgetMax != null)
                  _WorkspacePill(
                    label: 'Under ${item.query.budgetMax!.toStringAsFixed(0)}',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Resume smart'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Map smart'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Build route from latest smart search',
                  onPressed: onRoute,
                  icon: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Create listing from latest smart search',
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorPublicationsPanel extends StatelessWidget {
  const _CreatorPublicationsPanel({
    required this.data,
    required this.onCreate,
    required this.onScenario,
    required this.onOpenListing,
    required this.onSearchListing,
    required this.onMapListing,
    required this.onEditListingRoute,
    required this.onMapListingRoute,
  });

  final _ProfileWorkspaceData data;
  final VoidCallback onCreate;
  final VoidCallback onScenario;
  final ValueChanged<_CreatorListingData>? onOpenListing;
  final ValueChanged<_CreatorListingData>? onSearchListing;
  final ValueChanged<_CreatorListingData>? onMapListing;
  final ValueChanged<_CreatorListingData>? onEditListingRoute;
  final ValueChanged<_CreatorListingData>? onMapListingRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.dashboard_customize, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Creator publications',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            _WorkspacePill(
              label: '${data.creatorPublicationCount} active',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Manage drafts and published listings from the same workspace.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        if (data.draftListing != null) ...<Widget>[
          const SizedBox(height: 10),
          _CreatorPublicationCard(
            listing: data.draftListing!,
            onOpen: onOpenListing == null
                ? null
                : () => onOpenListing!(data.draftListing!),
            onSearch: onSearchListing == null
                ? null
                : () => onSearchListing!(data.draftListing!),
            onMap: onMapListing == null
                ? null
                : () => onMapListing!(data.draftListing!),
            onEditRoute:
                data.draftListing!.routeContext == null ||
                        onEditListingRoute == null
                    ? null
                    : () => onEditListingRoute!(data.draftListing!),
            onMapRoute:
                data.draftListing!.routeContext == null ||
                        onMapListingRoute == null
                    ? null
                    : () => onMapListingRoute!(data.draftListing!),
          ),
        ],
        if (data.publishedListing != null) ...<Widget>[
          const SizedBox(height: 10),
          _CreatorPublicationCard(
            listing: data.publishedListing!,
            onOpen: onOpenListing == null
                ? null
                : () => onOpenListing!(data.publishedListing!),
            onSearch: onSearchListing == null
                ? null
                : () => onSearchListing!(data.publishedListing!),
            onMap: onMapListing == null
                ? null
                : () => onMapListing!(data.publishedListing!),
            onEditRoute:
                data.publishedListing!.routeContext == null ||
                        onEditListingRoute == null
                    ? null
                    : () => onEditListingRoute!(data.publishedListing!),
            onMapRoute:
                data.publishedListing!.routeContext == null ||
                        onMapListingRoute == null
                    ? null
                    : () => onMapListingRoute!(data.publishedListing!),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_circle_outline),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('New listing'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onScenario,
                icon: const Icon(Icons.route_outlined),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Build route'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CreatorPublicationCard extends StatelessWidget {
  const _CreatorPublicationCard({
    required this.listing,
    required this.onOpen,
    required this.onSearch,
    required this.onMap,
    required this.onEditRoute,
    required this.onMapRoute,
  });

  final _CreatorListingData listing;
  final VoidCallback? onOpen;
  final VoidCallback? onSearch;
  final VoidCallback? onMap;
  final VoidCallback? onEditRoute;
  final VoidCallback? onMapRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  listing.isPublished
                      ? Icons.verified_outlined
                      : Icons.edit_note,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Creator listing',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                _WorkspacePill(label: listing.stageLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              listing.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              listing.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _WorkspacePill(label: listing.statusLabel),
                _WorkspacePill(label: listing.categoryLabel),
                if (listing.subcategory.isNotEmpty)
                  _WorkspacePill(label: listing.subcategory),
                _WorkspacePill(label: listing.city),
                _WorkspacePill(label: listing.priceLabel),
                _WorkspacePill(label: listing.readinessLabel),
              ],
            ),
            if (listing.missingFields.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Missing: ${listing.missingFields.join(', ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.edit_note),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        listing.isPublished ? 'Open Create' : 'Continue draft',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Search similar listing',
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Map listing area',
                  onPressed: onMap,
                  icon: const Icon(Icons.map_outlined),
                ),
              ],
            ),
            if (listing.routeContext != null) ...<Widget>[
              const SizedBox(height: 12),
              Divider(color: colorScheme.outline.withValues(alpha: 0.18)),
              const SizedBox(height: 8),
              _CreatorPublishedRouteSummary(
                routeContext: listing.routeContext!,
                onEditRoute: onEditRoute,
                onMapRoute: onMapRoute,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreatorNextStepsPanel extends StatelessWidget {
  const _CreatorNextStepsPanel({
    required this.roleSummary,
    required this.data,
    required this.onScenario,
    required this.onOpenListing,
    required this.onSearchListing,
    required this.onMapListing,
    required this.onEditListingRoute,
    required this.onMapListingRoute,
  });

  final ProfileRoleSummary roleSummary;
  final _ProfileWorkspaceData data;
  final VoidCallback onScenario;
  final ValueChanged<_CreatorListingData>? onOpenListing;
  final ValueChanged<_CreatorListingData>? onSearchListing;
  final ValueChanged<_CreatorListingData>? onMapListing;
  final ValueChanged<_CreatorListingData>? onEditListingRoute;
  final ValueChanged<_CreatorListingData>? onMapListingRoute;

  @override
  Widget build(BuildContext context) {
    final List<_CreatorNextStepData> steps = _steps();
    if (steps.isEmpty) return const SizedBox.shrink();

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.lightbulb_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Creator next steps',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                _WorkspacePill(label: '${steps.length} actions'),
              ],
            ),
            const SizedBox(height: 8),
            for (int index = 0; index < steps.length; index++) ...<Widget>[
              if (index > 0) _WorkspaceDivider(),
              _CreatorNextStepRow(step: steps[index]),
            ],
          ],
        ),
      ),
    );
  }

  List<_CreatorNextStepData> _steps() {
    final List<_CreatorNextStepData> steps = <_CreatorNextStepData>[];
    final _CreatorListingData? draft = data.draftListing;
    final _CreatorListingData? published = data.publishedListing;

    if (draft != null && onOpenListing != null) {
      if (draft.missingFields.isNotEmpty) {
        steps.add(
          _CreatorNextStepData(
            icon: Icons.fact_check_outlined,
            title: 'Finish draft',
            subtitle: 'Missing: ${draft.missingFields.join(', ')}',
            onTap: () => onOpenListing!(draft),
          ),
        );
      } else if (onSearchListing != null) {
        steps.add(
          _CreatorNextStepData(
            icon: Icons.campaign_outlined,
            title: 'Find draft audience',
            subtitle: 'Open Search with ${draft.title}',
            onTap: () => onSearchListing!(draft),
          ),
        );
      }
    }

    if (published != null) {
      final _PublishedRouteListingContext? routeContext =
          published.routeContext;
      if (routeContext != null && onMapListingRoute != null) {
        steps.add(
          _CreatorNextStepData(
            icon: Icons.route_outlined,
            title: 'Open route map',
            subtitle:
                '${published.title} · ${routeContext.stepCategories.length} stops',
            onTap: () => onMapListingRoute!(published),
          ),
        );
      } else if (onMapListing != null) {
        steps.add(
          _CreatorNextStepData(
            icon: Icons.map_outlined,
            title: 'Map published listing',
            subtitle: '${published.categoryLabel} · ${published.city}',
            onTap: () => onMapListing!(published),
          ),
        );
      }
    }

    if (roleSummary.isProGenerator) {
      steps.add(
        _CreatorNextStepData(
          icon: Icons.auto_awesome,
          title: 'Build next route',
          subtitle: 'Open Scenario Builder for the next generated idea',
          onTap: onScenario,
        ),
      );
    }

    return steps.take(3).toList(growable: false);
  }
}

class _CreatorNextStepData {
  const _CreatorNextStepData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _CreatorNextStepRow extends StatelessWidget {
  const _CreatorNextStepRow({
    required this.step,
  });

  final _CreatorNextStepData step;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: step.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: <Widget>[
            Icon(step.icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _CreatorPublishedRouteSummary extends StatelessWidget {
  const _CreatorPublishedRouteSummary({
    required this.routeContext,
    required this.onEditRoute,
    required this.onMapRoute,
  });

  final _PublishedRouteListingContext routeContext;
  final VoidCallback? onEditRoute;
  final VoidCallback? onMapRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.route, color: colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Published route',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            _WorkspacePill(label: '${routeContext.stepCategories.length} stops'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          routeContext.prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _WorkspacePill(label: routeContext.mood),
            _WorkspacePill(label: '${routeContext.durationMinutes} min'),
            if (routeContext.isFree) const _WorkspacePill(label: 'Free'),
            const _WorkspacePill(label: 'Walking'),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: routeContext.stepCategories
              .map(
                (String step) => _WorkspacePill(
                  label: createTaxonomyLabelForPath(step),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: onEditRoute,
                icon: const Icon(Icons.edit_location_alt),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Edit route'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onMapRoute,
                icon: const Icon(Icons.map_outlined),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Route map'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkspaceActionRow extends StatelessWidget {
  const _WorkspaceActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _WorkspacePill extends StatelessWidget {
  const _WorkspacePill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _WorkspaceDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.14),
    );
  }
}

class _ProfileEditSection extends StatelessWidget {
  const _ProfileEditSection({
    required this.displayNameController,
    required this.aboutController,
    required this.cityController,
    required this.avatarController,
    required this.onDisplayNameChanged,
    required this.onAboutChanged,
    required this.onCityChanged,
    required this.onAvatarChanged,
    required this.onSave,
    required this.saving,
  });

  final TextEditingController displayNameController;
  final TextEditingController aboutController;
  final TextEditingController cityController;
  final TextEditingController avatarController;
  final ValueChanged<String> onDisplayNameChanged;
  final ValueChanged<String> onAboutChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onAvatarChanged;
  final Future<void> Function()? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Edit profile',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Display name',
          controller: displayNameController,
          onChanged: onDisplayNameChanged,
        ),
        _LabeledField(
          label: 'About',
          controller: aboutController,
          onChanged: onAboutChanged,
          maxLines: 4,
        ),
        _LabeledField(
          label: 'City',
          controller: cityController,
          onChanged: onCityChanged,
        ),
        _LabeledField(
          label: 'Avatar URL/Path',
          controller: avatarController,
          onChanged: onAvatarChanged,
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save),
          label: Text(saving ? 'Сохраняем...' : 'Сохранить профиль'),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        minLines: maxLines > 1 ? 2 : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(text),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onTap,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileWorkspaceData {
  const _ProfileWorkspaceData({
    required this.savedCount,
    required this.scenarioCount,
    required this.searchCount,
    required this.activityCount,
    required this.freeCount,
    required this.latestScenario,
    required this.latestSearch,
    required this.latestSmartSearch,
    required this.draftListing,
    required this.publishedListing,
  });

  final int savedCount;
  final int scenarioCount;
  final int searchCount;
  final int activityCount;
  final int freeCount;
  final FavoriteItemEntity? latestScenario;
  final SavedSearchEntity? latestSearch;
  final SmartSearchHistoryEntity? latestSmartSearch;
  final _CreatorListingData? draftListing;
  final _CreatorListingData? publishedListing;

  bool get hasCreatorPublications =>
      draftListing != null || publishedListing != null;

  int get creatorPublicationCount {
    return (draftListing == null ? 0 : 1) +
        (publishedListing == null ? 0 : 1);
  }
}

class _CreatorListingData {
  const _CreatorListingData({
    required this.draft,
    required this.stageLabel,
    required this.isPublished,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.categoryLabel,
    required this.subcategory,
    required this.city,
    required this.priceLabel,
    required this.readinessLabel,
    required this.missingFields,
    required this.routeContext,
  });

  final CreateDraftEntity draft;
  final String stageLabel;
  final bool isPublished;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String categoryLabel;
  final String subcategory;
  final String city;
  final String priceLabel;
  final String readinessLabel;
  final List<String> missingFields;
  final _PublishedRouteListingContext? routeContext;
}

_ProfileWorkspaceData _profileWorkspaceDataFor(
  List<FavoriteItemEntity> items,
  List<SavedSearchEntity> savedSearches,
  List<SmartSearchHistoryEntity> smartSearchHistory,
  CreateDraftEntity? publishedDraft,
  CreateDraftEntity currentDraft,
) {
  FavoriteItemEntity? latestScenario;
  SavedSearchEntity? latestSearch;
  SmartSearchHistoryEntity? latestSmartSearch;
  int scenarioCount = 0;
  int freeCount = 0;

  for (final FavoriteItemEntity item in items) {
    if (item.isFree) freeCount += 1;
    if (item.category != 'scenario') continue;
    scenarioCount += 1;
    if (latestScenario == null ||
        item.savedAtUtc.isAfter(latestScenario.savedAtUtc)) {
      latestScenario = item;
    }
  }

  for (final SavedSearchEntity search in savedSearches) {
    if (latestSearch == null ||
        search.createdAtUtc.isAfter(latestSearch.createdAtUtc)) {
      latestSearch = search;
    }
  }

  for (final SmartSearchHistoryEntity item in smartSearchHistory) {
    if (latestSmartSearch == null ||
        item.createdAtUtc.isAfter(latestSmartSearch.createdAtUtc)) {
      latestSmartSearch = item;
    }
  }

  final _CreatorListingData? publishedListing = publishedDraft == null
      ? null
      : _creatorListingDataFor(
          publishedDraft,
          stageLabel: 'Published',
          statusLabel: publishedDraft.publishStatus.name,
          isPublished: true,
        );
  final bool currentMatchesPublished = publishedDraft != null &&
      _sameListingContent(currentDraft, publishedDraft);
  final _CreatorListingData? draftListing = currentMatchesPublished
      ? null
      : _creatorListingDataFor(
          currentDraft,
          stageLabel: 'Draft',
          statusLabel: currentDraft.draftStatus.name,
          isPublished: false,
        );

  return _ProfileWorkspaceData(
    savedCount: items.length + savedSearches.length + smartSearchHistory.length,
    scenarioCount: scenarioCount,
    searchCount: savedSearches.length + smartSearchHistory.length,
    activityCount: items.length - scenarioCount,
    freeCount: freeCount,
    latestScenario: latestScenario,
    latestSearch: latestSearch,
    latestSmartSearch: latestSmartSearch,
    draftListing: draftListing,
    publishedListing: publishedListing,
  );
}

_CreatorListingData? _creatorListingDataFor(
  CreateDraftEntity draft, {
  required String stageLabel,
  required String statusLabel,
  required bool isPublished,
}) {
  final bool hasContent = draft.title.trim().isNotEmpty ||
      draft.mainCategory.trim().isNotEmpty ||
      draft.media.coverImage.trim().isNotEmpty;
  if (!hasContent) return null;
  final CreateTaxonomyCategory? category =
      createTaxonomyCategoryById(draft.mainCategory);
  final List<String> missingFields = _missingPublishFields(draft);
  return _CreatorListingData(
    draft: draft,
    stageLabel: stageLabel,
    isPublished: isPublished,
    title: draft.title.trim().isEmpty ? 'Untitled listing' : draft.title,
    subtitle: draft.shortDescription.trim().isEmpty
        ? _listingVenueLabel(draft)
        : draft.shortDescription,
    statusLabel: statusLabel,
    categoryLabel: category?.title ?? draft.mainCategory,
    subcategory: draft.subcategory.trim().isEmpty
        ? ''
        : createTaxonomyLabelForPath(
            '${draft.mainCategory}.${draft.subcategory}',
          ),
    city: draft.city.trim().isEmpty ? 'No city' : draft.city,
    priceLabel: draft.isFree
        ? 'Free'
        : '${draft.basePrice?.toStringAsFixed(0) ?? '0'} ${draft.currency}',
    readinessLabel: missingFields.isEmpty
        ? (isPublished ? 'Published-ready' : 'Ready to publish')
        : '${missingFields.length} missing',
    missingFields: missingFields,
    routeContext: _PublishedRouteListingContext.fromDraft(draft),
  );
}

bool _sameListingContent(CreateDraftEntity left, CreateDraftEntity right) {
  return left.title == right.title &&
      left.mainCategory == right.mainCategory &&
      left.subcategory == right.subcategory &&
      left.shortDescription == right.shortDescription &&
      left.fullDescription == right.fullDescription &&
      left.city == right.city &&
      left.venueName == right.venueName &&
      left.media.coverImage == right.media.coverImage &&
      left.isFree == right.isFree &&
      left.basePrice == right.basePrice &&
      left.startDateTimeUtc == right.startDateTimeUtc;
}

List<String> _missingPublishFields(CreateDraftEntity draft) {
  return <String>[
    if (draft.title.trim().isEmpty) 'title',
    if (draft.mainCategory.trim().isEmpty) 'category',
    if (draft.city.trim().isEmpty) 'city',
    if (draft.media.coverImage.trim().isEmpty) 'cover',
    if (draft.objectType == CreateObjectType.event &&
        draft.startDateTimeUtc == null)
      'start time',
  ];
}

class _PublishedRouteListingContext {
  const _PublishedRouteListingContext({
    required this.prompt,
    required this.mood,
    required this.durationMinutes,
    required this.isFree,
    required this.stepCategories,
  });

  static _PublishedRouteListingContext? fromDraft(CreateDraftEntity draft) {
    if (draft.mainCategory != 'travel_tours' ||
        draft.subcategory != 'walking_tour') {
      return null;
    }
    final List<String> steps = _routeStepsFromPublishedDraft(draft);
    if (steps.isEmpty) return null;
    return _PublishedRouteListingContext(
      prompt: draft.title.trim().isEmpty ? 'Published route' : draft.title,
      mood: _scenarioMoodForDraft(draft),
      durationMinutes: _scenarioDurationForDraft(draft),
      isFree: draft.isFree,
      stepCategories: steps,
    );
  }

  final String prompt;
  final String mood;
  final int durationMinutes;
  final bool isFree;
  final List<String> stepCategories;

  String get builderLocation {
    return Uri(
      path: RouteNames.scenarioBuilder,
      queryParameters: _routeParameters(includeMode: false),
    ).toString();
  }

  String get mapLocation {
    return Uri(
      path: RouteNames.discoverMap,
      queryParameters: _routeParameters(includeMode: true),
    ).toString();
  }

  Map<String, String> _routeParameters({required bool includeMode}) {
    return <String, String>{
      if (includeMode) 'mode': 'scenario',
      'mood': mood,
      'duration': durationMinutes.toString(),
      'free': isFree ? '1' : '0',
      'walking': '1',
      'prompt': prompt,
      'steps': stepCategories.join(','),
    };
  }
}

String _mapRouteForSavedScenario(FavoriteItemEntity scenario) {
  final String? targetRoute = scenario.targetRoute;
  if (targetRoute == null || targetRoute.trim().isEmpty) {
    return RouteNames.discoverMap;
  }

  final Uri targetUri = Uri.parse(targetRoute);
  final Map<String, String> params =
      Map<String, String>.from(targetUri.queryParameters);
  final String? steps = params['steps'];
  if (steps == null || steps.trim().isEmpty) {
    return RouteNames.discoverMap;
  }
  params['mode'] = 'scenario';
  return Uri(
    path: RouteNames.discoverMap,
    queryParameters: params,
  ).toString();
}

List<String> _routeStepsFromPublishedDraft(CreateDraftEntity draft) {
  final String marker = 'Route steps: ';
  final int markerIndex = draft.fullDescription.indexOf(marker);
  if (markerIndex >= 0) {
    final int start = markerIndex + marker.length;
    final int end = draft.fullDescription.indexOf('. Review', start);
    final String rawSteps = end > start
        ? draft.fullDescription.substring(start, end)
        : draft.fullDescription.substring(start);
    final List<String> steps = rawSteps
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (steps.isNotEmpty) return steps;
  }
  return const <String>['wellness_recharge.calm_walk'];
}

String _scenarioMoodForDraft(CreateDraftEntity draft) {
  final String value =
      '${draft.title} ${draft.shortDescription} ${draft.fullDescription}'
          .toLowerCase();
  if (value.contains('active') ||
      value.contains('sport') ||
      value.contains('tennis')) {
    return 'active';
  }
  if (value.contains('social') || value.contains('evening')) {
    return 'social';
  }
  return 'calm';
}

int _scenarioDurationForDraft(CreateDraftEntity draft) {
  if (draft.durationMinutes != null && draft.durationMinutes! > 0) {
    return draft.durationMinutes!;
  }
  final RegExpMatch? match =
      RegExp(r'(\d+)\s*min').firstMatch(draft.shortDescription);
  if (match == null) return 90;
  return int.tryParse(match.group(1) ?? '') ?? 90;
}

String _searchRouteForSavedSearch(SavedSearchEntity search) {
  return _discoverRouteForSavedSearch(RouteNames.search, search.query);
}

String _mapRouteForSavedSearch(SavedSearchEntity search) {
  return _discoverRouteForSavedSearch(RouteNames.discoverMap, search.query);
}

String _searchRouteForSmartSearch(SmartSearchHistoryEntity item) {
  return _discoverRouteForSavedSearch(RouteNames.search, item.query);
}

String _mapRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult =
      _smartRouteParseForSmartSearch(item);
  if (parseResult != null) {
    return Uri(
      path: RouteNames.discoverMap,
      queryParameters: _smartRouteParameters(
        parseResult,
        includeMode: true,
      ),
    ).toString();
  }
  return _discoverRouteForSavedSearch(RouteNames.discoverMap, item.query);
}

String _searchRouteForCreateListing(_CreatorListingData listing) {
  return _discoverRouteForCreateListing(RouteNames.search, listing.draft);
}

String _mapRouteForCreateListing(_CreatorListingData listing) {
  return _discoverRouteForCreateListing(RouteNames.discoverMap, listing.draft);
}

String _discoverRouteForCreateListing(String path, CreateDraftEntity draft) {
  return Uri(
    path: path,
    queryParameters: <String, String>{
      'q': draft.title.trim(),
      'category': _discoverCategoryForCreateListing(draft.mainCategory),
      'free': draft.isFree ? '1' : '0',
      if (!draft.isFree && draft.basePrice != null)
        'budgetMax': draft.basePrice!.toStringAsFixed(0),
      'radius': '5000',
      'unlimited': '0',
    },
  ).toString();
}

String _discoverCategoryForCreateListing(String category) {
  switch (category) {
    case 'art_culture_museums':
      return 'art';
    case 'outdoor_nature_walking':
    case 'travel_tours':
      return 'outdoor';
    case 'wellness_recharge':
      return 'wellness';
    case 'food_drinks':
      return 'food';
    case 'family_kids':
      return 'family';
    default:
      return category;
  }
}

String _createRouteForSavedSearch(SavedSearchEntity search) {
  final Map<String, String> params = <String, String>{
    ..._queryParametersForSavedSearch(search.query),
    'source': 'saved_search',
    'type': 'event',
    'title': search.title,
    'subtitle': search.subtitle,
  };
  return Uri(
    path: RouteNames.create,
    queryParameters: params,
  ).toString();
}

String _createRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult =
      _smartRouteParseForSmartSearch(item);
  if (parseResult != null) {
    final SmartRouteIntent routeIntent = parseResult.routeIntent!;
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._smartRouteParameters(parseResult, includeMode: false),
        'source': 'scenario',
        'type': 'event',
        'title': '${_capitalized(routeIntent.mood)} recharge route',
        'subtitle': '${routeIntent.stepCategories.length} stops · '
            '${routeIntent.durationMinutes} min · smart route',
        'q': parseResult.originalText.trim(),
        'category': 'scenario',
      },
    ).toString();
  }
  final Map<String, String> params = <String, String>{
    ..._queryParametersForSavedSearch(item.query),
    'source': 'smart_search',
    'type': 'event',
    'title': _titleForSmartSearch(item.query),
    'subtitle': item.prompt,
  };
  return Uri(
    path: RouteNames.create,
    queryParameters: params,
  ).toString();
}

String _discoverRouteForSavedSearch(String path, DiscoverQuery query) {
  return Uri(
    path: path,
    queryParameters: _queryParametersForSavedSearch(query),
  ).toString();
}

Map<String, String> _queryParametersForSavedSearch(DiscoverQuery query) {
  return <String, String>{
    'q': query.queryText.trim(),
    'category': query.selectedCategoryIds.join(','),
    'free': query.freeOnly ? '1' : '0',
    if (query.budgetMax != null)
      'budgetMax': query.budgetMax!.toStringAsFixed(0),
    if (query.dateFrom != null) 'dateFrom': query.dateFrom!.toIso8601String(),
    if (query.dateTo != null) 'dateTo': query.dateTo!.toIso8601String(),
    'radius': query.radiusMeters.round().toString(),
    'unlimited': query.unlimitedRadius ? '1' : '0',
  };
}

String _scenarioBuilderRouteForSavedSearch(SavedSearchEntity search) {
  final DiscoverQuery query = search.query;
  final String prompt = _promptForSavedSearch(query);
  return _scenarioBuilderRouteForQuery(query, prompt: prompt);
}

String _scenarioBuilderRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult =
      _smartRouteParseForSmartSearch(item);
  if (parseResult != null) {
    return Uri(
      path: RouteNames.scenarioBuilder,
      queryParameters: _smartRouteParameters(
        parseResult,
        includeMode: false,
      ),
    ).toString();
  }
  final String prompt = item.prompt.trim().isEmpty
      ? _promptForSavedSearch(item.query)
      : item.prompt.trim();
  return _scenarioBuilderRouteForQuery(item.query, prompt: prompt);
}

SmartSearchParseResult? _smartRouteParseForSmartSearch(
  SmartSearchHistoryEntity item,
) {
  final SmartSearchParseResult parseResult = parseSmartSearch(item.prompt);
  if (parseResult.routeIntent == null) return null;
  return parseResult;
}

Map<String, String> _smartRouteParameters(
  SmartSearchParseResult parseResult, {
  required bool includeMode,
}) {
  final SmartRouteIntent routeIntent = parseResult.routeIntent!;
  return <String, String>{
    if (includeMode) 'mode': 'scenario',
    'mood': routeIntent.mood,
    'duration': routeIntent.durationMinutes.toString(),
    'free': routeIntent.freeOnly ? '1' : '0',
    'walking': routeIntent.walkingOnly ? '1' : '0',
    if (parseResult.originalText.trim().isNotEmpty)
      'prompt': parseResult.originalText.trim(),
    if (routeIntent.stepCategories.isNotEmpty)
      'steps': routeIntent.stepCategories.join(','),
  };
}

String _scenarioBuilderRouteForQuery(
  DiscoverQuery query, {
  required String prompt,
}) {
  final Map<String, String> params = <String, String>{
    'mood': _scenarioMoodForSavedSearch(query),
    'duration': query.radiusMeters <= 5000 ? '120' : '180',
    'walking': query.unlimitedRadius ? '0' : '1',
    if (query.freeOnly) 'free': '1',
    if (prompt.isNotEmpty) 'prompt': prompt,
  };
  return Uri(
    path: RouteNames.scenarioBuilder,
    queryParameters: params,
  ).toString();
}

String _titleForSmartSearch(DiscoverQuery query) {
  final String queryText = query.queryText.trim();
  if (queryText.isNotEmpty) {
    return queryText[0].toUpperCase() + queryText.substring(1);
  }
  if (query.selectedCategoryIds.isNotEmpty) {
    return '${query.selectedCategoryIds.first} idea';
  }
  return 'Smart search idea';
}

String _capitalized(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

String _scenarioMoodForSavedSearch(DiscoverQuery query) {
  final String queryText = query.queryText.toLowerCase();
  if (queryText.contains('run') ||
      queryText.contains('sport') ||
      queryText.contains('tennis') ||
      query.selectedCategoryIds.contains('outdoor')) {
    return 'active';
  }
  if (query.selectedCategoryIds.any(
    (String category) {
      return category == 'art' || category == 'music' || category == 'family';
    },
  )) {
    return 'social';
  }
  return 'calm';
}

String _promptForSavedSearch(DiscoverQuery query) {
  final List<String> parts = <String>[
    if (query.queryText.trim().isNotEmpty) query.queryText.trim(),
    if (query.selectedCategoryIds.isNotEmpty) query.selectedCategoryIds.first,
    if (query.freeOnly) 'free',
    if (query.budgetMax != null)
      'under ${query.budgetMax!.toStringAsFixed(0)}',
    query.unlimitedRadius
        ? 'any area'
        : 'near ${(query.radiusMeters / 1000).round()} km',
  ];
  return parts.join(' · ');
}

String _listingVenueLabel(CreateDraftEntity draft) {
  if (draft.venueName.isNotEmpty && draft.city.isNotEmpty) {
    return '${draft.venueName} · ${draft.city}';
  }
  if (draft.venueName.isNotEmpty) return draft.venueName;
  return draft.city.isEmpty ? 'Draft listing' : draft.city;
}
