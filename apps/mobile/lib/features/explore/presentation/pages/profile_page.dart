import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../../../core/localization/taxonomy_labels.dart';
import '../../../../shared/primitives/money/money.dart';
import '../widgets/scenario_library_panel.dart';
import '../../../../core/config/recharge_taxonomy.dart';
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

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
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
      return Scaffold(
        body: Center(child: Text(context.l10n.profileSignInRequired)),
      );
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
    final ProfilePersonalPresentation presentation =
        ProfilePersonalPresentation(accessSummary: accessRoleSummary);
    final _ProfileWorkspaceData workspaceData = _profileWorkspaceDataFor(
      context.l10n,
      favoritesState.items,
      savedSearches,
      smartSearchHistory,
      createState.publishedDraft,
      createState.draft,
    );

    return Scaffold(
      backgroundColor: RechargeTheme.profileBackground,
      appBar: AppBar(
        title: Text(context.l10n.profileRoleTitle(presentation.titleId)),
        backgroundColor: RechargeTheme.profileBackground,
        foregroundColor: RechargeTheme.ink,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: context.l10n.profileSettings,
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
          text: context.l10n.profileLoadFailed,
          actionLabel: context.l10n.commonRetry,
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
              presentation: presentation,
            ),
            const SizedBox(height: 14),
            _ProfileDashboardTabs(
              onCreated: () => context.push(RouteNames.profileWorkspace),
              onVisited: () => context.push(RouteNames.visitedPlaces),
              onPhotos: () => context.push(RouteNames.settings),
            ),
            const SizedBox(height: 10),
            _ProfileActionRow(
              icon: Icons.bookmark_border,
              title: context.l10n.profileSavedList,
              onTap: () => context.push(RouteNames.favorites),
            ),
            if (!presentation.canShowCreatorTools)
              _ProfileActionRow(
                icon: Icons.workspace_premium_outlined,
                title: context.l10n.profileCreatorTools,
                subtitle: context.l10n.profileCheckVerification,
                onTap: () => context.push(RouteNames.settings),
              ),
            const SizedBox(height: 14),
            ScenarioLibraryPanel(userId: user.id),
            const SizedBox(height: 14),
            _LatestCreatedEvents(
              data: workspaceData,
              canCreate: presentation.canShowCreatorTools,
              onViewAll: () => context.push(RouteNames.profileWorkspace),
              onOpenListing: (listing) =>
                  context.push(_searchRouteForCreateListing(listing)),
              onCreate: () => context.push(RouteNames.create),
              onCreateRoute: () => context.push(
                Uri(
                  path: RouteNames.create,
                  queryParameters: const <String, String>{'type': 'route'},
                ).toString(),
              ),
              onScenario: () => context.push(
                Uri(
                  path: RouteNames.create,
                  queryParameters: const <String, String>{'type': 'scenario'},
                ).toString(),
              ),
              onFindPeople: () => context.push(RouteNames.search),
            ),
            if (presentation.canShowGeneratorTools) ...<Widget>[
              const SizedBox(height: 14),
              _GeneratorToolsPanel(
                onManagePage: () => context.push(RouteNames.settings),
                onCreatedEvents: () =>
                    context.push(RouteNames.profileWorkspace),
                onInsights: () => context.push(RouteNames.profileWorkspace),
                onBookings: () => context.push(RouteNames.notifications),
              ),
            ],
            if (state.message ==
                ExploreController.profileSavedMessage) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                context.l10n.settingsProfileSaved,
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ],
        ),
      },
    );
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
}

String _profileContextLine(AppLocalizations l10n, String city) {
  final String location = city.trim().isEmpty
      ? 'Riga' // l10n-ignore: market city name
      : city.trim();
  return '${l10n.profilePersonal} · $location';
}

class ProfileWorkspacePage extends ConsumerStatefulWidget {
  const ProfileWorkspacePage({super.key});

  @override
  ConsumerState<ProfileWorkspacePage> createState() =>
      _ProfileWorkspacePageState();
}

