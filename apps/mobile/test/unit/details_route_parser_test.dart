import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/application/resolve_details_usecase.dart';
import 'package:recharge/app/router/details_route_parser.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';

/// `docs/product/DTL_LINK_01_DEEP_LINK_MIGRATION_SLICE_SPEC.md` §1.1.6/§3.4:
/// the parser recognizes the canonical shape and both legacy shapes
/// byte-for-byte, and resolves nothing itself.
void main() {
  group('parseDetailsRoutePath — canonical shape', () {
    test('/discover/details/:objectType/:objectId', () {
      final DetailsRouteTarget? target = parseDetailsRoutePath(
        '/discover/details/place/abc-123',
      );

      expect(target, isA<DetailsRouteTargetRef>());
      final CatalogObjectRef ref = (target as DetailsRouteTargetRef).ref;
      expect(ref.objectType, CatalogObjectType.place);
      expect(ref.objectId, 'abc-123');
    });

    test('accepts the bare enum-name form for a compound type', () {
      final DetailsRouteTarget? target = parseDetailsRoutePath(
        '/discover/details/findPeople/fp-1',
      );

      expect(target, isA<DetailsRouteTargetRef>());
      expect(
        (target as DetailsRouteTargetRef).ref.objectType,
        CatalogObjectType.findPeople,
      );
    });

    test('unknown objectType segment is a routing miss, not a guess', () {
      expect(parseDetailsRoutePath('/discover/details/not-a-type/abc'), isNull);
    });

    test('empty objectId segment is a routing miss', () {
      expect(parseDetailsRoutePath('/discover/details/place/'), isNull);
    });
  });

  group('parseDetailsRoutePath — legacy shapes', () {
    test('/discover/details/:itemId (no explicit type)', () {
      final DetailsRouteTarget? target = parseDetailsRoutePath(
        '/discover/details/evt_1',
      );

      expect(target, isA<DetailsRouteTargetLegacyDiscoverItem>());
      expect(
        (target as DetailsRouteTargetLegacyDiscoverItem).itemId,
        'evt_1',
      );
    });

    test('query parameters do not affect legacy discover parsing', () {
      final DetailsRouteTarget? target = parseDetailsRoutePath(
        '/discover/details/evt_1?favoriteApplied=1',
      );

      expect(target, isA<DetailsRouteTargetLegacyDiscoverItem>());
      expect(
        (target as DetailsRouteTargetLegacyDiscoverItem).itemId,
        'evt_1',
      );
    });

    test('/collection/details/:collectionId', () {
      final DetailsRouteTarget? target = parseDetailsRoutePath(
        '/collection/details/col_1',
      );

      expect(target, isA<DetailsRouteTargetLegacyCollection>());
      expect(
        (target as DetailsRouteTargetLegacyCollection).collectionId,
        'col_1',
      );
    });

    test('trailing slash with no id is a routing miss, not a crash', () {
      expect(parseDetailsRoutePath('/discover/details/'), isNull);
      expect(parseDetailsRoutePath('/collection/details/'), isNull);
    });
  });

  group('parseDetailsRoutePath — unrelated paths', () {
    test('a path outside both prefixes returns null', () {
      expect(parseDetailsRoutePath('/favorites'), isNull);
      expect(parseDetailsRoutePath('/discover/map'), isNull);
    });
  });

  group('catalogObjectTypeFromTaxonomyId', () {
    test('parses every stable taxonomyId', () {
      for (final CatalogObjectType type in CatalogObjectType.values) {
        expect(catalogObjectTypeFromTaxonomyId(type.taxonomyId), type);
      }
    });

    test('parses the bare enum .name form too (case-insensitively)', () {
      expect(
        catalogObjectTypeFromTaxonomyId('classWorkshop'),
        CatalogObjectType.classWorkshop,
      );
      expect(
        catalogObjectTypeFromTaxonomyId('CLASSWORKSHOP'),
        CatalogObjectType.classWorkshop,
      );
    });

    test('an unrecognized string returns null, never a guessed type', () {
      expect(catalogObjectTypeFromTaxonomyId('quick_plan'), isNull);
      expect(catalogObjectTypeFromTaxonomyId('nonsense'), isNull);
    });
  });
}
