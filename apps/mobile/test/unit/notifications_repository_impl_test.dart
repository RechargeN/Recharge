import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/features/notifications/data/datasources/notifications_local_datasource.dart';
import 'package:recharge/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:recharge/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';

/// `DTL-LINK-01` §3.4/AC-04: the two previously-hardcoded
/// `/discover/details/place-1` seed notifications must build their link
/// via `CatalogObjectRef`, not as a raw string.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test(
    'seeded place-subject notifications carry the typed canonical link',
    () async {
      final repository = NotificationsRepositoryImpl(
        localDataSource: NotificationsLocalDataSource(FlutterSecureStorage()),
      );

      final List<NotificationItemEntity> items = await repository
          .getNotifications(userId: 'user-1');

      final List<NotificationItemEntity> placeSubjectItems = items
          .where(
            (NotificationItemEntity item) =>
                item.subjectRef?.kind == NotificationSubjectKind.place,
          )
          .toList(growable: false);
      expect(placeSubjectItems, isNotEmpty);

      final String expectedRoute = RouteNames.discoverDetailsCanonicalFor(
        const CatalogObjectRef(
          objectType: CatalogObjectType.place,
          objectId: 'place-1',
        ),
      );
      // The canonical link is a real, typed path — not a coincidental
      // match to the pre-DTL-LINK-01 hardcoded string.
      expect(expectedRoute, '/discover/details/place/place-1');

      for (final NotificationItemEntity item in placeSubjectItems) {
        expect(item.targetRoute, expectedRoute);
        expect(item.targetRoute, isNot('/discover/details/place-1'));
      }
    },
  );
}
