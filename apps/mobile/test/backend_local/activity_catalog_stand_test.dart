import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/discover_catalog_composition.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/discover/data/repositories/catalog_discover_repository.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/presentation/shell/compatibility_object_renderer.dart';
import 'package:uuid/uuid.dart';
import 'support/stand_backend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final StandBackend? stand = StandBackend.fromEnvironment();
  testWidgets(
    'Activity Catalog real Feed Search Map Details and existing renderer',
    (WidgetTester tester) async {
      final Directory temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('activity-catalog-stand-'),
      ))!;
      try {
        final manifest = (await tester.runAsync(
          () => stand!.activityManifest(),
        ))!;
        final String id = manifest['contentId']! as String;
        await tester.runAsync(() => stand!.catalog(<String>['deliver']));
        final binding = BookingBackendBindingController(
          emulatorBase: StandBackend.functionsBase,
          releaseMode: false,
          initial: BackendBindingMode.testBackend,
        );
        final sessions = FileSessionStore(File('${temp.path}/session.json'));
        final runtime = (await tester.runAsync(
          () => BookingTransportRuntimeFactory(
            endpoint: binding.endpoint,
            client: CountingClient(),
            tokens: AuthEmulatorTokenProvider('stand-user-viewer'),
            sessions: sessions,
            installations: const FixedInstallationId(
              'activity-catalog-stand-viewer',
            ),
            supportDirectory: () async =>
                Directory('${temp.path}/support').create(recursive: true),
          ).create(),
        ))!;
        await tester.runAsync(
          () =>
              runtime.identitySessions!.establish(requestId: const Uuid().v4()),
        );
        final port = BookingPortCatalogAdapter(
          runtime: () async => runtime,
          guard: DiscoverCatalogTestEntryGuard(
            flag: true,
            releaseMode: false,
            binding: binding,
          ),
        );
        final session = CatalogSnapshotSession();
        final repo = CatalogDiscoverRepository(
          port: port,
          session: session,
          marketId: 'LV',
          currencyCode: 'EUR',
          activityEnabled: true,
        );
        final query = DiscoverQuery.defaults(
          centerLat: 56.9142,
          centerLng: 23.4706,
        ).copyWith(unlimitedRadius: true);
        final feed = await tester.runAsync(() => repo.getFeed(query));
        final item = feed!.firstWhere((entry) => entry.id == id);
        expect(item.objectKind, DiscoverObjectKind.activity);
        expect(item.revisionRef, manifest['publishedRevisionId']);
        expect(item.startsAtUtc, isNull);
        expect(item.priceAmount, isNull);
        expect(item.latitude, 56.9142);
        expect(item.activityCatalog!.durationMaxMinutes, 120);
        final search = await tester.runAsync(
          () => repo.getFeed(query.copyWith(queryText: 'Ķemeri')),
        );
        expect(search!.any((entry) => entry.id == id), isTrue);
        final map = await tester.runAsync(
          () => port.query(<String, Object?>{
            'schemaVersion': 1,
            'requestId': const Uuid().v4(),
            'queryType': 'map',
            'payload': <String, Object?>{
              'query': session.query!,
              'snapshotToken': session.snapshotToken!,
            },
          }),
        );
        expect(map!['kind'], 'succeeded');
        expect(
          ((map['map']! as Map)['leaves'] as List).any(
            (Object? leaf) => (leaf! as Map)['ref']['contentId'] == id,
          ),
          isTrue,
        );
        final details = await tester.runAsync(() => repo.getDetails(id));
        expect(details!.revisionRef, item.revisionRef);
        expect(details.activityCatalog!.timeOfDay, 'morning');
        void noop() {}
        final renderer = CompatibilityObjectRenderer(
          item: details,
          isFavorite: false,
          ctaSubmitted: false,
          onFavoriteTap: noop,
          onShareTap: noop,
          onMap: noop,
          onRouteMap: noop,
          onAddToScenario: null,
          onSearch: noop,
          onCreateSimilar: noop,
          onCreateRoute: noop,
          onMarkVisited: noop,
          onCtaTap: noop,
          onReportRoute: noop,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Builder(builder: renderer.buildBody),
              ),
            ),
          ),
        );
        expect(find.text('Typical duration: 60–120 min'), findsOneWidget);
        expect(find.text('Best time: morning'), findsOneWidget);
        expect(find.text('Season: any'), findsOneWidget);
        expect(find.text('Free'), findsNothing);
        expect(tester.takeException(), isNull);
        final disabled = CatalogDiscoverRepository(
          port: port,
          session: session,
          marketId: 'LV',
          currencyCode: 'EUR',
        );
        await tester.runAsync(
          () => expectLater(
            disabled.getDetails(id),
            throwsA(isA<DiscoverException>()),
          ),
        );
      } finally {
        await tester.runAsync(() => temp.delete(recursive: true));
      }
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
