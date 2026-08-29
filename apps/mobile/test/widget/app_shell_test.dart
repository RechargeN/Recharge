import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/presentation/recharge_app_shell.dart';
import 'package:recharge/app/router/route_names.dart';

void main() {
  testWidgets('selects home destination for discover', (tester) async {
    await tester.pumpWidget(_TestApp(initialLocation: RouteNames.discover));
    await tester.pumpAndSettle();

    expect(_navigationBar(tester).selectedIndex, 0);
    expect(
      _navigationBar(tester).labelBehavior,
      NavigationDestinationLabelBehavior.alwaysHide,
    );
    expect(_navigationBar(tester).height, 64);
    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('keeps map outside search destination', (tester) async {
    await tester.pumpWidget(_TestApp(initialLocation: RouteNames.discoverMap));
    await tester.pumpAndSettle();

    expect(_navigationBar(tester).selectedIndex, 0);
    expect(find.text('Map page'), findsOneWidget);
  });

  testWidgets('keeps scenario builder outside search destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(initialLocation: RouteNames.legacyScenarioBuilder),
    );
    await tester.pumpAndSettle();

    expect(_navigationBar(tester).selectedIndex, 0);
    expect(find.text('Builder page'), findsOneWidget);
  });

  testWidgets('moves to Smart Search destination from bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(_TestApp(initialLocation: RouteNames.discover));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bottom-nav-smart-search')));
    await tester.pumpAndSettle();

    expect(_navigationBar(tester).selectedIndex, 2);
    expect(find.text('Smart Search page'), findsOneWidget);
  });

  testWidgets('moves from map to Smart Search with bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(_TestApp(initialLocation: RouteNames.discoverMap));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bottom-nav-smart-search')));
    await tester.pumpAndSettle();

    expect(_navigationBar(tester).selectedIndex, 2);
    expect(find.text('Smart Search page'), findsOneWidget);
  });

  testWidgets('keeps regular Search outside Smart Search destination', (
    tester,
  ) async {
    await tester.pumpWidget(_TestApp(initialLocation: RouteNames.search));
    await tester.pumpAndSettle();

    expect(_navigationBar(tester).selectedIndex, 0);
    expect(find.text('Search page'), findsOneWidget);
  });
}

NavigationBar _navigationBar(WidgetTester tester) {
  return tester.widget<NavigationBar>(find.byType(NavigationBar));
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.initialLocation});

  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: <RouteBase>[
            ShellRoute(
              builder: (context, state, child) => RechargeAppShell(
                currentLocation: state.uri.path,
                child: child,
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: RouteNames.discover,
                  builder: (context, state) => const _ShellBody('Home page'),
                ),
                GoRoute(
                  path: RouteNames.search,
                  builder: (context, state) => const _ShellBody('Search page'),
                ),
                GoRoute(
                  path: RouteNames.smartSearch,
                  builder: (context, state) =>
                      const _ShellBody('Smart Search page'),
                ),
                GoRoute(
                  path: RouteNames.discoverMap,
                  builder: (context, state) => const _ShellBody('Map page'),
                ),
                GoRoute(
                  path: RouteNames.discoverResults,
                  builder: (context, state) => const _ShellBody('Results page'),
                ),
                GoRoute(
                  path: RouteNames.legacyScenarioBuilder,
                  builder: (context, state) => const _ShellBody('Builder page'),
                ),
                GoRoute(
                  path: RouteNames.favorites,
                  builder: (context, state) =>
                      const _ShellBody('Favorites page'),
                ),
                GoRoute(
                  path: RouteNames.notifications,
                  builder: (context, state) =>
                      const _ShellBody('Notifications page'),
                ),
                GoRoute(
                  path: RouteNames.profile,
                  builder: (context, state) => const _ShellBody('Profile page'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellBody extends StatelessWidget {
  const _ShellBody(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
