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
      label: 'Поиск',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      route: RouteNames.search,
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
        indicatorColor: colorScheme.primaryContainer,
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
    if (location == RouteNames.search ||
        location == RouteNames.discoverResults ||
        location == RouteNames.discoverMap ||
        location == RouteNames.scenarioBuilder ||
        location.startsWith('${RouteNames.search}/') ||
        location.startsWith('${RouteNames.discoverResults}/') ||
        location.startsWith('${RouteNames.discoverMap}/') ||
        location.startsWith('${RouteNames.scenarioBuilder}/')) {
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
    if (targetRoute == RouteNames.search) {
      return location == RouteNames.search ||
          location == RouteNames.discoverResults ||
          location == RouteNames.discoverMap ||
          location == RouteNames.scenarioBuilder;
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
