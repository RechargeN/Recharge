import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/money_test_values.dart';
import 'package:recharge/app/adapters/discover_scenario_intake_adapter.dart';
import 'package:recharge/app/application/scenario_object_intake_facade.dart';
import 'package:recharge/app/application/scenario_object_intake_providers.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/scenario_object_intake_sheet.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/datasources/scenario_object_intake_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/scenario_object_intake_repository_impl.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';

void main() {
  const storage = FlutterSecureStorage();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    await sl.reset();
  });

  tearDown(() => sl.reset());

  testWidgets('auth expiry blocks Apply, then retry commits once', (
    tester,
  ) async {
    final ids = _Ids(<String>[
      'intent-1',
      'day-1',
      'scenario-1',
      'item-1',
      'location-1',
    ]);
    sl.registerSingleton<IdGenerator>(ids);
    final collection = CreateRepositoryImpl(
      localDataSource: CreateLocalDataSource(storage, activeCurrency: 'EUR'),
      idGenerator: ids,
    );
    final facade = ScenarioObjectIntakeFacade(
      intentRepository: ScenarioObjectIntakeRepositoryImpl(
        ScenarioObjectIntakeLocalDataSource(storage),
      ),
      collectionRepository: collection,
      scenarioCoordinator: ScenarioCreateCoordinator(idGenerator: ids),
      runtimeDefaults: _defaults,
      idGenerator: ids,
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    var authenticated = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          discoverScenarioIntakeAdapterProvider.overrideWithValue(
            const DiscoverScenarioIntakeAdapter(),
          ),
          scenarioObjectIntakeFacadeProvider.overrideWithValue(facade),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: FilledButton(
                onPressed: () => showScenarioObjectIntakeSheet(
                  context: context,
                  ref: ref,
                  items: <DiscoverItemEntity>[_item],
                  sourceSurface: ScenarioObjectIntakeSurface.details,
                  requesterId: 'user-1',
                  requesterEmail: 'user@example.test',
                  requesterName: 'User',
                  isRequesterAuthenticated: () => authenticated,
                ),
                child: const Text('Launch intake'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch intake'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 · Scenario'), findsOneWidget);
    await tester.tap(find.text('Create new Scenario'));
    await tester.pump();
    await tester.tap(find.text('Continue to placement'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 3 · Placement'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await tester.pump();
    expect(find.text('3 of 3 · Review'), findsOneWidget);

    await tester.tap(find.text('Add 1'));
    await tester.pump();
    expect(
      find.text('Sign in again before adding items to Scenario.'),
      findsOneWidget,
    );
    expect(await facade.listTargets('user-1'), isEmpty);

    authenticated = true;
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsOneWidget);
    expect(find.textContaining('Added 1 to'), findsOneWidget);
    expect(await facade.listTargets('user-1'), hasLength(1));
  });

  testWidgets('360dp at text scale 1.5 stays usable and announces result', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    final semantics = tester.ensureSemantics();
    final ids = _Ids(<String>[
      'intent-adaptive',
      'day-adaptive',
      'scenario-adaptive',
      'item-adaptive',
      'location-adaptive',
    ]);
    sl.registerSingleton<IdGenerator>(ids);
    final facade = ScenarioObjectIntakeFacade(
      intentRepository: ScenarioObjectIntakeRepositoryImpl(
        ScenarioObjectIntakeLocalDataSource(storage),
      ),
      collectionRepository: CreateRepositoryImpl(
        localDataSource: CreateLocalDataSource(storage, activeCurrency: 'EUR'),
        idGenerator: ids,
      ),
      scenarioCoordinator: ScenarioCreateCoordinator(idGenerator: ids),
      runtimeDefaults: _defaults,
      idGenerator: ids,
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          discoverScenarioIntakeAdapterProvider.overrideWithValue(
            const DiscoverScenarioIntakeAdapter(),
          ),
          scenarioObjectIntakeFacadeProvider.overrideWithValue(facade),
        ],
        child: MaterialApp(
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            );
          },
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: FilledButton(
                onPressed: () => showScenarioObjectIntakeSheet(
                  context: context,
                  ref: ref,
                  items: <DiscoverItemEntity>[_item],
                  sourceSurface: ScenarioObjectIntakeSurface.details,
                  requesterId: 'user-1',
                  requesterEmail: 'user@example.test',
                  requesterName: 'User',
                  isRequesterAuthenticated: () => true,
                ),
                child: const Text('Launch adaptive intake'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch adaptive intake'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Create new Scenario'));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue to placement'));
    await tester.tap(find.text('Continue to placement'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Review'));
    await tester.tap(find.text('Review'));
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp('Selected stop 1.*GORS')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Add 1'));
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel(RegExp('Success.*Added 1 stops')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

const CreateRuntimeDefaults _defaults = CreateRuntimeDefaults(
  marketCityId: 'latvia',
  timezone: 'Europe/Riga',
  country: 'LV',
  city: 'Riga',
  currency: 'EUR',
);

final DiscoverItemEntity _item = DiscoverItemEntity(
  id: 'place-1',
  title: 'GORS',
  subtitle: 'Culture centre',
  city: 'Rezekne',
  category: 'culture',
  startsAtUtc: DateTime.utc(2026, 8, 8, 17),
  latitude: 56.5099,
  longitude: 27.3332,
  price: testZeroEur,
  distanceKm: 1,
  isFree: true,
  objectKind: DiscoverObjectKind.place,
  venueName: 'GORS',
  addressLine: 'Atbrivosanas aleja 93',
  marketCityId: 'rezekne',
  timezoneId: 'Europe/Riga',
  durationMinutes: 60,
);

class _Ids implements IdGenerator {
  _Ids(this._values);

  final List<String> _values;

  @override
  String generate() {
    if (_values.isEmpty) throw StateError('No test ids left.');
    return _values.removeAt(0);
  }
}
