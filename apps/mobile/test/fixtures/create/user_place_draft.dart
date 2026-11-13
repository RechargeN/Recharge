import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/build_place_content_body.dart';

/// A user's Place draft as the Create flow stores it (D3.1 §5): Create
/// defaults plus the fields a user fills in, under the strict v1.0 rules and
/// the Emulator Place taxonomy (§2.3: `outdoor_nature_walking/park` needs the
/// `difficulty` criterion). Local ids are `loc_*`; it is not a backend body.
CreateDraftEntity userPlaceDraft({
  required String pageId,
  required String coverPath,
  List<String> galleryPaths = const <String>[],
  String? localId,
  String title = 'Kronvalda park pond',
}) {
  final CreateDraftEntity base = CreateDraftEntity.defaults(
    organizerId: 'user-1',
    organizerEmail: 'user@example.com',
    organizerName: 'Stand Creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  );
  final PlaceDraftData place =
      PlaceDraftData.defaults(
        userId: 'user-1',
        marketCityId: 'riga',
        countryCode: 'LV',
        city: 'Riga',
        timezoneId: 'Europe/Riga',
        currencyCode: 'EUR',
      ).copyWith(
        placeKind: PlaceKind.publicSpace,
        relationshipToPlace: PlaceRelationship.visitor,
        publisherRef: PublisherRef(type: PublisherType.page, id: pageId),
        location: const PlaceLocationDraft(
          marketCityId: 'riga',
          countryCode: 'LV',
          city: 'Riga',
          timezoneId: 'Europe/Riga',
          formattedAddress: 'Kronvalda bulvaris, Riga',
          latitude: 56.9586,
          longitude: 24.1066,
          accuracy: PlaceLocationAccuracy.rooftop,
          pinConfirmed: true,
        ),
        hours: const PlaceHoursDraft(
          mode: PlaceHoursMode.regular,
          weeklyPeriods: <LocalOpeningPeriod>[
            LocalOpeningPeriod(
              id: 'loc_period_mon',
              dayOfWeek: 1,
              openMinute: 420,
              closeMinute: 1320,
              closesNextDay: false,
            ),
          ],
        ),
        pricing: const PlacePricingDraft(
          currencyCode: 'EUR',
          entryType: PlaceEntryType.free,
        ),
        provenance: PlaceDataProvenance(
          sourceType: PlaceSourceType.creatorSubmission,
          submittedByUserId: 'user-1',
          createdAtUtc: DateTime.utc(2026, 10, 10, 8),
          lastConfirmedAtUtc: DateTime.utc(2026, 10, 10, 8),
        ),
      );
  return base.copyWith(
    id: localId ?? base.id,
    objectType: CreateObjectType.place,
    title: title,
    mainCategory: 'outdoor_nature_walking',
    subcategory: 'park',
    shortDescription: 'Quiet city park with a pond and benches',
    sectionData: <String, Object?>{
      'criteria': <String, Object?>{'difficulty': 'easy'},
    },
    placeData: place,
    media: MediaEntity(coverImage: coverPath, gallery: galleryPaths),
  );
}

/// Inputs shared by the compatibility cases (D3.1 §5.7) and the fixture file
/// `packages/api_contracts/schema/content/v1/fixtures/place_create_compat.json`.
const String compatAccountId = 'account-compat-1';
const String compatPageId = 'page-compat-1';
const String compatLocalDraftId = 'local-place-compat-1';
const String compatServerOwner = 'server-owner-compat-1';
const List<String> compatGallery = <String>[
  'C:/photos/pond-1.png',
  'C:/photos/pond-2.png',
];

PlacePublicationScope compatScope() => PlacePublicationScope(
  accountId: compatAccountId,
  publisherRef: const PublisherRef(type: PublisherType.page, id: compatPageId),
  localDraftId: compatLocalDraftId,
);

/// The uploaded assets of the compatibility drafts, by stable attachment id.
Map<String, String> compatAssetIds() {
  final PlacePublicationScope scope = compatScope();
  return <String, String>{
    scope.coverAttachmentId: 'asset-cover',
    scope.galleryAttachmentId(compatGallery[0]): 'asset-gallery-1',
    scope.galleryAttachmentId(compatGallery[1]): 'asset-gallery-2',
  };
}

CreateDraftEntity _compatBase() => userPlaceDraft(
  pageId: compatPageId,
  coverPath: 'C:/photos/pond-cover.png',
  galleryPaths: compatGallery,
  localId: compatLocalDraftId,
);

PlaceDraftData _place(CreateDraftEntity draft) => draft.placeData!;

/// A Create draft per case: the accepted one, then one per row of §5.7.
final Map<String, CreateDraftEntity Function()> placeCompatCases =
    <String, CreateDraftEntity Function()>{
      'valid': _compatBase,
      'cover_missing': () => _compatBase().copyWith(
        media: const MediaEntity(coverImage: '', gallery: compatGallery),
      ),
      'short_description_short': () =>
          _compatBase().copyWith(shortDescription: 'Quiet park'),
      'hours_mode_missing': () {
        final CreateDraftEntity draft = _compatBase();
        return draft.copyWith(
          placeData: _place(draft).copyWith(hours: const PlaceHoursDraft()),
        );
      },
      'entry_type_missing': () {
        final CreateDraftEntity draft = _compatBase();
        return draft.copyWith(
          placeData: _place(
            draft,
          ).copyWith(pricing: const PlacePricingDraft(currencyCode: 'EUR')),
        );
      },
      'currency_mismatch': () {
        final CreateDraftEntity draft = _compatBase();
        return draft.copyWith(
          placeData: _place(draft).copyWith(
            pricing: const PlacePricingDraft(
              currencyCode: 'USD',
              entryType: PlaceEntryType.free,
            ),
          ),
        );
      },
      // Contacts are hidden for a park; a museum (cultural venue) shows them.
      'phone_invalid': () {
        final CreateDraftEntity draft = _compatBase();
        return draft.copyWith(
          mainCategory: 'art_culture_museums',
          subcategory: 'museum',
          sectionData: const <String, Object?>{},
          placeData: _place(draft).copyWith(
            contacts: const PlaceContactsDraft(phone: 'call 1234567 ext'),
          ),
        );
      },
      'source_type_mismatch': () {
        final CreateDraftEntity draft = _compatBase();
        return draft.copyWith(
          placeData: _place(
            draft,
          ).copyWith(relationshipToPlace: PlaceRelationship.owner),
        );
      },
      'outside_service_area': () {
        final CreateDraftEntity draft = _compatBase();
        final PlaceLocationDraft location = _place(draft).location;
        return draft.copyWith(
          placeData: _place(draft).copyWith(
            location: PlaceLocationDraft(
              marketCityId: location.marketCityId,
              countryCode: location.countryCode,
              city: location.city,
              timezoneId: location.timezoneId,
              formattedAddress: location.formattedAddress,
              latitude: 59.437,
              longitude: 24.7536,
              accuracy: location.accuracy,
              pinConfirmed: true,
            ),
          ),
        );
      },
      'subcategory_not_applicable': () => _compatBase().copyWith(
        mainCategory: 'art_culture_museums',
        subcategory: 'artist_talk',
        sectionData: const <String, Object?>{},
      ),
      'criterion_missing': () =>
          _compatBase().copyWith(sectionData: const <String, Object?>{}),
    };
