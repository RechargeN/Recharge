import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/build_rental_content_body.dart';

import '../fixtures/create/user_rental_draft.dart';

/// D3.3 §4: the Create Rental draft mapped to the public Content Rental body.
/// Listing photos come from the shared Create media; the attestation and the
/// blocks carry this account's server id only for this account's own
/// confirmations (Q3); local ids become UUIDv5; the output equals the shared
/// compatibility fixture.
void main() {
  const RentalContentBodyMapper mapper = RentalContentBodyMapper();

  RentalContentBody map(
    CreateDraftEntity draft, {
    String account = compatAccountId,
    Map<String, String>? assets,
  }) => mapper.map(
    draft,
    scope: compatScope(),
    localAccountId: account,
    serverActorUserId: compatServerActor,
    assetIds: assets ?? compatAssetIds(),
  );

  CreateDraftEntity base() => rentalCompatCases['valid']!();
  CreateDraftEntity withRental(RentalDraftData Function(RentalDraftData) f) =>
      base().copyWith(rentalData: f(base().rentalData!));
  Map<String, Object?> part(Map<String, Object?> body, String key) =>
      body[key]! as Map<String, Object?>;

  group('compatibility fixture', () {
    final Map<String, Object?> fixture =
        jsonDecode(
              File(
                '../../packages/api_contracts/schema/content/v1/fixtures/'
                'rental_create_compat.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final List<Map<String, Object?>> cases =
        (fixture['cases']! as List<Object?>).cast<Map<String, Object?>>();

    test('covers exactly the Create cases of the fixture builder', () {
      expect(fixture['typeId'], 'rental');
      expect(fixture['actorUserId'], compatServerActor);
      expect(
        cases.map((item) => item['name']).toList(),
        rentalCompatCases.keys.toList(),
      );
    });

    for (final Map<String, Object?> item in cases) {
      test('the mapper produces the fixture body of "${item['name']}"', () {
        final RentalContentBody mapped = map(
          rentalCompatCases[item['name']! as String]!(),
        );
        expect(mapped.unsupported, isEmpty);
        expect(jsonDecode(jsonEncode(mapped.body)), item['body']);
      });
    }
  });

  group('field table (§4)', () {
    test('the listing photos are the shared Create media, cover first', () {
      final Map<String, Object?> body = map(base()).body;
      expect(body['mediaRefs'], <String>[
        'asset-cover',
        'asset-gallery-1',
        'asset-gallery-2',
      ]);
      // Before upload the photos are placeholders of their attachment ids.
      expect(
        (map(base(), assets: const <String, String>{}).body['mediaRefs']!
                as List<Object?>)
            .first,
        'loc_${compatScope().coverAttachmentId}',
      );
      // Without a cover nothing is invented: the server keeps cover_required.
      expect(
        map(
          base().copyWith(
            media: const MediaEntity(coverImage: '', gallery: <String>[]),
          ),
        ).body['mediaRefs'],
        isEmpty,
      );
    });

    test('Q3: this account\'s confirmations carry its server id', () {
      final Map<String, Object?> body = map(base()).body;
      expect(part(body, 'attestation')['acceptedByUserId'], compatServerActor);
      final Map<String, Object?> block =
          (part(body, 'availability')['blocks']! as List<Object?>).single!
              as Map<String, Object?>;
      expect(block['createdByUserId'], compatServerActor);
      // Create counts block revisions from 0, the contract from 1.
      expect(block['revision'], 1);
    });

    test('the block revision is a wire renumbering: the draft stays 0, '
        'every mapping sends 1', () {
      final CreateDraftEntity draft = base();
      int sent(RentalContentBody mapped) =>
          ((part(mapped.body, 'availability')['blocks']! as List<Object?>)
                      .single!
                  as Map<String, Object?>)['revision']!
              as int;
      final RentalContentBody first = map(draft);
      final RentalContentBody second = map(draft);
      expect(sent(first), 1);
      expect(sent(second), 1);
      expect(jsonEncode(first.body), jsonEncode(second.body));
      // The draft itself is never changed by the mapping.
      expect(draft.rentalData!.availability.blocks.single.revision, 0);
      // A block already revised once in Create (revision 1) is sent as 2.
      final CreateDraftEntity revised = withRental(
        (rental) => rental.copyWith(
          availability: rental.availability.copyWith(
            blocks: <RentalAvailabilityBlock>[
              rental.availability.blocks.single.copyWith(revision: 1),
            ],
          ),
        ),
      );
      expect(sent(map(revised)), 2);
    });

    test('an approximate area never carries an address; disabled delivery '
        'carries no children', () {
      final Map<String, Object?> handover = part(
        map(
          withRental(
            (rental) => rental.copyWith(
              handover: rental.handover.copyWith(
                publicAddress: 'Kipsalas iela 1',
                deliveryRadiusKm: 10,
                deliveryTerms: 'left over from an earlier choice',
              ),
            ),
          ),
        ).body,
        'handover',
      );
      expect(handover.containsKey('publicAddress'), isFalse);
      expect(handover['deliveryAvailable'], isFalse);
      expect(handover.containsKey('deliveryRadiusKm'), isFalse);
      expect(handover.containsKey('deliveryTerms'), isFalse);
    });

    test('weekly opening hours get stable ids; overnight closes next day', () {
      final Map<String, Object?> handover = part(
        map(
          withRental(
            (rental) => rental.copyWith(
              handover: rental.handover.copyWith(
                scheduleMode: RentalScheduleMode.openingHours,
                openingHours: const <CreateOpeningHoursDraftRule>[
                  CreateOpeningHoursDraftRule(
                    dayOfWeek: 6,
                    isClosedAllDay: false,
                    openMinutesSinceLocalMidnight: 1200,
                    closeMinutesSinceLocalMidnight: 120,
                  ),
                ],
              ),
            ),
          ),
        ).body,
        'handover',
      );
      expect(handover['scheduleMode'], 'opening_hours');
      expect(handover['openingHours'], <Map<String, Object?>>[
        <String, Object?>{
          'id': compatScope().hoursId(0),
          'dayOfWeek': 6,
          'openMinute': 1200,
          'closeMinute': 120,
          'closesNextDay': true,
        },
      ]);
    });

    test('the public body has no private authoring field', () {
      final String json = jsonEncode(map(base()).body);
      for (final String key in <String>[
        'privateAuthoring',
        'exactPickupAddress',
        'exactPickupGeo',
        'handoverInstructions',
        'inventoryNotesByGroupId',
        'availabilityNotesByBlockId',
        'publisherRef',
      ]) {
        expect(json.contains('"$key"'), isFalse, reason: key);
      }
    });
  });

  group('not sent at all (§2 Q2, Q3)', () {
    test('another user\'s attestation or block is never rewritten', () {
      expect(map(base(), account: 'someone-else').unsupported, <String>[
        'rental.attestation_foreign',
        'rental.block_foreign',
      ]);
    });

    test('listing media or group photos the form does not edit', () {
      expect(
        map(
          withRental(
            (rental) => rental.copyWith(mediaRefs: <String>['old-asset']),
          ),
        ).unsupported,
        <String>['rental.listing_media'],
      );
      expect(
        map(
          withRental(
            (rental) => rental.copyWith(
              inventoryGroups: <RentalInventoryGroup>[
                rental.inventoryGroups.single.copyWith(
                  photoRefs: <String>['C:/photos/group.png'],
                ),
              ],
            ),
          ),
        ).unsupported,
        <String>['rental.group_photos'],
      );
    });

    test('date exceptions in opening hours and newer draft fields', () {
      expect(
        map(
          withRental(
            (rental) => rental.copyWith(
              handover: rental.handover.copyWith(
                scheduleMode: RentalScheduleMode.openingHours,
                openingHours: const <CreateOpeningHoursDraftRule>[
                  CreateOpeningHoursDraftRule(
                    exceptionDateIso: '2026-12-24',
                    isClosedAllDay: true,
                  ),
                ],
              ),
            ),
          ),
        ).unsupported,
        <String>['rental.hours_exceptions'],
      );
      expect(
        map(
          withRental(
            (rental) => rental.copyWith(
              unknownFields: <String, Object?>{'futureField': 1},
            ),
          ),
        ).unsupported,
        <String>['unknown_fields'],
      );
    });

    test('a non-Rental draft is not mapped', () {
      expect(
        () => map(base().copyWith(objectType: CreateObjectType.place)),
        throwsArgumentError,
      );
    });
  });

  group('ids and keys (§4)', () {
    test('namespace and scope give the independently computed UUIDv5', () {
      expect(
        RentalPublicationScope.namespace,
        '9e258ab9-3a98-4009-aa3e-4005091488aa',
      );
      final RentalPublicationScope scope = compatScope();
      expect(
        scope.value,
        'recharge:rental-publication:v1:account-compat-1:page:'
        'page-compat-1:local-rental-compat-1',
      );
      // Computed with Python's uuid.uuid5 for the same namespace and name.
      expect(scope.coverAttachmentId, '2ca7b919-5b3e-532b-8457-66ff09db11ff');
      expect(
        scope.groupId('loc_group_kayak'),
        '425f2542-795c-5220-a6d6-d7c58cb7ad34',
      );
      expect(
        scope.blockId('loc_block_maintenance'),
        '5404ee23-ecc8-5de1-9e4b-35373093ab7f',
      );
      expect(scope.keyBase, matches(RegExp(r'^rp1-[0-9a-f]{24}$')));
    });

    test('local ids are replaced and the block points to its group', () {
      final Map<String, Object?> body = map(base()).body;
      expect(jsonEncode(body).contains('loc_'), isFalse);
      final String groupId =
          ((body['inventoryGroups']! as List<Object?>).single!
                  as Map<String, Object?>)['id']!
              as String;
      final Map<String, Object?> block =
          (part(body, 'availability')['blocks']! as List<Object?>).single!
              as Map<String, Object?>;
      expect(block['groupId'], groupId);
      expect(jsonEncode(body), jsonEncode(map(base()).body));
    });
  });
}
