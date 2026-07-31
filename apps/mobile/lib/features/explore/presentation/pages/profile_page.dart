import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../../../app/application/visit_history_facade.dart';
import '../../../../app/application/visit_history_providers.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../../../core/identity/account_experience.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/entities/auth_user_entity.dart';
import '../../../create/application/create_providers.dart';
import '../../../create/application/create_taxonomy.dart';
import '../../../create/domain/entities/create_draft_entity.dart';
import '../../../discover/application/discover_providers.dart';
import '../../../discover/domain/entities/discover_query.dart';
import '../../../discover/application/smart_search_parser.dart';
import '../../../discover/domain/entities/saved_search_entity.dart';
import '../../../discover/domain/entities/smart_search_history_entity.dart';
import '../../../favorites/application/favorites_providers.dart';
import '../../../favorites/domain/entities/favorite_item_entity.dart';
import '../../application/controllers/explore_controller.dart';
import '../../application/explore_providers.dart';
import '../../application/profile_role_summary.dart';
import '../../application/state/explore_state.dart';

enum _ProfileDashboardSection { page, created, visited }

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String? _loadKey;
  String? _createLoadKey;
  String? _visitedLoadKey;
  _ProfileDashboardSection? _selectedDashboardSection;

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
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).state;
    final favoritesState = ref.watch(favoritesControllerProvider).state;
    final createState = ref.watch(createControllerProvider).state;
    final discoverState = ref.watch(discoverFeedControllerProvider).state;
    final savedSearches = discoverState.savedSearches;
    final smartSearchHistory = discoverState.smartSearchHistory;
    final ExploreController exploreController = ref.watch(
      exploreControllerProvider,
    );
    final ExploreState state = exploreController.state;

    final AuthUserEntity? user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Требуется авторизация')));
    }

    _scheduleLoad(
      userId: user.id,
      email: user.email,
      role: user.role,
      favoritesCount: favoritesState.items.length,
    );
    _scheduleCreateLoad(user);
    final ProfileRoleSummary accessRoleSummary = profileRoleSummaryFor(
      role: user.role,
      capabilities: user.capabilities,
    );
    final ProfileRoleSummary roleSummary = _profilePresentationSummary(
      context,
      accessRoleSummary,
    );
    final _ProfileDashboardSection dashboardSection =
        _selectedDashboardSection ??
        (roleSummary.isProGenerator
            ? _ProfileDashboardSection.page
            : roleSummary.isCreator
            ? _ProfileDashboardSection.created
            : _ProfileDashboardSection.visited);
    final VisitHistorySummary? visitedState = roleSummary.isUser
        ? ref.watch(visitHistorySummaryProvider)
        : null;
    if (roleSummary.isUser) {
      _scheduleVisitedLoad(user.id);
    }
    final _ProfileWorkspaceData workspaceData = _profileWorkspaceDataFor(
      favoritesState.items,
      savedSearches,
      smartSearchHistory,
      createState.publishedDraft,
      createState.draft,
    );

    return Scaffold(
      backgroundColor: RechargeTheme.profileBackground,
      appBar: AppBar(
        title: Text(_profilePageTitle(roleSummary)),
        backgroundColor: RechargeTheme.profileBackground,
        foregroundColor: RechargeTheme.ink,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Настройки',
              onPressed: () => context.push(RouteNames.settings),
              icon: const Icon(Icons.settings_outlined),
            ),
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
            ),
            const SizedBox(height: 14),
            _ProfileDashboardTabs(
              roleSummary: roleSummary,
              selectedSection: dashboardSection,
              onPage: () =>
                  _selectDashboardSection(_ProfileDashboardSection.page),
              onCreated: () =>
                  _selectDashboardSection(_ProfileDashboardSection.created),
              onVisited: () => context.push(RouteNames.visitedPlaces),
              onInsights: () => context.push(RouteNames.profileWorkspace),
              onPhotos: () => context.push(RouteNames.settings),
            ),
            const SizedBox(height: 14),
            if (roleSummary.isUser)
              _ViewerProfileBody(
                state: visitedState!,
                onOpenVisit: (VisitHistoryItem item) => context.push(
                  '${RouteNames.discoverDetails}/${item.placeId}',
                ),
                onViewAllVisits: () => context.push(RouteNames.visitedPlaces),
                onSavedList: () => context.push(RouteNames.favorites),
                onUpgrade: () => context.push(RouteNames.settings),
              )
            else if (roleSummary.isCreator ||
                dashboardSection == _ProfileDashboardSection.created)
              _LatestCreatedEvents(
                data: workspaceData,
                onViewAll: () =>
                    _selectDashboardSection(_ProfileDashboardSection.created),
                onOpenListing: (listing) =>
                    context.push(_searchRouteForCreateListing(listing)),
                onCreate: () => context.push(RouteNames.create),
                onCreateRoute: () => context.push(
                  Uri(
                    path: RouteNames.create,
                    queryParameters: const <String, String>{'type': 'route'},
                  ).toString(),
                ),
                onScenario: () => context.push(RouteNames.scenarioBuilder),
                onFindPeople: () => context.push(RouteNames.search),
              )
            else
              _ProGeneratorProfileBody(
                displayName: state.profile.displayName,
                city: state.profile.city,
                avatar: state.profile.avatar,
                data: workspaceData,
                onManagePage: () =>
                    _selectDashboardSection(_ProfileDashboardSection.page),
                onCreatedEvents: () =>
                    _selectDashboardSection(_ProfileDashboardSection.created),
                onInsights: () => context.push(RouteNames.profileWorkspace),
                onBookings: () => context.push(RouteNames.notifications),
              ),
            if (state.message != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(state.message!, style: const TextStyle(color: Colors.green)),
            ],
          ],
        ),
      },
    );
  }

  void _selectDashboardSection(_ProfileDashboardSection section) {
    if (_selectedDashboardSection == section) return;
    setState(() => _selectedDashboardSection = section);
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
      ref
          .read(exploreControllerProvider)
          .ensureLoaded(
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
      ref
          .read(createControllerProvider)
          .ensureLoaded(
            userId: user.id,
            organizerEmail: user.email,
            organizerName: user.email.split('@').first,
          );
    });
  }

  void _scheduleVisitedLoad(String userId) {
    if (_visitedLoadKey == userId) return;
    _visitedLoadKey = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(visitHistoryFacadeProvider).ensureLoaded(userId: userId);
    });
  }
}

