import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/build_activity_content_body.dart';

import '../fixtures/create/user_activity_draft.dart';

/// D3.2 §5.2, §5.3, §5.5: the Create Recharge Activity draft mapped to the
/// Content Activity body. Strings are trimmed and empty optionals left out; a
/// linked Place is never sent (§2.4); ids are UUIDv5 under the
/// account/publisher/draft scope; the output equals the shared compatibility
/// fixture.
void main() {
  const ActivityContentBodyMapper mapper = ActivityContentBodyMapper();

  ActivityContentBody map(
    CreateDraftEntity draft, {
    ActivityPublicationScope? scope,
    Map<String, String>? assets,
  }) => mapper.map(
    draft,
    scope: scope ?? compatScope(),
    assetIds: assets ?? compatAssetIds(),
  );

  CreateDraftEntity base() => activityCompatCases['valid']!();
  ActivityDraftData activity(CreateDraftEntity draft) => draft.activityData!;
  CreateDraftEntity withActivity(
    ActivityDraftData Function(ActivityDraftData value) change,
  ) => base().copyWith(activityData: change(activity(base())));
  Map<String, Object?> location(Map<String, Object?> body) =>
      body['location']! as Map<String, Object?>;

  test(
    'explicit linked Place capability maps only the ID and preserves own location',
    () {
      final draft = withActivity(
        (value) => value.copyWith(
          location: value.location.copyWith(
            linkedPlaceId: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
          ),
        ),
      );
      expect(map(draft).unsupported, contains('location.linked_place'));
      final mapped = const ActivityContentBodyMapper(
        allowLinkedPlace: true,
      ).map(draft, scope: compatScope(), assetIds: compatAssetIds());
      expect(mapped.unsupported, isEmpty);
      expect(
        location(mapped.body)['linkedPlaceId'],
        '01ARZ3NDEKTSV4RRFFQ69G5FAV',
      );
      final own = Map<String, Object?>.from(location(mapped.body))
        ..remove('linkedPlaceId');
      expect(own, location(map(base()).body));
    },
  );

  group('compatibility fixture', () {
    final Map<String, Object?> fixture =
        jsonDecode(
              File(
                '../../packages/api_contracts/schema/content/v1/fixtures/'
                'activity_create_compat.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final List<Map<String, Object?>> cases =
        (fixture['cases']! as List<Object?>).cast<Map<String, Object?>>();

    test('covers exactly the Create cases of the fixture builder', () {
      expect(fixture['typeId'], 'activity');
      expect(
        cases.map((item) => item['name']).toList(),
        activityCompatCases.keys.toList(),
      );
    });

    for (final Map<String, Object?> item in cases) {
      test('the mapper produces the fixture body of "${item['name']}"', () {
        final ActivityContentBody mapped = map(
          activityCompatCases[item['name']! as String]!(),
        );
        expect(mapped.unsupported, isEmpty);
        // Through JSON, as the transport sends it.
        expect(jsonDecode(jsonEncode(mapped.body)), item['body']);
      });
    }
  });

  group('field table (§5.2)', () {
    test('maps the accepted draft section by section', () {
      final Map<String, Object?> body = map(base()).body;
      expect(body['title'], 'Ķemeri bog boardwalk loop');
      expect(body['categoryId'], 'outdoor_nature_walking');
      expect(body['subcategoryId'], 'forest_walk');
      expect(body['criteria'], <String, Object?>{'difficulty': 'easy'});
      expect(location(body), <String, Object?>{
        'latitude': 56.9142,
        'longitude': 23.4706,
        'pinConfirmed': true,
        'addressLine': 'Ķemeri National Park, Jūrmala',
        'accessNotes': 'Start at the car park by the visitor trail sign',
      });
      expect(body['typicalDurationMinutes'], <String, Object?>{
        'min': 60,
        'max': 120,
      });
      expect(body['suggestedGroupSize'], <String, Object?>{'min': 1, 'max': 6});
      expect(body['bestTime'], <String, Object?>{
        'timeOfDay': 'morning',
        'season': 'any',
      });
      // Only Activity's own contract: no publisher, schedule, booking or tags.
      for (final String key in <String>[
        'publisherRef',
        'schedule',
        'booking',
        'pricing',
        'tags',
        'optionalContribution',
        'fullDescription',
      ]) {
        expect(body.containsKey(key), isFalse, reason: key);
      }
    });

    test('trims strings and leaves empty optionals out', () {
      final Map<String, Object?> body = map(
        base()
            .copyWith(
              title: '  Ķemeri bog boardwalk loop  ',
              fullDescription: '   ',
            )
            .copyWith(
              activityData: activity(base()).copyWith(
                location: const ActivityLocationDraft(
                  latitude: 56.9142,
                  longitude: 23.4706,
                  pinConfirmed: true,
                  addressLine: '  ',
                  accessNotes: '  Start at the car park  ',
                ),
                bestTime: const ActivityBestTimeDraft(),
              ),
            ),
      ).body;
      expect(body['title'], 'Ķemeri bog boardwalk loop');
      expect(body.containsKey('fullDescription'), isFalse);
      expect(body.containsKey('bestTime'), isFalse);
      expect(location(body).containsKey('addressLine'), isFalse);
      expect(location(body)['accessNotes'], 'Start at the car park');
    });

    test('a caution that is not informal and has no note is no caution', () {
      ActivityLocationDraft cautioned(ActivityAccessCautionDraft caution) =>
          ActivityLocationDraft(
            latitude: 56.9142,
            longitude: 23.4706,
            pinConfirmed: true,
            accessNotes: 'Start at the car park by the sign',
            accessCaution: caution,
          );
      Map<String, Object?> sent(ActivityAccessCautionDraft caution) => location(
        map(
          withActivity((value) => value.copyWith(location: cautioned(caution))),
        ).body,
      );
      expect(
        sent(
          const ActivityAccessCautionDraft(isInformal: false, note: ' '),
        ).containsKey('accessCaution'),
        isFalse,
      );
      expect(
        sent(
          const ActivityAccessCautionDraft(
            isInformal: true,
            note: '  Private land, stay on the path  ',
          ),
        )['accessCaution'],
        <String, Object?>{
          'isInformal': true,
          'note': 'Private land, stay on the path',
        },
      );
      // Informal without a note is sent as it is; the server refuses it.
      expect(
        sent(
          const ActivityAccessCautionDraft(isInformal: true),
        )['accessCaution'],
        <String, Object?>{'isInformal': true},
      );
    });

    test('a contribution is sent only when it holds something', () {
      Map<String, Object?> body(ActivityOptionalContributionDraft value) => map(
        withActivity((draft) => draft.copyWith(optionalContribution: value)),
      ).body;
      expect(
        body(
          const ActivityOptionalContributionDraft(note: '  '),
        ).containsKey('optionalContribution'),
        isFalse,
      );
      expect(
        body(
          const ActivityOptionalContributionDraft(
            kind: ActivityContributionKind.donation,
            note: ' Leave a coin in the box ',
            amountHint: ActivityContributionAmountDraft(
              amountMinor: 200,
              currencyCode: 'EUR',
            ),
          ),
        )['optionalContribution'],
        <String, Object?>{
          'kind': 'donation',
          'note': 'Leave a coin in the box',
          'amountHint': <String, Object?>{
            'amountMinor': 200,
            'currencyCode': 'EUR',
          },
        },
      );
    });
  });

  group('not sent at all (§2.4, §5.3)', () {
    test('a linked Place: the server cannot resolve it yet', () {
      final ActivityContentBody mapped = map(
        withActivity(
          (value) => value.copyWith(
            location: value.location.copyWith(
              linkedPlaceId: '01HZZZZZZZZZZZZZZZZZZZZZZZ',
            ),
          ),
        ),
      );
      expect(mapped.unsupported, <String>['location.linked_place']);
      expect(location(mapped.body).containsKey('linkedPlaceId'), isFalse);
    });

    test('tags, which the Activity contract does not carry', () {
      expect(map(base().copyWith(tags: <String>['bog'])).unsupported, <String>[
        'tags',
      ]);
    });

    test('fields of a newer draft schema', () {
      expect(
        map(
          withActivity(
            (value) => value.copyWith(
              unknownFields: <String, Object?>{'futureField': 1},
            ),
          ),
        ).unsupported,
        <String>['unknown_fields'],
      );
    });

    test('a non-Activity draft is not mapped', () {
      expect(
        () => map(base().copyWith(objectType: CreateObjectType.place)),
        throwsArgumentError,
      );
    });
  });

  group('ids and keys (§5.5)', () {
    test('namespace and scope give the independently computed UUIDv5', () {
      expect(
        ActivityPublicationScope.namespace,
        '82167158-6d3c-4536-aec4-b7f4f12b012b',
      );
      final ActivityPublicationScope scope = compatScope();
      expect(
        scope.value,
        'recharge:activity-publication:v1:account-compat-1:page:'
        'page-compat-1:local-activity-compat-1',
      );
      // Computed with Python's uuid.uuid5 for the same namespace and name.
      expect(scope.coverAttachmentId, '1255ee50-882b-5818-ab76-cf423091f990');
      expect(
        scope.galleryAttachmentId('C:/photos/bog-1.png'),
        '1d070e2d-4bea-5f5e-a9a2-9c3410564803',
      );
      expect(scope.keyBase, matches(RegExp(r'^ap1-[0-9a-f]{24}$')));
    });

    test('with assets no loc_ id is left, and a remap is identical', () {
      final Map<String, Object?> first = map(base()).body;
      expect(jsonEncode(first), jsonEncode(map(base()).body));
      expect(jsonEncode(first).contains('loc_'), isFalse);
    });

    test(
      'before upload the media are loc_ placeholders of their attachment ids',
      () {
        final ActivityContentBody mapped = map(
          base(),
          assets: const <String, String>{},
        );
        final Map<String, Object?> media =
            mapped.body['media']! as Map<String, Object?>;
        expect(
          (media['coverImage']! as Map<String, Object?>)['mediaId'],
          'loc_${compatScope().coverAttachmentId}',
        );
        expect(mapped.attachments.map((item) => item.role).toList(), <String>[
          'cover',
          'gallery',
          'gallery',
        ]);
      },
    );

    test('reordering the gallery keeps every attachment id', () {
      final CreateDraftEntity draft = base();
      final CreateDraftEntity reordered = draft.copyWith(
        media: MediaEntity(
          coverImage: draft.media.coverImage,
          gallery: draft.media.gallery.reversed.toList(),
        ),
      );
      final Map<String, String> before = <String, String>{
        for (final ActivityMediaAttachment item in map(draft).attachments)
          item.localRef: item.attachmentId,
      };
      for (final ActivityMediaAttachment item in map(reordered).attachments) {
        expect(item.attachmentId, before[item.localRef]);
      }
      // The body follows the draft's order.
      final Map<String, Object?> media =
          map(reordered).body['media']! as Map<String, Object?>;
      expect(
        (media['gallery']! as List<Object?>)
            .map((item) => (item! as Map<String, Object?>)['mediaId'])
            .toList(),
        <String>['asset-gallery-2', 'asset-gallery-1'],
      );
    });

    test('another account, publisher or draft never shares an id', () {
      final ActivityPublicationScope scope = compatScope();
      final List<ActivityPublicationScope> others = <ActivityPublicationScope>[
        ActivityPublicationScope(
          accountId: 'another-account',
          publisherRef: scope.publisherRef,
          localDraftId: scope.localDraftId,
        ),
        ActivityPublicationScope(
          accountId: scope.accountId,
          publisherRef: const PublisherRef(
            type: PublisherType.user,
            id: 'page-compat-1',
          ),
          localDraftId: scope.localDraftId,
        ),
        ActivityPublicationScope(
          accountId: scope.accountId,
          publisherRef: scope.publisherRef,
          localDraftId: 'another-draft',
        ),
      ];
      for (final ActivityPublicationScope other in others) {
        expect(other.coverAttachmentId, isNot(scope.coverAttachmentId));
        expect(other.keyBase, isNot(scope.keyBase));
      }
    });

    test('an upload id changes with the bytes, not with the attempt', () {
      final ActivityPublicationScope scope = compatScope();
      final String attachment = scope.galleryAttachmentId(compatGallery[0]);
      expect(
        scope.uploadIntentId(attachment, 'aa'),
        scope.uploadIntentId(attachment, 'aa'),
      );
      expect(
        scope.uploadIntentId(attachment, 'aa'),
        isNot(scope.uploadIntentId(attachment, 'bb')),
      );
    });
  });
}
