import 'package:test/test.dart';

import 'support/booking_schema_fixture_validator.dart';
import 'support/booking_semantic_hash.dart';

void main() {
  final vectors = readJsonObject(
    '$bookingSchemaRoot/fixtures/semantic_hash_vectors.json',
  );
  final invalid = readJsonObject(
    '$bookingSchemaRoot/fixtures/semantic_hash_invalid.json',
  );

  test('shared vectors freeze projection, canonical bytes and SHA-256', () {
    final results = <String, BookingSemanticHashResult>{};
    for (final vector in readObjectList(vectors, 'vectors')) {
      final result = computeBookingSemanticHash(
        rawCommandJson: vector['rawCommandJson']! as String,
        resolvedActorScope: (vector['resolvedActorScope']! as Map)
            .cast<String, Object?>(),
      );
      expect(
        result.projection,
        vector['expectedProjection'],
        reason: vector['id']! as String,
      );
      expect(
        result.canonicalHex,
        vector['expectedCanonicalHex'],
        reason: vector['id']! as String,
      );
      expect(
        result.digest,
        vector['expectedDigest'],
        reason: vector['id']! as String,
      );
      results[vector['id']! as String] = result;
    }

    expect(
      results['key-order-a']!.digest,
      results['key-order-b-request-change']!.digest,
    );
    expect(
      results['nested-unicode-nfc-literal']!.digest,
      results['nested-unicode-nfc-escaped']!.digest,
    );
    expect(
      results['nested-unicode-nfc-literal']!.digest,
      isNot(results['unicode-nfd-distinct']!.digest),
    );
    expect(
      results['booking-revision-7']!.digest,
      isNot(results['booking-revision-8']!.digest),
    );
    expect(
      results['event-revision-11']!.digest,
      isNot(results['event-revision-12']!.digest),
    );
    expect(results['idempotency-a']!.digest, results['idempotency-b']!.digest);
    expect(
      results['idempotency-a']!.logicalIdentity,
      isNot(results['idempotency-b']!.logicalIdentity),
    );
  });

  test('raw invalid vectors fail before hashing', () {
    for (final fixture in readObjectList(invalid, 'cases')) {
      expect(
        () => computeBookingSemanticHash(
          rawCommandJson: fixture['rawCommandJson']! as String,
          resolvedActorScope: (fixture['resolvedActorScope']! as Map)
              .cast<String, Object?>(),
        ),
        throwsFormatException,
        reason: '${fixture['id']}: ${fixture['reason']}',
      );
    }
  });
}
