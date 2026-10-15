import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/server_library_repositories.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/library_composition.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/favorites/domain/entities/favorite_item_entity.dart';
import 'package:recharge/features/visited/domain/entities/visited_place_entity.dart';
import 'package:recharge/features/library/data/library_sync_client.dart';
import 'package:uuid/uuid.dart';
import 'support/stand_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['RECHARGE_G_LOCAL'] == '1';
  if (enabled) HttpOverrides.global = null;
  test(
    'two real Flutter Library adapters synchronize through separate Sessions',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('g-library-client-');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final placeId = Platform.environment['RECHARGE_G_PLACE_ID']!;
      Future<(LibrarySyncClient, BookingBackendBindingController)> client(
        String installation,
      ) async {
        final binding = BookingBackendBindingController(
          emulatorBase: StandBackend.functionsBase,
          releaseMode: false,
          initial: BackendBindingMode.testBackend,
        );
        final http = CountingClient();
        addTearDown(http.close);
        final runtime = await BookingTransportRuntimeFactory(
          endpoint: binding.endpoint,
          client: http,
          tokens: AuthEmulatorTokenProvider('stand-user-library-g'),
          sessions: FileSessionStore(
            File('${temp.path}/$installation-session.json'),
          ),
          installations: FixedInstallationId(installation),
          supportDirectory: () => Directory(
            '${temp.path}/$installation-support',
          ).create(recursive: true),
        ).create();
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
        return (
          LibrarySyncClient(
            invoke: libraryInvoke(
              binding: binding,
              runtime: () async => runtime,
            ),
            storage: const FlutterSecureStorage(),
          ),
          binding,
        );
      }

      final (a, bindingA) = await client('g-mobile-client-a');
      final (b, _) = await client('g-mobile-client-b');
      final favoritesA = ServerFavoritesRepository(a),
          favoritesB = ServerFavoritesRepository(b);
      final visitsA = ServerVisitedPlacesRepository(a),
          visitsB = ServerVisitedPlacesRepository(b);
      await favoritesA.addFavorite(
        FavoriteItemEntity(
          id: placeId,
          objectType: 'place',
          title: 'Client title must not become authority',
          subtitle: '',
          city: '',
          category: '',
          startsAtUtc: null,
          distanceKm: 0,
          priceAmount: null,
          isFree: false,
          savedAtUtc: DateTime.now().toUtc(),
          targetRoute: null,
        ),
      );
      final saved = await favoritesB.getFavorites();
      expect(saved.single.title, 'Synthetic library target');
      expect(saved.single.objectType, 'place');
      expect(await visitsB.getVisitedPlaces(userId: 'local-profile'), isEmpty);
      await favoritesB.removeFavorite(placeId);
      expect(await favoritesA.getFavorites(), isEmpty);
      final visit = VisitedPlaceEntity(
        id: const Uuid().v4(),
        userId: 'local-profile',
        placeId: placeId,
        title: '',
        subtitle: '',
        city: '',
        category: '',
        visitedOn: DateTime(2026, 1, 3),
        timezoneId: 'Pacific/Honolulu',
        evidence: VisitEvidence.selfReported,
        recordedAtUtc: DateTime.now().toUtc(),
      );
      await visitsA.recordVisit(visit);
      await visitsA.recordVisit(visit);
      final history = await visitsB.getVisitedPlaces(userId: 'local-profile');
      expect(history, hasLength(1));
      expect(history.single.timezoneId, 'Europe/Riga');
      expect(history.single.localDayKey, '2026-01-03');
      await visitsB.removeVisit(
        userId: 'local-profile',
        visitId: history.single.id,
      );
      expect(await visitsA.getVisitedPlaces(userId: 'local-profile'), isEmpty);
      bindingA.activate(BackendBindingMode.localOnly);
      await expectLater(a.refresh(), throwsA(isA<LibraryFailure>()));
    },
    skip: enabled
        ? false
        : 'Run the Library Emulator group with RECHARGE_G_MOBILE=1.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
