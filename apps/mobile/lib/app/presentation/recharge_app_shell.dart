import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/identity/account_experience.dart';
import '../../features/identity/application/controllers/identity_workspace_controller.dart';
import '../../features/identity/application/identity_workspace_providers.dart';
import '../router/route_names.dart';

class RechargeAppShell extends ConsumerStatefulWidget {
  const RechargeAppShell({
    super.key,
    required this.currentLocation,
    required this.child,
    this.userId = '',
  });

  final String currentLocation;
  final Widget child;
  final String userId;

  @override
  ConsumerState<RechargeAppShell> createState() => _RechargeAppShellState();
}

class _RechargeAppShellState extends ConsumerState<RechargeAppShell> {
  static const List<_RechargeDestination> _personalDestinations =
      <_RechargeDestination>[
        _RechargeDestination(
          id: 'home',
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          route: RouteNames.discover,
        ),
        _RechargeDestination(
          id: 'favorites',
          label: 'Favorites',
          icon: Icons.favorite_border_rounded,
          selectedIcon: Icons.favorite_rounded,
          route: RouteNames.favorites,
        ),
        _RechargeDestination(
          id: 'smart-search',
          label: 'Smart Search',
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome,
          route: RouteNames.smartSearch,
        ),
        _RechargeDestination(
          id: 'notifications',
          label: 'Notifications',
          icon: Icons.notifications_none_rounded,
          selectedIcon: Icons.notifications_rounded,
          route: RouteNames.notifications,
        ),
        _RechargeDestination(
          id: 'profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          route: RouteNames.profile,
        ),
      ];

  static const List<_RechargeDestination> _professionalDestinations =
      <_RechargeDestination>[
        _RechargeDestination(
          id: 'page',
          label: 'Page',
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront_rounded,
          route: RouteNames.professionalPage,
        ),
        _RechargeDestination(
          id: 'content',
          label: 'Content',
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view_rounded,
          route: RouteNames.professionalPageContent,
        ),
        _RechargeDestination(
          id: 'create',
          label: 'Create',
          icon: Icons.add_circle_outline_rounded,
          selectedIcon: Icons.add_circle_rounded,
          route: RouteNames.professionalPageCreate,
        ),
        _RechargeDestination(
          id: 'notifications',
          label: 'Notifications',
          icon: Icons.notifications_none_rounded,
          selectedIcon: Icons.notifications_rounded,
          route: RouteNames.notifications,
        ),
        _RechargeDestination(
          id: 'account',
          label: 'Account',
          icon: Icons.manage_accounts_outlined,
          selectedIcon: Icons.manage_accounts_rounded,
          route: RouteNames.professionalPageAccount,
        ),
      ];

  String? _loadedUserId;
  String? _scheduledRedirectKey;

  @override
  Widget build(BuildContext context) {
    final IdentityWorkspaceController? identityController =
        widget.userId.isEmpty
        ? null
        : ref.watch(identityWorkspaceControllerProvider);
    _ensureIdentityLoaded(widget.userId);
    final AccountExperience experience =
        identityController?.state.effectiveExperience ??
        AccountExperience.viewer;
    final bool isProfessional =
        experience == AccountExperience.professionalPage;
    final List<_RechargeDestination> destinations = isProfessional
        ? _professionalDestinations
        : _personalDestinations;
    if (identityController?.state.isLoaded ?? false) {
      _scheduleExperienceRedirect(isProfessional);
    }

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: AccountExperienceScope(experience: experience, child: widget.child),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _selectedIndexFor(widget.currentLocation, destinations),
        backgroundColor: colorScheme.surface,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (int index) {
          final String targetRoute = destinations[index].route;
          if (_isSameTopLevelRoute(widget.currentLocation, targetRoute)) {
            return;
          }
          context.go(targetRoute);
        },
        destinations: destinations
            .map(
              (_RechargeDestination destination) => NavigationDestination(
                key: ValueKey<String>('bottom-nav-${destination.id}'),
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  void _ensureIdentityLoaded(String userId) {
    if (userId.isEmpty || _loadedUserId == userId) return;
    _loadedUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(identityWorkspaceControllerProvider).ensureLoaded(userId);
    });
  }

  void _scheduleExperienceRedirect(bool isProfessional) {
    final bool onProfessionalRoute =
        widget.currentLocation == RouteNames.professionalPage ||
        widget.currentLocation == RouteNames.professionalPageContent ||
        widget.currentLocation == RouteNames.professionalPageCreate ||
        widget.currentLocation == RouteNames.professionalPageAccount;
    final String? target = isProfessional && !onProfessionalRoute
        ? widget.currentLocation == RouteNames.notifications
              ? null
              : RouteNames.professionalPage
        : !isProfessional && onProfessionalRoute
        ? RouteNames.discover
        : null;
    if (target == null) {
      _scheduledRedirectKey = null;
      return;
    }
    final String key = '${widget.currentLocation}:$target';
    if (_scheduledRedirectKey == key) return;
    _scheduledRedirectKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(target);
    });
  }

  static int _selectedIndexFor(
    String location,
    List<_RechargeDestination> destinations,
  ) {
    final int exact = destinations.indexWhere(
      (_RechargeDestination item) => item.route == location,
    );
    if (exact >= 0) return exact;

    int selected = 0;
    int longestMatch = -1;
    for (int index = 0; index < destinations.length; index += 1) {
      final String route = destinations[index].route;
      if (location.startsWith('$route/') && route.length > longestMatch) {
        selected = index;
        longestMatch = route.length;
      }
    }
    return selected;
  }

  static bool _isSameTopLevelRoute(String location, String targetRoute) {
    if (targetRoute == RouteNames.smartSearch) {
      return location == RouteNames.smartSearch ||
          location.startsWith('${RouteNames.smartSearch}/');
    }
    return location == targetRoute;
  }
}

class _RechargeDestination {
  const _RechargeDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
