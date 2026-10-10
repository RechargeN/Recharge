import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/place_create_config.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/place_creation_policy.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/build_place_content_body.dart';
import 'package:recharge/shared/primitives/money/money.dart';

import '../fixtures/create/user_place_draft.dart';

/// D3.1 §5.2, §5.3, §5.5: the Create Place draft mapped to the Content Place
/// body. Only what the Create form treats as active is sent; inactive values
/// stay in the local draft; ids are UUIDv5 under the account/publisher/draft
/// scope; the output equals the shared compatibility fixture.
void main() {
  const PlaceContentBodyMapper mapper = PlaceContentBodyMapper();

  PlaceContentBody map(
    CreateDraftEntity draft, {
    PlaceCreationPolicy? policy,
    PlacePublicationScope? scope,
    Map<String, String>? assets,
  }) => mapper.map(
    draft,
    scope: scope ?? compatScope(),
    policy: policy ?? placeCreationPolicyFor(draft.subcategory),
    serverOwnerUserId: compatServerOwner,
    assetIds: assets ?? compatAssetIds(),
  );

  CreateDraftEntity base() => placeCompatCases['valid']!();
  PlaceDraftData place(CreateDraftEntity draft) => draft.placeData!;

  /// Every field visible; each test hides what it needs.
  PlaceCreationPolicy policy({
    PlaceFieldRequirement hours = PlaceFieldRequirement.optional,
    PlaceFieldRequirement admission = PlaceFieldRequirement.optional,
    PlaceFieldRequirement typicalSpend = PlaceFieldRequirement.optional,
    PlaceFieldRequirement visitPlanning = PlaceFieldRequirement.optional,
    PlaceFieldRequirement amenities = PlaceFieldRequirement.optional,
    PlaceFieldRequirement contacts = PlaceFieldRequirement.optional,
    PlaceFieldRequirement booking = PlaceFieldRequirement.optional,
    PlaceFieldRequirement accessNote = PlaceFieldRequirement.optional,
  }) => PlaceCreationPolicy(
    id: PlaceCreationProfileId.balanced,
    label: 'test',
    description: 'test',
    suggestedKind: PlaceKind.publicSpace,
    shortDescription: PlaceFieldRequirement.optional,
    cover: PlaceFieldRequirement.optional,
    hours: hours,
    admission: admission,
    typicalSpend: typicalSpend,
    visitPlanning: visitPlanning,
    amenities: amenities,
    contacts: contacts,
    booking: booking,
    accessNote: accessNote,
  );

  group('compatibility fixture', () {
    final Map<String, Object?> fixture =
        jsonDecode(
              File(
                '../../packages/api_contracts/schema/content/v1/fixtures/'
                'place_create_compat.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final List<Map<String, Object?>> cases =
        (fixture['cases']! as List<Object?>).cast<Map<String, Object?>>();

    test('covers exactly the Create cases of the fixture builder', () {
      expect(
        cases.map((item) => item['name']).toList(),
        placeCompatCases.keys.toList(),
      );
      expect(fixture['serverOwnerUserId'], compatServerOwner);
    });

    for (final Map<String, Object?> item in cases) {
      test('the mapper produces the fixture body of "${item['name']}"', () {
        final PlaceContentBody mapped = map(
          placeCompatCases[item['name']! as String]!(),
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
      expect(body['title'], 'Kronvalda park pond');
      expect(body['placeKind'], 'publicSpace');
      expect(body['relationshipToPlace'], 'visitor');
      expect(body['categoryId'], 'outdoor_nature_walking');
      expect(body['subcategoryId'], 'park');
      expect(body['criteria'], <String, Object?>{'difficulty': 'easy'});
      final Map<String, Object?> location =
          body['location']! as Map<String, Object?>;
      expect(location['point'], <String, Object?>{
        'latitude': 56.9586,
        'longitude': 24.1066,
      });
      expect(location.containsKey('latitude'), isFalse);
      final Map<String, Object?> provenance =
          body['provenance']! as Map<String, Object?>;
      expect(provenance['submittedByUserId'], compatServerOwner);
      expect(provenance['relationshipClaim'], 'visitor');
      expect(provenance['createdAtUtc'], '2026-10-10T08:00:00.000Z');
      expect(body.containsKey('publisherRef'), isFalse);
    });

    test('renames operational dates, website, minor units', () {
      final CreateDraftEntity draft = base().copyWith(
        placeData: place(base()).copyWith(
          operationalStatus: const PlaceOperationalStatusDraft(
            status: PlaceOperationalStatus.temporarilyClosed,
            closedFromLocalDate: '2026-11-01',
            closedUntilLocalDate: '2026-11-20',
          ),
          contacts: const PlaceContactsDraft(websiteUrl: 'https://park.lv'),
          pricing: PlacePricingDraft(
            currencyCode: 'EUR',
            entryType: PlaceEntryType.paid,
            entryPriceFrom: Money(minorUnits: 500, currencyCode: 'EUR'),
          ),
        ),
      );
      final Map<String, Object?> body = map(draft, policy: policy()).body;
      expect(body['operationalStatus'], <String, Object?>{
        'status': 'temporarilyClosed',
        'startLocalDate': '2026-11-01',
        'endLocalDate': '2026-11-20',
      });
      expect(body['contacts'], <String, Object?>{'website': 'https://park.lv'});
      expect((body['pricing']! as Map<String, Object?>)['entryPriceFrom'], 500);
    });

    test('an empty short description is not sent', () {
      final Map<String, Object?> body = map(
        base().copyWith(shortDescription: '   '),
      ).body;
      expect(body.containsKey('shortDescription'), isFalse);
    });
  });

  group('inactive values stay local and are not sent (§5.3, Q2)', () {
    void notSent(
      CreateDraftEntity draft,
      PlaceCreationPolicy policy,
      bool Function(Map<String, Object?> body) present,
      bool Function(CreateDraftEntity draft) kept,
    ) {
      expect(kept(draft), isTrue, reason: 'the local draft holds the value');
      expect(present(map(draft, policy: policy).body), isFalse);
      expect(kept(draft), isTrue, reason: 'mapping does not change the draft');
    }

    Map<String, Object?> section(Map<String, Object?> body, String key) =>
        (body[key] as Map<String, Object?>?) ?? const <String, Object?>{};

    test('inactive criteria of an earlier category', () {
      final CreateDraftEntity draft = base().copyWith(
        sectionData: <String, Object?>{
          'criteria': <String, Object?>{'difficulty': 'easy'},
          'inactive_place_criteria': <String, Object?>{'language': 'en'},
        },
      );
      notSent(
        draft,
        policy(),
        (body) =>
            jsonEncode(body).contains('inactive_place_criteria') ||
            section(body, 'criteria').containsKey('language'),
        (d) => d.sectionData.containsKey('inactive_place_criteria'),
      );
    });

    test('closure dates without a temporary closure', () {
      final CreateDraftEntity draft = base().copyWith(
        placeData: place(base()).copyWith(
          operationalStatus: const PlaceOperationalStatusDraft(
            closedFromLocalDate: '2026-11-01',
            closedUntilLocalDate: '2026-11-20',
          ),
        ),
      );
      notSent(
        draft,
        policy(),
        (body) =>
            section(body, 'operationalStatus').containsKey('startLocalDate') ||
            section(body, 'operationalStatus').containsKey('endLocalDate'),
        (d) => d.placeData!.operationalStatus.closedFromLocalDate != null,
      );
    });

    test(
      'entry prices of a free entry, and any entry under hidden admission',
      () {
        final CreateDraftEntity free = base().copyWith(
          placeData: place(base()).copyWith(
            pricing: PlacePricingDraft(
              currencyCode: 'EUR',
              entryType: PlaceEntryType.free,
              entryPriceFrom: Money(minorUnits: 500, currencyCode: 'EUR'),
              entryPriceTo: Money(minorUnits: 900, currencyCode: 'EUR'),
            ),
          ),
        );
        notSent(
          free,
          policy(),
          (body) =>
              section(body, 'pricing').containsKey('entryPriceFrom') ||
              section(body, 'pricing').containsKey('entryPriceTo'),
          (d) => d.placeData!.pricing.entryPriceFrom != null,
        );
        final CreateDraftEntity paid = free.copyWith(
          placeData: place(free).copyWith(
            pricing: place(
              free,
            ).pricing.copyWith(entryType: PlaceEntryType.paid),
          ),
        );
        notSent(
          paid,
          policy(admission: PlaceFieldRequirement.hidden),
          (body) =>
              section(body, 'pricing').containsKey('entryType') ||
              section(body, 'pricing').containsKey('entryPriceFrom'),
          (d) => d.placeData!.pricing.entryType == PlaceEntryType.paid,
        );
      },
    );

    test('typical spend under hidden typical spend', () {
      final CreateDraftEntity draft = base().copyWith(
        placeData: place(base()).copyWith(
          pricing: PlacePricingDraft(
            currencyCode: 'EUR',
            entryType: PlaceEntryType.free,
            typicalSpendFrom: Money(minorUnits: 300, currencyCode: 'EUR'),
            typicalSpendTo: Money(minorUnits: 800, currencyCode: 'EUR'),
          ),
        ),
      );
      notSent(
        draft,
        policy(typicalSpend: PlaceFieldRequirement.hidden),
        (body) =>
            section(body, 'pricing').containsKey('typicalSpendFrom') ||
            section(body, 'pricing').containsKey('typicalSpendTo'),
        (d) => d.placeData!.pricing.typicalSpendFrom != null,
      );
    });

    test(
      'pricing note and URL when admission and typical spend are hidden',
      () {
        final CreateDraftEntity draft = base().copyWith(
          placeData: place(base()).copyWith(
            pricing: const PlacePricingDraft(
              currencyCode: 'EUR',
              entryType: PlaceEntryType.free,
              pricingNote: 'Donations welcome',
              officialPricingUrl: 'https://park.lv/prices',
            ),
          ),
        );
        notSent(
          draft,
          policy(
            admission: PlaceFieldRequirement.hidden,
            typicalSpend: PlaceFieldRequirement.hidden,
          ),
          (body) =>
              section(body, 'pricing').containsKey('pricingNote') ||
              section(body, 'pricing').containsKey('officialPricingUrl'),
          (d) => d.placeData!.pricing.pricingNote != null,
        );
      },
    );

    test('visit planning under hidden visit planning', () {
      final CreateDraftEntity draft = base().copyWith(
        placeData: place(base()).copyWith(
          visitPlanning: const PlaceVisitPlanningDraft(
            recommendedVisitMinutes: 60,
          ),
        ),
      );
      notSent(
        draft,
        policy(visitPlanning: PlaceFieldRequirement.hidden),
        (body) => body.containsKey('visitPlanning'),
        (d) => d.placeData!.visitPlanning.recommendedVisitMinutes == 60,
      );
    });

    test(
      'contacts under hidden contacts, booking link under hidden booking',
      () {
        final CreateDraftEntity draft = base().copyWith(
          placeData: place(base()).copyWith(
            contacts: const PlaceContactsDraft(
              websiteUrl: 'https://park.lv',
              phone: '+371 20000000',
              bookingUrl: 'https://park.lv/book',
            ),
          ),
        );
        final Map<String, Object?> onlyBooking = map(
          draft,
          policy: policy(contacts: PlaceFieldRequirement.hidden),
        ).body;
        expect(onlyBooking['contacts'], <String, Object?>{
          'bookingUrl': 'https://park.lv/book',
        });
        notSent(
          draft,
          policy(booking: PlaceFieldRequirement.hidden),
          (body) => section(body, 'contacts').containsKey('bookingUrl'),
          (d) => d.placeData!.contacts.bookingUrl != null,
        );
        notSent(
          draft,
          policy(
            contacts: PlaceFieldRequirement.hidden,
            booking: PlaceFieldRequirement.hidden,
          ),
          (body) => body.containsKey('contacts'),
          (d) => d.placeData!.contacts.websiteUrl != null,
        );
      },
    );

    test('hours under hidden hours', () {
      notSent(
        base(),
        policy(hours: PlaceFieldRequirement.hidden),
        (body) => body.containsKey('hours'),
        (d) => d.placeData!.hours.weeklyPeriods.isNotEmpty,
      );
    });

    test('entrance hint under hidden access note', () {
      final CreateDraftEntity draft = base().copyWith(
        placeData: place(base()).copyWith(
          location: place(base()).location.copyWith(entranceHint: 'North gate'),
        ),
      );
      expect(
        section(map(draft, policy: policy()).body, 'location')['entranceHint'],
        'North gate',
      );
      notSent(
        draft,
        policy(accessNote: PlaceFieldRequirement.hidden),
        (body) => section(body, 'location').containsKey('entranceHint'),
        (d) => d.placeData!.location.entranceHint == 'North gate',
      );
    });

    test('amenities under hidden amenities', () {
      final CreateDraftEntity draft = base().copyWith(
        placeData: place(base()).copyWith(
          amenityIds: <String>{'parking'},
          amenityUnknownIds: <String>{'wifi'},
        ),
      );
      notSent(
        draft,
        policy(amenities: PlaceFieldRequirement.hidden),
        (body) =>
            body.containsKey('amenityIds') ||
            body.containsKey('amenityUnknownIds'),
        (d) => d.placeData!.amenityIds.contains('parking'),
      );
    });
  });

  group('unsupported content is refused, never dropped', () {
    test('seasonal hours', () {
      final CreateDraftEntity draft = base().copyWith(
        placeData: place(
          base(),
        ).copyWith(hours: const PlaceHoursDraft(mode: PlaceHoursMode.seasonal)),
      );
      expect(map(draft).unsupported, <String>['hours.seasonal']);
    });

    test('fields of a newer draft schema', () {
      final CreateDraftEntity draft = base().copyWith(
        placeData: place(
          base(),
        ).copyWith(unknownFields: <String, Object?>{'futureField': 1}),
      );
      expect(map(draft).unsupported, <String>['unknown_fields']);
    });

    test('a non-Place draft is not mapped', () {
      expect(
        () => map(base().copyWith(objectType: CreateObjectType.event)),
        throwsArgumentError,
      );
    });
  });

  group('ids and keys (§5.5)', () {
    test('namespace and scope give the independently computed UUIDv5', () {
      expect(
        PlacePublicationScope.namespace,
        '7dd283c2-0e3c-41e1-b60f-7ed6bb9e0735',
      );
      final PlacePublicationScope scope = compatScope();
      expect(
        scope.value,
        'recharge:place-publication:v1:account-compat-1:page:page-compat-1:'
        'local-place-compat-1',
      );
      // Computed with Python's uuid.uuid5 for the same namespace and name.
      expect(
        scope.periodId('loc_period_mon'),
        'c9f7dd79-cd6a-5b13-9085-63dd9eb08757',
      );
      expect(scope.keyBase, matches(RegExp(r'^pp1-[0-9a-f]{24}$')));
    });

    test(
      'local ids become stable UUIDv5 and no loc_ id is left with assets',
      () {
        final Map<String, Object?> first = map(base()).body;
        final Map<String, Object?> second = map(base()).body;
        expect(jsonEncode(first), jsonEncode(second));
        expect(jsonEncode(first).contains('loc_'), isFalse);
      },
    );

    test(
      'before upload the media are loc_ placeholders of their attachment ids',
      () {
        final PlaceContentBody mapped = map(
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
        for (final PlaceMediaAttachment item in map(draft).attachments)
          item.localRef: item.attachmentId,
      };
      final List<PlaceMediaAttachment> after = map(reordered).attachments;
      for (final PlaceMediaAttachment item in after) {
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
      final PlacePublicationScope scope = compatScope();
      final List<PlacePublicationScope> others = <PlacePublicationScope>[
        PlacePublicationScope(
          accountId: 'another-account',
          publisherRef: scope.publisherRef,
          localDraftId: scope.localDraftId,
        ),
        PlacePublicationScope(
          accountId: scope.accountId,
          publisherRef: const PublisherRef(
            type: PublisherType.user,
            id: 'page-compat-1',
          ),
          localDraftId: scope.localDraftId,
        ),
        PlacePublicationScope(
          accountId: scope.accountId,
          publisherRef: scope.publisherRef,
          localDraftId: 'another-draft',
        ),
      ];
      for (final PlacePublicationScope other in others) {
        expect(other.coverAttachmentId, isNot(scope.coverAttachmentId));
        expect(
          other.periodId('loc_period_mon'),
          isNot(scope.periodId('loc_period_mon')),
        );
        expect(other.keyBase, isNot(scope.keyBase));
      }
    });

    test('an upload id changes with the bytes, not with the attempt', () {
      final PlacePublicationScope scope = compatScope();
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