ProfileRoleSummary _profilePresentationSummary(
  BuildContext context,
  ProfileRoleSummary accessSummary,
) {
  final AccountExperienceScope? scope = AccountExperienceScope.maybeOf(context);
  if (scope == null) return accessSummary;
  return switch (scope.experience) {
    AccountExperience.viewer => profileRoleSummaryForTier(ProfileRoleTier.user),
    AccountExperience.creator => profileRoleSummaryForTier(
      ProfileRoleTier.creator,
    ),
    AccountExperience.professionalPage => profileRoleSummaryForTier(
      ProfileRoleTier.creator,
    ),
  };
}

String _profilePageTitle(ProfileRoleSummary roleSummary) {
  if (roleSummary.isProGenerator) return 'Pro generator profile';
  if (roleSummary.isCreator) return 'Community creator profile';
  return 'Viewer profile';
}

String _profileBadgeLabel(ProfileRoleSummary roleSummary) {
  if (roleSummary.isProGenerator) return 'PRO GENERATOR';
  if (roleSummary.isCreator) return 'CREATOR LIGHT';
  return 'VIEWER';
}

String _profileContextLine(ProfileRoleSummary roleSummary, String city) {
  final String location = city.trim().isEmpty ? 'Riga' : city.trim();
  final String contextLabel = roleSummary.isProGenerator
      ? 'Organizer'
      : roleSummary.isCreator
      ? 'Community'
      : 'Explorer';
  return '$contextLabel · $location';
}

class ProfileWorkspacePage extends ConsumerStatefulWidget {
  const ProfileWorkspacePage({super.key});

  @override
  ConsumerState<ProfileWorkspacePage> createState() =>
      _ProfileWorkspacePageState();
}

