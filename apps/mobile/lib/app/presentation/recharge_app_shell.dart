import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';

class RechargeAppShell extends StatelessWidget {
  const RechargeAppShell({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  static const List<_RechargeDestination> _destinations =
      <_RechargeDestination>[
        _RechargeDestination(
          label: 'Главная',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          route: RouteNames.discover,
        ),
        _RechargeDestination(
          label: 'Избранное',
          icon: Icons.favorite_border_rounded,
          selectedIcon: Icons.favorite_rounded,
          route: RouteNames.favorites,
        ),
        _RechargeDestination(
          label: 'Smart Search',
          icon: Icons.auto_awesome_outlined,
          selectedIcon: Icons.auto_awesome,
          route: RouteNames.smartSearch,
        ),
        _RechargeDestination(
          label: 'Уведомления',
          icon: Icons.notifications_none_rounded,
          selectedIcon: Icons.notifications_rounded,
          route: RouteNames.notifications,
        ),
        _RechargeDestination(
          label: 'Профиль',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          route: RouteNames.profile,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndexFor(currentLocation),
        backgroundColor: colorScheme.surface,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (int index) {
          final String targetRoute = _destinations[index].route;
          if (_isSameTopLevelRoute(currentLocation, targetRoute)) return;
          context.go(targetRoute);
        },
        destinations: _destinations
            .map(
              (_RechargeDestination destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  static int _selectedIndexFor(String location) {
    if (location == RouteNames.favorites ||
        location.startsWith('${RouteNames.favorites}/')) {
      return 1;
    }
    if (location == RouteNames.smartSearch ||
        location.startsWith('${RouteNames.smartSearch}/')) {
      return 2;
    }
    if (location == RouteNames.notifications ||
        location.startsWith('${RouteNames.notifications}/')) {
      return 3;
    }
    if (location == RouteNames.profile ||
        location.startsWith('${RouteNames.profile}/')) {
      return 4;
    }
    return 0;
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
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
