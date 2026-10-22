import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/discover_catalog_composition.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/discover/data/datasources/catalog_query_port.dart';
import 'package:recharge/features/discover/data/repositories/catalog_discover_repository.dart';
import 'package:recharge/features/discover/data/repositories/catalog_snapshot_session.dart';
import 'package:recharge/features/discover/data/repositories/discover_item_details_lookup.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/domain/entities/discover_query.dart';
import 'package:recharge/features/discover/domain/entities/route_catalog_facts.dart';
import 'package:recharge/features/discover/domain/repositories/discover_repository.dart';
import 'package:recharge/features/discover/domain/usecases/get_discover_details_usecase.dart';
import 'package:recharge/features/discover/presentation/renderers/route_details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';
import 'package:recharge/features/discover/presentation/widgets/route_segment_polylines.dart';
import 'package:uuid/uuid.dart';

import 'support/stand_backend.dart';

/// DTL-RTE-02 on the local stand: the J2-published Routes (the Creator's
/// trimmed recorded walk and the Page's two-part walk with a gap) are read
/// from the real Catalog through the real Discover adapters — Feed, Search,
/// Map, the canonical Details lookup and the Route Details renderer — and the
/// lifecycle is followed through restart, offline, a new revision, a
/// withdrawal and a restore. The define `RECHARGE_TEST_ROUTE_CATALOG=true`
/// comes from the gate.
///
/// Limits: PC host run (no device), viewer Session from the B1-local Auth
/// Emulator path.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final StandBackend? stand = StandBackend.fromEnvironment();

  testWidgets(
    'published Routes open from the Catalog in Discover and Details',
    (WidgetTester tester) async {
      final Directory temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('dtl-rte-02-'),
      ))!;
      try {
        await tester.runAsync(() => stand!.routeSeed());
        final Map<String, Object?> manifest = (await tester.runAsync(
          () => stand!.routeManifest(),
        ))!;
        final String personalId = manifest['contentId']! as String;
        final String pageId =
            (manifest['page']! as Map<String, Object?>)['contentId']! as String;
        await tester.runAsync(() => stand!.catalog(<String>['deliver']));
        final BookingBackendBindingController binding =
            BookingBackendBindingController(
              emulatorBase: StandBackend.functionsBase,
              releaseMode: false,
              initial: BackendBindingMode.testBackend,
            );

        Future<BookingTransportRuntime> viewer(String installation) async {
          final BookingTransportRuntime runtime =
              await BookingTransportRuntimeFactory(
                endpoint: binding.endpoint,
                client: CountingClient(),
                tokens: AuthEmulatorTokenProvider('stand-user-viewer'),
                sessions: FileSessionStore(
                  File('${temp.path}/$installation.json'),
                ),
                installations: FixedInstallationId(installation),
                supportDirectory: () async => Directory(
                  '${temp.path}/$installation-support',
                ).create(recursive: true),
              ).create();
          await runtime.identitySessions!.establish(
            requestId: const Uuid().v4(),
          );
          return runtime;
        }

        CatalogQueryPort portFor(
          BookingTransportRuntime runtime, {
          bool allowed = true,
        }) => BookingPortCatalogAdapter(
          runtime: () async => runtime,
          guard: DiscoverCatalogTestEntryGuard(
            flag: allowed,
            releaseMode: false,
            binding: binding,
          ),
        );
        final BookingTransportRuntime runtime = (await tester.runAsync(
          () => viewer('dtl-rte-02-viewer'),
        ))!;
        final CatalogQueryPort port = portFor(runtime);
        final CatalogSnapshotSession session = CatalogSnapshotSession();
        CatalogDiscoverRepository repositoryFor(
          CatalogQueryPort port,
          CatalogSnapshotSession session,
        ) => CatalogDiscoverRepository(
          port: port,
          session: session,
          marketId: 'LV',
          currencyCode: 'EUR',
          routeEnabled: true,
        );
        final CatalogDiscoverRepository repository = repositoryFor(
          port,
          session,
        );
        final DiscoverQuery browse = DiscoverQuery.defaults(
          centerLat: 56.96,
          centerLng: 24.12,
        ).copyWith(unlimitedRadius: true);
        final DiscoverQuery search = browse.copyWith(queryText: 'walk');

        // RD-05: the default feed has no Routes; a search for them does.
        final List<DiscoverItemEntity> defaults = (await tester.runAsync(
          () => repository.getFeed(browse),
        ))!;
        expect(defaults.any((DiscoverItemEntity e) => e.isRoute), isFalse);
        final List<DiscoverItemEntity> found = (await tester.runAsync(
          () => repository.getFeed(search),
        ))!;
        final DiscoverItemEntity pageCard = found.singleWhere(
          (DiscoverItemEntity e) => e.id == pageId,
        );
        final DiscoverItemEntity personalCard = found.singleWhere(
          (DiscoverItemEntity e) => e.id == personalId,
        );
        // Cards: preview only, gap open, no invented metric, publisher kind.
        final RouteCatalogFacts pageFacts = pageCard.routeCatalog!;
        expect(pageFacts.track, isNull);
        expect(
          pageFacts.preview.map((RouteCatalogSegment s) => s.connected),
          <bool>[false, false],
        );
        expect(pageFacts.gapCount, 1);
        expect(pageFacts.ascentMeters, isNull);
        expect(pageFacts.publisherKind, RouteCatalogPublisherKind.page);
        expect(pageCard.startsAtUtc, isNull);
        expect(pageCard.priceAmount, isNull);
        expect(pageCard.durationMinutes, isNull);
        expect(
          personalCard.routeCatalog!.publisherKind,
          RouteCatalogPublisherKind.personal,
        );
        expect(personalCard.routeCatalog!.ascentMeters, isNotNull);

        // Map: the same snapshot; the Page Route leaf carries its preview.
        final Map<String, Object?> map = (await tester.runAsync(
          () => port.query(<String, Object?>{
            'schemaVersion': 1,
            'requestId': const Uuid().v4(),
            'queryType': 'map',
            'payload': <String, Object?>{
              'query': session.query!,
              'snapshotToken': session.snapshotToken!,
            },
          }),
        ))!;
        final Map<Object?, Object?> leaf =
            ((map['map']! as Map)['leaves'] as List)
                .cast<Map<Object?, Object?>>()
                .singleWhere(
                  (Map<Object?, Object?> l) =>
                      (l['ref']! as Map)['contentId'] == pageId,
                );
        expect(leaf['preview'], isNotNull);
        expect(jsonEncode(map).contains('PRIVATE'), isFalse);

        // Details through the canonical lookup and the Route renderer.
        final DiscoverItemDetailsLookup lookup = DiscoverItemDetailsLookup(
          GetDiscoverDetailsUseCase(repository),
        );
        final DiscoverItemEntity details = (await tester
            .runAsync<DiscoverItemEntity?>(() => lookup.lookup(pageId)))!;
        expect(details.routeCatalog!.track, hasLength(2));
        expect(details.routeCatalog!.track!.last.connected, isFalse);
        void noop() {}
        RouteDetailsRenderer renderer(DiscoverItemEntity item) =>
            RouteDetailsRenderer(
              item: item,
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
        // Only the body is pumped, as in the Activity Catalog stand test: on a
        // PC host the integration binding has no Google Maps platform view.
        // The hero draws exactly `buildRouteSegmentPolylines(track)` (its
        // GoogleMap is covered by the widget test).
        Future<void> show(DiscoverItemEntity item) async {
          final RouteDetailsRenderer r = renderer(item);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Builder(builder: r.buildBody),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await show(details);
        expect(
          buildRouteSegmentPolylines(
            details.routeCatalog!.track!,
            idPrefix: 'stand',
          ),
          hasLength(2),
        );
        expect(find.text('Страница', skipOffstage: false), findsOneWidget);
        expect(
          find.text('Разрывов трека: 1', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Набор высоты', skipOffstage: false), findsNothing);
        expect(
          find.textContaining('Сообщить', skipOffstage: false),
          findsNothing,
        );
        expect(
          renderer(
            details,
          ).buildStickyAction(tester.element(find.byType(Scaffold))),
          isNull,
        );
        final DiscoverItemEntity personal = (await tester
            .runAsync<DiscoverItemEntity?>(() => lookup.lookup(personalId)))!;
        await show(personal);
        expect(find.text('Автор', skipOffstage: false), findsOneWidget);
        expect(find.text('Набор высоты', skipOffstage: false), findsOneWidget);
        expect(
          find.textContaining('PRIVATE', skipOffstage: false),
          findsNothing,
        );

        // Restart: a new runtime, session and repository read the same revision.
        final BookingTransportRuntime restarted = (await tester.runAsync(
          () => viewer('dtl-rte-02-viewer-restart'),
        ))!;
        final DiscoverItemEntity again = (await tester.runAsync(
          () => repositoryFor(
            portFor(restarted),
            CatalogSnapshotSession(),
          ).getDetails(pageId),
        ))!;
        expect(again.revisionRef, details.revisionRef);

        // Offline (the transport refuses): "Нет связи", nothing old is shown.
        Object? offline;
        await tester.runAsync(() async {
          try {
            await DiscoverItemDetailsLookup(
              GetDiscoverDetailsUseCase(
                repositoryFor(portFor(runtime, allowed: false), session),
              ),
            ).lookup(pageId);
          } on DiscoverException catch (error) {
            offline = error;
          }
        });
        expect(offline, isNotNull);
        await tester.pumpWidget(
          MaterialApp(
            home: DetailsShell(
              state: detailsUnavailableForError(offline!, onRetry: noop),
            ),
          ),
        );
        expect(find.text('Нет связи'), findsOneWidget);

        // A new revision: the listing's snapshot reports it, "Обновить" reads it.
        await tester.runAsync(() => stand!.routePageAction('page-revise'));
        await tester.runAsync(() => stand!.catalog(<String>['deliver']));
        Object? changed;
        await tester.runAsync(() async {
          try {
            await lookup.lookup(pageId);
          } on DiscoverException catch (error) {
            changed = error;
          }
        });
        expect((changed! as DiscoverException).code, routeRevisionChangedCode);
        await tester.pumpWidget(
          MaterialApp(
            home: DetailsShell(
              state: detailsUnavailableForError(changed!, onRetry: noop),
            ),
          ),
        );
        expect(find.text('Маршрут обновился'), findsOneWidget);
        expect(find.text('Обновить'), findsOneWidget);
        final DiscoverItemEntity revised = (await tester
            .runAsync<DiscoverItemEntity?>(() => lookup.lookup(pageId)))!;
        expect(revised.title, 'Riga two-part walk (stand Page, revised)');
        expect(revised.revisionRef, isNot(details.revisionRef));

        // Withdrawn: the exact id and the listing no longer show it.
        await tester.runAsync(() => stand!.routePageAction('page-withdraw'));
        await tester.runAsync(() => stand!.catalog(<String>['deliver']));
        expect(await tester.runAsync(() => lookup.lookup(pageId)), isNull);
        final List<DiscoverItemEntity> afterWithdraw = (await tester.runAsync(
          () => repository.getFeed(search),
        ))!;
        expect(
          afterWithdraw.any((DiscoverItemEntity e) => e.id == pageId),
          isFalse,
        );

        // Restored: listed again at the revised revision.
        await tester.runAsync(() => stand!.routePageAction('page-restore'));
        await tester.runAsync(() => stand!.catalog(<String>['deliver']));
        final List<DiscoverItemEntity> restored = (await tester.runAsync(
          () => repository.getFeed(search),
        ))!;
        expect(
          restored
              .singleWhere((DiscoverItemEntity e) => e.id == pageId)
              .revisionRef,
          revised.revisionRef,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() => temp.delete(recursive: true));
      }
    },
    skip: stand == null || !routeCatalogTestEntryDefined,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