class _ProfileWorkspacePageState extends ConsumerState<ProfileWorkspacePage> {
  String? _createLoadKey;
  ProfileRoleTier? _selectedRoleTier;

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
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).state;
    final favoritesState = ref.watch(favoritesControllerProvider).state;
    final createState = ref.watch(createControllerProvider).state;
    final discoverState = ref.watch(discoverFeedControllerProvider).state;
    final AuthUserEntity? user = authState.user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Требуется авторизация')));
    }

    _scheduleCreateLoad(user);
    final ProfileRoleSummary accessRoleSummary = profileRoleSummaryFor(
      role: user.role,
      capabilities: user.capabilities,
    );
    final AccountExperienceScope? experienceScope =
        AccountExperienceScope.maybeOf(context);
    final ProfileRoleTier activeRoleTier = _activeRoleTierFor(
      selectedTier: _selectedRoleTier,
      accessSummary: accessRoleSummary,
    );
    final ProfileRoleSummary roleSummary = experienceScope == null
        ? profileRoleSummaryForTier(activeRoleTier)
        : _profilePresentationSummary(context, accessRoleSummary);
    final _ProfileWorkspaceData workspaceData = _profileWorkspaceDataFor(
      favoritesState.items,
      discoverState.savedSearches,
      discoverState.smartSearchHistory,
      createState.publishedDraft,
      createState.draft,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        title: const Text('Profile workspace'),
        backgroundColor: const Color(0xFFF4F6F2),
        foregroundColor: const Color(0xFF10231F),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          if (experienceScope == null) ...<Widget>[
            _RoleTrack(
              activeTier: activeRoleTier,
              accessSummary: accessRoleSummary,
              onRoleSelected: _selectRoleTier,
            ),
            const SizedBox(height: 14),
          ],
          _RoleWorkspace(
            roleSummary: roleSummary,
            data: workspaceData,
            onSaved: () => context.push(RouteNames.favorites),
            onSearch: () => context.push(RouteNames.search),
            onCreate: () => context.push(RouteNames.create),
            onScenario: () => context.push(RouteNames.scenarioBuilder),
            onEditScenario: workspaceData.latestScenario == null
                ? null
                : () => _openSavedScenario(workspaceData.latestScenario!),
            onRouteScenario: workspaceData.latestScenario == null
                ? null
                : () => _openSavedScenarioMap(workspaceData.latestScenario!),
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
                : () => _openSmartSearchMap(workspaceData.latestSmartSearch!),
            onRouteSmartSearch: workspaceData.latestSmartSearch == null
                ? null
                : () => _openSmartSearchRoute(workspaceData.latestSmartSearch!),
            onCreateFromSmartSearch: workspaceData.latestSmartSearch == null
                ? null
                : () =>
                      _openSmartSearchCreate(workspaceData.latestSmartSearch!),
            onOpenListing: (_) => context.push(RouteNames.create),
            onSearchListing: (listing) =>
                context.push(_searchRouteForCreateListing(listing)),
            onMapListing: (listing) =>
                context.push(_mapRouteForCreateListing(listing)),
            onEditListingRoute: (listing) =>
                context.push(listing.routeContext!.builderLocation),
            onMapListingRoute: (listing) =>
                context.push(listing.routeContext!.mapLocation),
          ),
        ],
      ),
    );
  }

  ProfileRoleTier _activeRoleTierFor({
    required ProfileRoleTier? selectedTier,
    required ProfileRoleSummary accessSummary,
  }) {
    if (selectedTier != null &&
        profileRoleTierUnlocked(
          tier: selectedTier,
          accessSummary: accessSummary,
        )) {
      return selectedTier;
    }
    return accessSummary.tier;
  }

  void _selectRoleTier(ProfileRoleTier tier) {
    setState(() {
      _selectedRoleTier = tier;
    });
  }

  void _openSavedScenario(FavoriteItemEntity scenario) {
    final String? targetRoute = scenario.targetRoute;
    if (targetRoute == null || targetRoute.trim().isEmpty) {
      context.push(RouteNames.scenarioBuilder);
      return;
    }
    context.push(targetRoute);
  }

  void _openSavedScenarioMap(FavoriteItemEntity scenario) {
    context.push(_mapRouteForSavedScenario(scenario));
  }

  void _openSavedSearch(SavedSearchEntity search) {
    context.push(_searchRouteForSavedSearch(search));
  }

  void _openSavedSearchMap(SavedSearchEntity search) {
    context.push(_mapRouteForSavedSearch(search));
  }

  void _openSavedSearchRoute(SavedSearchEntity search) {
    context.push(_scenarioBuilderRouteForSavedSearch(search));
  }

  void _openSavedSearchCreate(SavedSearchEntity search) {
    context.push(_createRouteForSavedSearch(search));
  }

  void _openSmartSearch(SmartSearchHistoryEntity item) {
    context.push(_searchRouteForSmartSearch(item));
  }

  void _openSmartSearchMap(SmartSearchHistoryEntity item) {
    context.push(_mapRouteForSmartSearch(item));
  }

  void _openSmartSearchRoute(SmartSearchHistoryEntity item) {
    context.push(_scenarioBuilderRouteForSmartSearch(item));
  }

  void _openSmartSearchCreate(SmartSearchHistoryEntity item) {
    context.push(_createRouteForSmartSearch(item));
  }

  void _scheduleCreateLoad(AuthUserEntity user) {
    final String key = user.id;
    if (_createLoadKey == key) return;
    _createLoadKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(createControllerProvider)
          .ensureLoaded(
            userId: user.id,
            organizerEmail: user.email,
            organizerName: user.email.split('@').first,
          );
    });
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.email,
    required this.avatar,
    required this.city,
    required this.roleSummary,
  });

  final String displayName;
  final String email;
  final String avatar;
  final String city;
  final ProfileRoleSummary roleSummary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.profileSurface,
        borderRadius: BorderRadius.circular(RechargeTheme.profileCardRadius),
        border: Border.all(color: RechargeTheme.profileBorder),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12003F32),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF0B3028),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${email.split('@').first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6C7A73),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.place_outlined,
                        size: 15,
                        color: Color(0xFF0B3028),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _profileContextLine(roleSummary, city),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF0B3028),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _HeroPill(label: _profileBadgeLabel(roleSummary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDashboardTabs extends StatelessWidget {
  const _ProfileDashboardTabs({
    required this.roleSummary,
    required this.selectedSection,
    required this.onPage,
    required this.onCreated,
    required this.onVisited,
    required this.onInsights,
    required this.onPhotos,
  });

  final ProfileRoleSummary roleSummary;
  final _ProfileDashboardSection selectedSection;
  final VoidCallback onPage;
  final VoidCallback onCreated;
  final VoidCallback onVisited;
  final VoidCallback onInsights;
  final VoidCallback onPhotos;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(RechargeTheme.profileCompactRadius),
        border: Border.all(color: RechargeTheme.profileBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: roleSummary.isProGenerator
              ? <Widget>[
                  _ProfileDashboardTab(
                    icon: Icons.storefront_outlined,
                    label: 'Page',
                    active: selectedSection == _ProfileDashboardSection.page,
                    onTap: onPage,
                  ),
                  _ProfileDashboardTab(
                    icon: Icons.work_outline,
                    label: 'Created',
                    active: selectedSection == _ProfileDashboardSection.created,
                    onTap: onCreated,
                  ),
                  _ProfileDashboardTab(
                    icon: Icons.insights_outlined,
                    label: 'Insights',
                    active: false,
                    onTap: onInsights,
                  ),
                  _ProfileDashboardTab(
                    icon: Icons.image_outlined,
                    label: 'Photos',
                    active: false,
                    onTap: onPhotos,
                  ),
                ]
              : <Widget>[
                  if (roleSummary.isCreator)
                    _ProfileDashboardTab(
                      icon: Icons.work_outline,
                      label: 'Created',
                      active:
                          selectedSection == _ProfileDashboardSection.created,
                      onTap: onCreated,
                    ),
                  _ProfileDashboardTab(
                    icon: Icons.place_outlined,
                    label: 'Visited',
                    active: roleSummary.isUser,
                    onTap: onVisited,
                  ),
                  _ProfileDashboardTab(
                    icon: Icons.image_outlined,
                    label: 'Photos',
                    active: false,
                    onTap: onPhotos,
                  ),
                ],
        ),
      ),
    );
  }
}