class _ProfileWorkspacePageState extends ConsumerState<ProfileWorkspacePage> {
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
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).state;
    final favoritesState = ref.watch(favoritesControllerProvider).state;
    final createState = ref.watch(createControllerProvider).state;
    final discoverState = ref.watch(discoverFeedControllerProvider).state;
    final AuthUserEntity? user = authState.user;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(context.l10n.profileSignInRequired)),
      );
    }

    _scheduleCreateLoad(user);
    final ProfileRoleSummary accessRoleSummary = profileRoleSummaryFor(
      role: user.role,
      capabilities: user.capabilities,
    );
    final ProfileRoleSummary roleSummary = accessRoleSummary;
    final _ProfileWorkspaceData workspaceData = _profileWorkspaceDataFor(
      context.l10n,
      favoritesState.items,
      discoverState.savedSearches,
      discoverState.smartSearchHistory,
      createState.publishedDraft,
      createState.draft,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F2),
      appBar: AppBar(
        title: Text(context.l10n.profileWorkspace),
        backgroundColor: const Color(0xFFF4F6F2),
        foregroundColor: const Color(0xFF10231F),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _RoleWorkspace(
            roleSummary: roleSummary,
            data: workspaceData,
            onSaved: () => context.push(RouteNames.favorites),
            onSearch: () => context.push(RouteNames.search),
            onCreate: () => context.push(RouteNames.create),
            onScenario: () => context.push(
              Uri(
                path: RouteNames.create,
                queryParameters: const <String, String>{'type': 'scenario'},
              ).toString(),
            ),
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

  void _openSavedScenario(FavoriteItemEntity scenario) {
    final String? targetRoute = scenario.targetRoute;
    if (targetRoute == null || targetRoute.trim().isEmpty) {
      context.push(
        Uri(
          path: RouteNames.create,
          queryParameters: const <String, String>{'type': 'scenario'},
        ).toString(),
      );
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
    context.push(_createRouteForSmartSearch(context.l10n, item));
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
    required this.presentation,
  });

  final String displayName;
  final String email;
  final String avatar;
  final String city;
  final ProfilePersonalPresentation presentation;

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
                    '@${email.split('@').first}', // l10n-ignore: account handle, not copy
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
                          _profileContextLine(context.l10n, city),
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
                  _HeroPill(
                    label: context.l10n
                        .profileRoleTitle(presentation.titleId)
                        .toUpperCase(),
                  ),
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
    required this.onCreated,
    required this.onVisited,
    required this.onPhotos,
  });
  final VoidCallback onCreated;
  final VoidCallback onVisited;
  final VoidCallback onPhotos;
  @override
  Widget build(BuildContext context) => _ProfileSurfacePanel(
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          _ProfileDashboardTab(
            icon: Icons.work_outline,
            label: context.l10n.profileCreated,
            active: true,
            onTap: onCreated,
          ),
          _ProfileDashboardTab(
            icon: Icons.place_outlined,
            label: context.l10n.profileVisited,
            active: false,
            onTap: onVisited,
          ),
          _ProfileDashboardTab(
            icon: Icons.image_outlined,
            label: context.l10n.profilePhotos,
            active: false,
            onTap: onPhotos,
          ),
        ],
      ),
    ),
  );
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

