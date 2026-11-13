import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/models/catalog_wire_models.dart';

void main() {
  test('the envelope needs schema version 1 and exactly one success body', () {
    expect(
      () =>
          CatalogAnswer.fromWire(const <String, Object?>{'kind': 'succeeded'}),
      throwsFormatException,
    );
    expect(
      () => CatalogAnswer.fromWire(const <String, Object?>{
        'schemaVersion': 1,
        'kind': 'succeeded',
      }),
      throwsFormatException,
    );
    final CatalogAnswer refusal = CatalogAnswer.fromWire(
      const <String, Object?>{
        'schemaVersion': 1,
        'kind': 'rejected',
        'code': 'feature_disabled',
      },
    );
    expect(refusal.succeeded, isFalse);
    expect(refusal.code, 'feature_disabled');
  });

  test('Details carries an item only when listed', () {
    final CatalogDetails excluded = CatalogDetails.fromWire(
      const <String, Object?>{
        'state': 'excluded',
        'reason': 'restricted',
        'item': <String, Object?>{'leaked': true},
        'changedSinceSnapshot': true,
      },
    );
    expect(excluded.item, isNull);
    expect(excluded.reason, 'restricted');
    expect(
      () => CatalogDetails.fromWire(const <String, Object?>{
        'state': 'visible',
        'changedSinceSnapshot': false,
      }),
      throwsFormatException,
    );
  });

  test('unknown or partial shapes are refused, never guessed', () {
    expect(
      () => CatalogPrice.read(const <String, Object?>{'mode': 'donation'}),
      throwsFormatException,
    );
    expect(
      () => CatalogPrice.read(const <String, Object?>{
        'mode': 'fixed',
        'amountMinor': 1.5,
        'currencyCode': 'EUR',
      }),
      throwsFormatException,
    );
    expect(
      () => CatalogPoint.read(const <String, Object?>{'latitude': 56.9}),
      throwsFormatException,
    );
    expect(CatalogPoint.read(null), isNull);
    expect(CatalogPrice.read(null), isNull);
    expect(
      () => CatalogFeedPage.fromWire(const <String, Object?>{
        'snapshotToken': 's',
        'projectionSetRevision': 1,
        'items': <Object?>[
          <String, Object?>{
            'ref': <String, Object?>{'typeId': 'place', 'contentId': 'p'},
          },
        ],
        'nextCursor': null,
      }),
      throwsFormatException,
    );
  });
}