class _ProfileDashboardTab extends StatelessWidget {
  const _ProfileDashboardTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: active ? const Color(0xFF0B3028) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: active ? Colors.white : const Color(0xFF0B3028),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF0B3028),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerProfileBody extends StatelessWidget {
  const _ViewerProfileBody({
    required this.state,
    required this.onOpenVisit,
    required this.onViewAllVisits,
    required this.onSavedList,
    required this.onUpgrade,
  });

  final VisitHistorySummary state;
  final ValueChanged<VisitHistoryItem> onOpenVisit;
  final VoidCallback onViewAllVisits;
  final VoidCallback onSavedList;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final List<VisitHistoryItem> visits = state.items
        .take(3)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _ProfileSectionLabel('VISITED PLACES'),
        const SizedBox(height: 8),
        _ProfileSurfacePanel(
          child: switch (state.status) {
            VisitHistoryLoadStatus.initial ||
            VisitHistoryLoadStatus.loading => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            VisitHistoryLoadStatus.error => _ProfileActionRow(
              icon: Icons.refresh,
              title: 'Could not load visits',
              subtitle: 'Open visit history to try again',
              onTap: onViewAllVisits,
            ),
            VisitHistoryLoadStatus.ready when visits.isEmpty =>
              _ProfileActionRow(
                icon: Icons.place_outlined,
                title: 'No visits yet',
                subtitle: 'Places you visit will appear here',
                onTap: onViewAllVisits,
              ),
            VisitHistoryLoadStatus.ready => Column(
              children: <Widget>[
                for (final VisitHistoryItem visit in visits)
                  _VisitedProfileRow(
                    item: visit,
                    onTap: () => onOpenVisit(visit),
                  ),
                if (state.items.length > visits.length)
                  ListTile(
                    dense: true,
                    title: const Center(
                      child: Text(
                        'View all visits',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: onViewAllVisits,
                  ),
              ],
            ),
          },
        ),
        const SizedBox(height: 14),
        const _ProfileSectionLabel('ACTIONS'),
        const SizedBox(height: 8),
        _ProfileSurfacePanel(
          child: Column(
            children: <Widget>[
              _ProfileActionRow(
                icon: Icons.bookmark_border,
                title: 'Saved list',
                onTap: onSavedList,
              ),
              _ViewerUpgradeRow(onTap: onUpgrade),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisitedProfileRow extends StatelessWidget {
  const _VisitedProfileRow({required this.item, required this.onTap});

  final VisitHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String visitedDate = MaterialLocalizations.of(
      context,
    ).formatMediumDate(item.visitedOn);
    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(
              RechargeTheme.profileCompactRadius,
            ),
            child: SizedBox(
              width: 52,
              height: 52,
              child: item.coverImageUrl.isEmpty
                  ? const ColoredBox(
                      color: RechargeTheme.mint100,
                      child: Icon(
                        Icons.place_outlined,
                        color: RechargeTheme.profileAccent,
                      ),
                    )
                  : Image.network(
                      item.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: RechargeTheme.mint100,
                        child: Icon(
                          Icons.place_outlined,
                          color: RechargeTheme.profileAccent,
                        ),
                      ),
                    ),
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${item.city} · Self-reported $visitedDate',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 72),
      ],
    );
  }
}

class _ViewerUpgradeRow extends StatelessWidget {
  const _ViewerUpgradeRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 6),
      child: Material(
        color: RechargeTheme.profileAccent,
        borderRadius: BorderRadius.circular(RechargeTheme.profileCompactRadius),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.workspace_premium_outlined),
          iconColor: Colors.white,
          textColor: Colors.white,
          title: const Text(
            'Upgrade account',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ProGeneratorProfileBody extends StatelessWidget {
  const _ProGeneratorProfileBody({
    required this.displayName,
    required this.city,
    required this.avatar,
    required this.data,
    required this.onManagePage,
    required this.onCreatedEvents,
    required this.onInsights,
    required this.onBookings,
  });

  final String displayName;
  final String city;
  final String avatar;
  final _ProfileWorkspaceData data;
  final VoidCallback onManagePage;
  final VoidCallback onCreatedEvents;
  final VoidCallback onInsights;
  final VoidCallback onBookings;

  @override
  Widget build(BuildContext context) {
    final _CreatorListingData? listing =
        data.publishedListing ?? data.draftListing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _ProfileSectionLabel('MANAGED PAGE'),
        const SizedBox(height: 8),
        _ManagedPageCard(
          title: listing?.title ?? displayName,
          subtitle:
              'Organizer page · ${city.trim().isEmpty ? 'Riga' : city.trim()}',
          status: listing?.stageLabel ?? 'Active',
          coverImageUrl: listing?.draft.media.coverImage ?? avatar,
          onTap: onManagePage,
        ),
        const SizedBox(height: 14),
        const _ProfileSectionLabel('CONTROL CENTER'),
        const SizedBox(height: 8),
        _ProfileSurfacePanel(
          child: Column(
            children: <Widget>[
              _ProfileActionRow(
                icon: Icons.edit_square,
                title: 'Manage page',
                onTap: onManagePage,
              ),
              _ProfileActionRow(
                icon: Icons.event_note_outlined,
                title: 'Created events',
                onTap: onCreatedEvents,
              ),
              _ProfileActionRow(
                icon: Icons.insights_outlined,
                title: 'Event insights',
                onTap: onInsights,
              ),
              _ProfileActionRow(
                icon: Icons.group_outlined,
                title: 'Bookings & requests',
                onTap: onBookings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ManagedPageCard extends StatelessWidget {
  const _ManagedPageCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.coverImageUrl,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final String coverImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ProfileSurfacePanel(
      child: InkWell(
        borderRadius: BorderRadius.circular(RechargeTheme.profileCardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  RechargeTheme.profileCompactRadius,
                ),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: coverImageUrl.trim().isEmpty
                      ? const ColoredBox(
                          color: RechargeTheme.mint100,
                          child: Icon(
                            Icons.storefront_outlined,
                            color: RechargeTheme.profileAccent,
                          ),
                        )
                      : Image.network(
                          coverImageUrl.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: RechargeTheme.mint100,
                            child: Icon(
                              Icons.storefront_outlined,
                              color: RechargeTheme.profileAccent,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RechargeTheme.profileMuted),
                    ),
                    const SizedBox(height: 8),
                    _ProfileStatusPill(label: status),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSurfacePanel extends StatelessWidget {
  const _ProfileSurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.profileSurface,
        borderRadius: BorderRadius.circular(RechargeTheme.profileCardRadius),
        border: Border.all(color: RechargeTheme.profileBorder),
      ),
      child: child,
    );
  }
}

class _ProfileStatusPill extends StatelessWidget {
  const _ProfileStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.mint100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(
            color: RechargeTheme.profileAccent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LatestCreatedEvents extends StatelessWidget {
  const _LatestCreatedEvents({
    required this.data,
    required this.onViewAll,
    required this.onOpenListing,
    required this.onCreate,
    required this.onCreateRoute,
    required this.onScenario,
    required this.onFindPeople,
  });

  final _ProfileWorkspaceData data;
  final VoidCallback onViewAll;
  final ValueChanged<_CreatorListingData> onOpenListing;
  final VoidCallback onCreate;
  final VoidCallback onCreateRoute;
  final VoidCallback onScenario;
  final VoidCallback onFindPeople;

  @override
  Widget build(BuildContext context) {
    final List<_CreatorListingData> listings = <_CreatorListingData>[
      if (data.publishedListing != null) data.publishedListing!,
      if (data.draftListing != null) data.draftListing!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _ProfileSectionLabel('LATEST CREATED EVENTS'),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7ECE6)),
          ),
          child: Column(
            children: <Widget>[
              if (listings.isEmpty)
                _ProfileActionRow(
                  icon: Icons.add_box_outlined,
                  title: 'Create first event',
                  subtitle: 'Start from Recharge Create Hub',
                  onTap: onCreate,
                )
              else
                for (final _CreatorListingData listing in listings.take(3))
                  _CreatedEventRow(
                    listing: listing,
                    onTap: () => onOpenListing(listing),
                  ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                title: const Center(
                  child: Text(
                    'View all events',
                    style: TextStyle(
                      color: Color(0xFF0B3028),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: onViewAll,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _ProfileSectionLabel('QUICK ACTIONS'),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7ECE6)),
          ),
          child: Column(
            children: <Widget>[
              _ProfileActionRow(
                icon: Icons.add_box_outlined,
                title: 'Create Hub',
                subtitle: 'Open taxonomy-based creator flow',
                onTap: onCreate,
              ),
              _ProfileActionRow(
                icon: Icons.route_outlined,
                title: 'Create route',
                subtitle: 'Open the Route block in Create Hub',
                onTap: onCreateRoute,
              ),
              _ProfileActionRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Scenario Builder',
                subtitle: 'Build a personal plan from intent',
                onTap: onScenario,
              ),
              _ProfileActionRow(
                icon: Icons.calendar_today_outlined,
                title: 'One-time event',
                onTap: onCreate,
              ),
              _ProfileActionRow(
                icon: Icons.group_outlined,
                title: 'Find people',
                subtitle: 'Continue in Search conditions',
                onTap: onFindPeople,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreatedEventRow extends StatelessWidget {
  const _CreatedEventRow({required this.listing, required this.onTap});

  final _CreatorListingData listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CreateDraftEntity draft = listing.draft;
    return Column(
      children: <Widget>[
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          leading: _CreatedEventThumb(draft: draft),
          title: Text(
            draft.title.trim().isEmpty ? 'Untitled activity' : draft.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF10231F),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _createdEventMeta(draft),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              _CreatedEventStatus(label: listing.stageLabel),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 72),
      ],
    );
  }
}

class _CreatedEventThumb extends StatelessWidget {
  const _CreatedEventThumb({required this.draft});

  final CreateDraftEntity draft;

  @override
  Widget build(BuildContext context) {
    final String cover = draft.media.coverImage.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52,
        height: 52,
        child: cover.isEmpty
            ? const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFFDDE8E2), Color(0xFF86A89B)],
                  ),
                ),
                child: Icon(Icons.image_outlined, color: Color(0xFF0B3028)),
              )
            : Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFDDE8E2)),
                  child: Icon(Icons.image_outlined, color: Color(0xFF0B3028)),
                ),
              ),
      ),
    );
  }
}

class _CreatedEventStatus extends StatelessWidget {
  const _CreatedEventStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE6F5E8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1F6F27),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          dense: true,
          leading: Icon(icon, color: const Color(0xFF0B3028), size: 20),
          title: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 48),
      ],
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF7D8983),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatar, required this.displayName});

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
        child: Text(initials, style: Theme.of(context).textTheme.titleLarge),
      );
    }
    return CircleAvatar(
      radius: 32,
      backgroundImage: NetworkImage(avatar.trim()),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0B3028),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _RoleTrack extends StatelessWidget {
  const _RoleTrack({
    required this.activeTier,
    required this.accessSummary,
    required this.onRoleSelected,
  });

  final ProfileRoleTier activeTier;
  final ProfileRoleSummary accessSummary;
  final ValueChanged<ProfileRoleTier> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _ProfileSectionLabel('PROFILE MODE'),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7ECE6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _RoleCard(
                    title: 'User',
                    description: 'Discover, save, and join activities.',
                    active: activeTier == ProfileRoleTier.user,
                    unlocked: true,
                    icon: Icons.person_outline,
                    onTap: () => onRoleSelected(ProfileRoleTier.user),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _RoleCard(
                    title: 'Creator',
                    description: 'Create events and places for others.',
                    active: activeTier == ProfileRoleTier.creator,
                    unlocked: accessSummary.canCreate,
                    icon: Icons.edit_calendar_outlined,
                    onTap: accessSummary.canCreate
                        ? () => onRoleSelected(ProfileRoleTier.creator)
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _RoleCard(
                    title: 'Pro',
                    description: 'Generate scenarios, routes, and smart plans.',
                    active: activeTier == ProfileRoleTier.proGenerator,
                    unlocked: accessSummary.canGenerate,
                    icon: Icons.auto_awesome_outlined,
                    onTap: accessSummary.canGenerate
                        ? () => onRoleSelected(ProfileRoleTier.proGenerator)
                        : null,
                  ),
                ),
              ],
            ),
          ),
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
    required this.onTap,
  });

  final String title;
  final String description;
  final bool active;
  final bool unlocked;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = active
        ? Colors.white
        : unlocked
        ? const Color(0xFF0B3028)
        : const Color(0xFF9AA39E);
    return Tooltip(
      message: description,
      child: InkWell(
        onTap: unlocked ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0B3028) : const Color(0xFFF3F5F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(height: 5),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                _RoleStatusBadge(active: active, unlocked: unlocked),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleStatusBadge extends StatelessWidget {
  const _RoleStatusBadge({required this.active, required this.unlocked});

  final bool active;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final String label = active ? 'Active' : (unlocked ? 'Open' : 'Locked');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? Colors.white.withValues(alpha: 0.18) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF0B3028),
            fontSize: 9,
            fontWeight: FontWeight.w800,
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
            child: Column(children: _workspaceActions()),
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
          subtitle:
              '${data.activityCount} activities, ${data.scenarioCount} routes',
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
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(search.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
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
    final SmartRouteIntent? routeIntent = parseSmartSearch(
      item.prompt,
    ).routeIntent;
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
            _WorkspacePill(label: '${data.creatorPublicationCount} active'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Manage drafts and published listings from the same workspace.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
  const _CreatorNextStepRow({required this.step});

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
            _WorkspacePill(
              label: '${routeContext.stepCategories.length} stops',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          routeContext.prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
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
                (String step) =>
                    _WorkspacePill(label: createTaxonomyLabelForPath(step)),
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
  const _WorkspacePill({required this.label});

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
            OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
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
    return (draftListing == null ? 0 : 1) + (publishedListing == null ? 0 : 1);
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
  final bool currentMatchesPublished =
      publishedDraft != null &&
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
  final bool hasContent =
      draft.title.trim().isNotEmpty ||
      draft.mainCategory.trim().isNotEmpty ||
      draft.media.coverImage.trim().isNotEmpty;
  if (!hasContent) return null;
  final CreateTaxonomyCategory? category = createTaxonomyCategoryById(
    draft.mainCategory,
  );
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
    if (createBlockConfigFor(draft.objectType).requiresStartDateTime &&
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
  final Map<String, String> params = Map<String, String>.from(
    targetUri.queryParameters,
  );
  final String? steps = params['steps'];
  if (steps == null || steps.trim().isEmpty) {
    return RouteNames.discoverMap;
  }
  params['mode'] = 'scenario';
  return Uri(path: RouteNames.discoverMap, queryParameters: params).toString();
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
  final RegExpMatch? match = RegExp(
    r'(\d+)\s*min',
  ).firstMatch(draft.shortDescription);
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
  return Uri(
    path: RouteNames.smartSearch,
    queryParameters: <String, String>{'prompt': item.prompt},
  ).toString();
}

String _mapRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    return Uri(
      path: RouteNames.discoverMap,
      queryParameters: _smartRouteParameters(parseResult, includeMode: true),
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
  return category;
}

String _createRouteForSavedSearch(SavedSearchEntity search) {
  final Map<String, String> params = <String, String>{
    ..._queryParametersForSavedSearch(search.query),
    'source': 'saved_search',
    'type': 'event',
    'title': search.title,
    'subtitle': search.subtitle,
  };
  return Uri(path: RouteNames.create, queryParameters: params).toString();
}

String _createRouteForSmartSearch(SmartSearchHistoryEntity item) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    final SmartRouteIntent routeIntent = parseResult.routeIntent!;
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._smartRouteParameters(parseResult, includeMode: false),
        'source': 'scenario',
        'type': 'event',
        'title': '${_capitalized(routeIntent.mood)} recharge route',
        'subtitle':
            '${routeIntent.stepCategories.length} stops · '
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
  return Uri(path: RouteNames.create, queryParameters: params).toString();
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
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    return Uri(
      path: RouteNames.scenarioBuilder,
      queryParameters: _smartRouteParameters(parseResult, includeMode: false),
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
  final Set<String> normalizedCategories = query.selectedCategoryIds
      .map(normalizeRechargeContentGroupId)
      .toSet();
  if (queryText.contains('run') ||
      queryText.contains('sport') ||
      queryText.contains('tennis') ||
      normalizedCategories.contains('sport') ||
      normalizedCategories.contains('outdoor_nature_walking')) {
    return 'active';
  }
  if (normalizedCategories.contains('art_culture_museums') ||
      normalizedCategories.contains('music_nightlife') ||
      normalizedCategories.contains('family_kids')) {
    return 'social';
  }
  return 'calm';
}

String _promptForSavedSearch(DiscoverQuery query) {
  final List<String> parts = <String>[
    if (query.queryText.trim().isNotEmpty) query.queryText.trim(),
    if (query.selectedCategoryIds.isNotEmpty) query.selectedCategoryIds.first,
    if (query.freeOnly) 'free',
    if (query.budgetMax != null) 'under ${query.budgetMax!.toStringAsFixed(0)}',
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

String _createdEventMeta(CreateDraftEntity draft) {
  final DateTime? startsAt = draft.startDateTimeUtc?.toLocal();
  final String dateLabel;
  if (startsAt == null) {
    dateLabel = 'Date to be set';
  } else {
    final String hour = startsAt.hour.toString().padLeft(2, '0');
    final String minute = startsAt.minute.toString().padLeft(2, '0');
    dateLabel = 'May ${startsAt.day} · $hour:$minute';
  }
  return '$dateLabel · ${draft.city.isEmpty ? 'Riga' : draft.city}';
}