class _GeneratorToolsPanel extends StatelessWidget {
  const _GeneratorToolsPanel({
    required this.onManagePage,
    required this.onCreatedEvents,
    required this.onInsights,
    required this.onBookings,
  });
  final VoidCallback onManagePage;
  final VoidCallback onCreatedEvents;
  final VoidCallback onInsights;
  final VoidCallback onBookings;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _ProfileSectionLabel(context.l10n.profileControlCenter),
      const SizedBox(height: 8),
      _ProfileSurfacePanel(
        child: Column(
          children: <Widget>[
            _ProfileActionRow(
              icon: Icons.edit_square,
              title: context.l10n.profileManagePage,
              onTap: onManagePage,
            ),
            _ProfileActionRow(
              icon: Icons.event_note_outlined,
              title: context.l10n.profileCreatedEvents,
              onTap: onCreatedEvents,
            ),
            _ProfileActionRow(
              icon: Icons.insights_outlined,
              title: context.l10n.profileEventInsights,
              onTap: onInsights,
            ),
            _ProfileActionRow(
              icon: Icons.group_outlined,
              title: context.l10n.profileBookingsRequests,
              onTap: onBookings,
            ),
          ],
        ),
      ),
    ],
  );
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
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _LatestCreatedEvents extends StatelessWidget {
  const _LatestCreatedEvents({
    required this.data,
    required this.canCreate,
    required this.onViewAll,
    required this.onOpenListing,
    required this.onCreate,
    required this.onCreateRoute,
    required this.onScenario,
    required this.onFindPeople,
  });

  final _ProfileWorkspaceData data;
  final bool canCreate;
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
        _ProfileSectionLabel(context.l10n.profileLatestCreatedEvents),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7ECE6)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: <Widget>[
                if (listings.isEmpty)
                  _ProfileActionRow(
                    icon: Icons.add_box_outlined,
                    title: canCreate
                        ? context.l10n.profileCreateFirstEvent
                        : context.l10n.profileNoCreatedEvents,
                    subtitle: canCreate
                        ? context.l10n.profileStartFromHub
                        : null,
                    onTap: canCreate ? onCreate : null,
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
                  title: Center(
                    child: Text(
                      context.l10n.profileViewAllEvents,
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
        ),
        const SizedBox(height: 14),
        _ProfileSectionLabel(context.l10n.profileQuickActions),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7ECE6)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: <Widget>[
                if (canCreate)
                  _ProfileActionRow(
                    icon: Icons.add_box_outlined,
                    title: context.l10n.profileCreateHub,
                    subtitle: context.l10n.profileOpenTaxonomyFlow,
                    onTap: onCreate,
                  ),
                if (canCreate)
                  _ProfileActionRow(
                    icon: Icons.route_outlined,
                    title: context.l10n.profileCreateRoute,
                    subtitle: context.l10n.profileOpenRouteBlock,
                    onTap: onCreateRoute,
                  ),
                _ProfileActionRow(
                  icon: Icons.auto_awesome_outlined,
                  title: context.l10n.profileCreateScenario,
                  subtitle: context.l10n.profileOpenScenarioBlock,
                  onTap: onScenario,
                ),
                if (canCreate)
                  _ProfileActionRow(
                    icon: Icons.calendar_today_outlined,
                    title: context.l10n.profileOneTimeEvent,
                    onTap: onCreate,
                  ),
                _ProfileActionRow(
                  icon: Icons.group_outlined,
                  title: context.l10n.profileFindPeople,
                  subtitle: context.l10n.profileContinueInSearch,
                  onTap: onFindPeople,
                ),
              ],
            ),
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
            draft.title.trim().isEmpty
                ? context.l10n.profileUntitledActivity
                : draft.title,
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
                _createdEventMeta(context.l10n, draft),
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
  final VoidCallback? onTap;

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
          context.l10n.profileWorkspaceHeading,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _WorkspaceMetric(
                label: context.l10n.profileSaved,
                value: data.savedCount.toString(),
                icon: Icons.bookmark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _WorkspaceMetric(
                label: context.l10n.profileRoutes,
                value: data.scenarioCount.toString(),
                icon: Icons.route,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _WorkspaceMetric(
                label: context.l10n.profileSearches,
                value: data.searchCount.toString(),
                icon: Icons.tune,
              ),
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
        if (roleSummary.canCreate && data.hasCreatorPublications) ...<Widget>[
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
            child: Column(children: _workspaceActions(context)),
          ),
        ),
      ],
    );
  }

  List<Widget> _workspaceActions(BuildContext context) {
    if (roleSummary.canGenerate) {
      return <Widget>[
        _WorkspaceActionRow(
          icon: Icons.auto_awesome,
          title: context.l10n.profileGenerateScenario,
          subtitle: context.l10n.profileOpenBuilderControls,
          onTap: onScenario,
        ),
        _WorkspaceDivider(),
        _WorkspaceActionRow(
          icon: Icons.psychology,
          title: context.l10n.profileSmartPrompt,
          subtitle: data.latestSmartSearch == null
              ? context.l10n.profileSearchContinuations(data.searchCount)
              : data.latestSmartSearch!.prompt,
          onTap: onSearch,
        ),
        _WorkspaceDivider(),
        _WorkspaceActionRow(
          icon: Icons.add_circle,
          title: context.l10n.profilePublishIdea,
          subtitle: context.l10n.profileIdeaToHub,
          onTap: onCreate,
        ),
      ];
    }
    if (roleSummary.canCreate) {
      return <Widget>[
        _WorkspaceActionRow(
          icon: Icons.add_circle,
          title: context.l10n.profileCreateHub,
          subtitle: context.l10n.profileDraftFromTaxonomy,
          onTap: onCreate,
        ),
        _WorkspaceDivider(),
        _WorkspaceActionRow(
          icon: Icons.route,
          title: context.l10n.profileBuildRouteIdea,
          subtitle: context.l10n.profileUseSavedInspiration,
          onTap: onScenario,
        ),
        _WorkspaceDivider(),
        _WorkspaceActionRow(
          icon: Icons.favorite,
          title: context.l10n.profileReviewSavedPlan,
          subtitle:
              '${context.l10n.profileActivitiesCount(data.activityCount)} · '
              '${context.l10n.profileRoutesCount(data.scenarioCount)}',
          onTap: onSaved,
        ),
      ];
    }
    return <Widget>[
      _WorkspaceActionRow(
        icon: Icons.favorite,
        title: context.l10n.profileSavedPlan,
        subtitle: context.l10n.profileSavedIdeasReady(data.savedCount),
        onTap: onSaved,
      ),
      _WorkspaceDivider(),
      _WorkspaceActionRow(
        icon: Icons.search,
        title: context.l10n.profileFindNextActivity,
        subtitle: data.latestSmartSearch != null
            // The search text is the reader's own, shown as is.
            ? '${context.l10n.profileResume}: ${data.latestSmartSearch!.prompt}'
            : data.latestSearch == null
            ? context.l10n.profileUseSearchMap
            : '${context.l10n.profileResume}: ${data.latestSearch!.title}',
        onTap: onSearch,
      ),
      _WorkspaceDivider(),
      _WorkspaceActionRow(
        icon: Icons.route,
        title: context.l10n.profileBuildARoute,
        subtitle: context.l10n.profilePersonalScenario,
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colorScheme.primary, size: 20),
            const SizedBox(height: 8),
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
                    context.l10n.profileLatestRoute,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _WorkspacePill(label: context.l10n.profileScenario),
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
                    label: Text(context.l10n.profileEditRoute),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRoute,
                    icon: const Icon(Icons.map),
                    label: Text(context.l10n.profileMapRoute),
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
                    context.l10n.profileLatestSearch,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _WorkspacePill(label: context.l10n.profileConditions),
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
                      ? context.l10n.profileAll
                      : search.query.selectedCategoryIds.first,
                ),
                _WorkspacePill(
                  label: search.query.unlimitedRadius
                      ? context.l10n.profileAnyArea
                      : context.l10n.discoverDistanceKm(
                          '${(search.query.radiusMeters / 1000).round()}',
                        ),
                ),
                if (search.query.freeOnly)
                  _WorkspacePill(label: context.l10n.profileFree),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.search),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.l10n.profileResumeSearch),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.l10n.profileMapSearch),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.l10n.profileRouteFromLatestSearch,
                  onPressed: onRoute,
                  icon: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.l10n.profileListingFromLatestSearch,
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
                    context.l10n.profileLatestSmartSearch,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _WorkspacePill(label: context.l10n.profileSmart),
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
                      ? context.l10n.profileAll
                      : item.query.selectedCategoryIds.first,
                ),
                if (routeIntent != null) ...<Widget>[
                  _WorkspacePill(label: context.l10n.profileSmartRoute),
                  _WorkspacePill(
                    label: context.l10n.discoverMinutes(
                      routeIntent.durationMinutes,
                    ),
                  ),
                  _WorkspacePill(
                    label: '${routeIntent.stepCategories.length} stops',
                  ),
                ],
                _WorkspacePill(
                  label: item.query.unlimitedRadius
                      ? context.l10n.profileAnyArea
                      : context.l10n.discoverDistanceKm(
                          '${(item.query.radiusMeters / 1000).round()}',
                        ),
                ),
                if (item.query.budgetMax != null)
                  _WorkspacePill(
                    label: context.l10n.discoverUnder(
                      RechargeFormats.money(
                        item.query.budgetMax!,
                        context.l10n.localeName,
                      ),
                    ),
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
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.l10n.profileResumeSmart),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.l10n.profileMapSmart),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.l10n.profileRouteFromLatestSmart,
                  onPressed: onRoute,
                  icon: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.l10n.profileListingFromLatestSmart,
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
                context.l10n.profileCreatorPublications,
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
          context.l10n.profileManageDrafts,
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
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(context.l10n.profileNewListing),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onScenario,
                icon: const Icon(Icons.route_outlined),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(context.l10n.profileBuildRoute),
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
                    context.l10n.profileCreatorListing,
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
                context.l10n.profileMissingFields(
                  listing.missingFields
                      .map(context.l10n.profileMissingField)
                      .join(', '),
                ),
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
                        listing.isPublished
                            ? context.l10n.profileOpenCreate
                            : context.l10n.profileContinueDraft,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.l10n.profileSearchSimilarListing,
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: context.l10n.profileMapListingArea,
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
    final List<_CreatorNextStepData> steps = _steps(context);
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
                    context.l10n.profileCreatorNextSteps,
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

  List<_CreatorNextStepData> _steps(BuildContext context) {
    final List<_CreatorNextStepData> steps = <_CreatorNextStepData>[];
    final _CreatorListingData? draft = data.draftListing;
    final _CreatorListingData? published = data.publishedListing;

    if (draft != null && onOpenListing != null) {
      if (draft.missingFields.isNotEmpty) {
        steps.add(
          _CreatorNextStepData(
            icon: Icons.fact_check_outlined,
            title: context.l10n.profileFinishDraft,
            subtitle: context.l10n.profileMissingFields(
              draft.missingFields
                  .map(context.l10n.profileMissingField)
                  .join(', '),
            ),
            onTap: () => onOpenListing!(draft),
          ),
        );
      } else if (onSearchListing != null) {
        steps.add(
          _CreatorNextStepData(
            icon: Icons.campaign_outlined,
            title: context.l10n.profileFindDraftAudience,
            // The draft title is the author's own text, shown as is.
            subtitle: '${context.l10n.profileOpenSearchWith} ${draft.title}',
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
            title: context.l10n.profileOpenRouteMap,
            subtitle:
                '${published.title} · '
                '${context.l10n.discoverStops(routeContext.stepCategories.length)}',
            onTap: () => onMapListingRoute!(published),
          ),
        );
      } else if (onMapListing != null) {
        steps.add(
          _CreatorNextStepData(
            icon: Icons.map_outlined,
            title: context.l10n.profileMapPublishedListing,
            subtitle: '${published.categoryLabel} · ${published.city}',
            onTap: () => onMapListing!(published),
          ),
        );
      }
    }

    if (roleSummary.canGenerate) {
      steps.add(
        _CreatorNextStepData(
          icon: Icons.auto_awesome,
          title: context.l10n.profileBuildNextRoute,
          subtitle: context.l10n.profileOpenQuickPlanNext,
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
                context.l10n.profilePublishedRoute,
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
            _WorkspacePill(
              label: context.l10n.discoverMinutes(routeContext.durationMinutes),
            ),
            if (routeContext.isFree)
              _WorkspacePill(label: context.l10n.profileFree),
            _WorkspacePill(label: context.l10n.profileWalking),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: routeContext.stepCategories
              .map(
                (String step) =>
                    _WorkspacePill(label: taxonomyLabel(context.l10n, step)),
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
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(context.l10n.profileEditRoute),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onMapRoute,
                icon: const Icon(Icons.map_outlined),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(context.l10n.profileRouteMap),
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
  AppLocalizations l10n,
  List<FavoriteItemEntity> items,
  List<SavedSearchEntity> savedSearches,
  List<SmartSearchHistoryEntity> smartSearchHistory,
  CreateDraftEntity? publishedDraft,
  CreateDraftEntity currentDraft,
) {
  final List<FavoriteItemEntity> visibleFavorites = items
      .where(
        (item) =>
            item.category.trim().toLowerCase() != 'scenario' &&
            !(item.targetRoute?.contains(RouteNames.legacyScenarioBuilder) ??
                false),
      )
      .toList(growable: false);
  SavedSearchEntity? latestSearch;
  SmartSearchHistoryEntity? latestSmartSearch;
  int freeCount = 0;

  for (final FavoriteItemEntity item in visibleFavorites) {
    if (item.isFree) freeCount += 1;
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
          l10n,
          publishedDraft,
          stageLabel: l10n.profileStagePublished,
          statusLabel: l10n.createOption(
            'PublishStatus_${publishedDraft.publishStatus.name}',
          ),
          isPublished: true,
        );
  final bool currentMatchesPublished =
      publishedDraft != null &&
      _sameListingContent(currentDraft, publishedDraft);
  final _CreatorListingData? draftListing = currentMatchesPublished
      ? null
      : _creatorListingDataFor(
          l10n,
          currentDraft,
          stageLabel: l10n.profileStageDraft,
          // DraftStatus shares the PublishStatus values.
          statusLabel: l10n.createOption(
            'PublishStatus_${currentDraft.draftStatus.name}',
          ),
          isPublished: false,
        );

  return _ProfileWorkspaceData(
    savedCount:
        visibleFavorites.length +
        savedSearches.length +
        smartSearchHistory.length,
    scenarioCount: 0,
    searchCount: savedSearches.length + smartSearchHistory.length,
    activityCount: visibleFavorites.length,
    freeCount: freeCount,
    latestScenario: null,
    latestSearch: latestSearch,
    latestSmartSearch: latestSmartSearch,
    draftListing: draftListing,
    publishedListing: publishedListing,
  );
}

_CreatorListingData? _creatorListingDataFor(
  AppLocalizations l10n,
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
    title: draft.title.trim().isEmpty
        ? l10n.profileUntitledListing
        : draft.title,
    subtitle: draft.shortDescription.trim().isEmpty
        ? _listingVenueLabel(l10n, draft)
        : draft.shortDescription,
    statusLabel: statusLabel,
    categoryLabel: category == null
        ? draft.mainCategory
        : taxonomyLabel(l10n, category.id),
    subcategory: draft.subcategory.trim().isEmpty
        ? ''
        : taxonomyLabel(l10n, '${draft.mainCategory}.${draft.subcategory}'),
    city: draft.city.trim().isEmpty ? l10n.profileNoCity : draft.city,
    priceLabel: draft.isFree
        ? l10n.discoverFree
        : RechargeFormats.money(
            draft.basePrice ??
                Money(minorUnits: 0, currencyCode: draft.currency),
            l10n.localeName,
          ),
    readinessLabel: missingFields.isEmpty
        ? (isPublished
              ? l10n.profilePublishedReady
              : l10n.profileReadyToPublish)
        : l10n.profileMissingCount(missingFields.length),
    missingFields: missingFields,
    routeContext: _PublishedRouteListingContext.fromDraft(l10n, draft),
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
      'start time', // l10n-ignore: stable missing-field id
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

  static _PublishedRouteListingContext? fromDraft(
    AppLocalizations l10n,
    CreateDraftEntity draft,
  ) {
    if (draft.mainCategory != 'travel_tours' ||
        draft.subcategory != 'walking_tour') {
      return null;
    }
    final List<String> steps = _routeStepsFromPublishedDraft(draft);
    if (steps.isEmpty) return null;
    return _PublishedRouteListingContext(
      prompt: draft.title.trim().isEmpty
          ? l10n.profilePublishedRoute
          : draft.title,
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
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._routeParameters(includeMode: false),
        'source': 'published_route_seed',
        'type': 'route',
        'category': 'route',
      },
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
      if (includeMode) 'mode': 'route',
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
  final String marker =
      'Route steps: '; // l10n-ignore: seed marker parsed back from the description
  final int markerIndex = draft.fullDescription.indexOf(marker);
  if (markerIndex >= 0) {
    final int start = markerIndex + marker.length;
    final int end = draft.fullDescription.indexOf(
      '. Review', // l10n-ignore: seed marker
      start,
    );
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

String _createRouteForSmartSearch(
  AppLocalizations l10n,
  SmartSearchHistoryEntity item,
) {
  final SmartSearchParseResult? parseResult = _smartRouteParseForSmartSearch(
    item,
  );
  if (parseResult != null) {
    final SmartRouteIntent routeIntent = parseResult.routeIntent!;
    return Uri(
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._smartRouteParameters(parseResult, includeMode: false),
        'source': 'smart_route_seed',
        'type': 'route',
        'title':
            '${_capitalized(routeIntent.mood)} recharge route', // l10n-ignore: Create seed prefill data
        'subtitle':
            '${routeIntent.stepCategories.length} stops · ' // l10n-ignore: Create seed prefill data
            '${routeIntent.durationMinutes} min · smart route', // l10n-ignore: Create seed prefill data
        'q': parseResult.originalText.trim(),
        'category': 'route',
      },
    ).toString();
  }
  final Map<String, String> params = <String, String>{
    ..._queryParametersForSavedSearch(item.query),
    'source': 'smart_search',
    'type': 'event',
    'title': _titleForSmartSearch(l10n, item.query),
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
      path: RouteNames.create,
      queryParameters: <String, String>{
        ..._smartRouteParameters(parseResult, includeMode: false),
        'source': 'smart_route_seed',
        'type': 'route',
        'category': 'route',
      },
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
    if (includeMode) 'mode': 'route',
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
    path: RouteNames.create,
    queryParameters: <String, String>{
      ...params,
      'source': 'saved_search_route_seed',
      'type': 'route',
      'category': 'route',
    },
  ).toString();
}

String _titleForSmartSearch(AppLocalizations l10n, DiscoverQuery query) {
  final String queryText = query.queryText.trim();
  if (queryText.isNotEmpty) {
    return queryText[0].toUpperCase() + queryText.substring(1);
  }
  if (query.selectedCategoryIds.isNotEmpty) {
    return '${query.selectedCategoryIds.first} idea';
  }
  return l10n.profileSmartSearchIdea;
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
    if (query.budgetMax != null)
      'under ${query.budgetMax!.toStringAsFixed(0)}', // l10n-ignore: search prompt text built from the saved query, not UI copy
    query.unlimitedRadius
        ? 'any area' // l10n-ignore: search prompt text built from the saved query, not UI copy
        : 'near ${(query.radiusMeters / 1000).round()} km', // l10n-ignore: search prompt text built from the saved query, not UI copy
  ];
  return parts.join(' · ');
}

String _listingVenueLabel(AppLocalizations l10n, CreateDraftEntity draft) {
  if (draft.venueName.isNotEmpty && draft.city.isNotEmpty) {
    return '${draft.venueName} · ${draft.city}';
  }
  if (draft.venueName.isNotEmpty) return draft.venueName;
  return draft.city.isEmpty ? l10n.profileDraftListing : draft.city;
}

String _createdEventMeta(AppLocalizations l10n, CreateDraftEntity draft) {
  // L4.6: the start in the object's own zone (an unknown zone shows UTC).
  final DateTime? startsAtUtc = draft.startDateTimeUtc;
  final String dateLabel = startsAtUtc == null
      ? l10n.profileDateTbd
      : RechargeFormats.dateTime(startsAtUtc, draft.timezone, l10n.localeName);
  return '$dateLabel · ${draft.city.isEmpty ? 'Riga' : draft.city}'; // l10n-ignore: market city name
}
