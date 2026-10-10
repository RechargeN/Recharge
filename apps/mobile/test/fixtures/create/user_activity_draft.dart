import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/build_activity_content_body.dart';

/// A user's Recharge Activity draft as the Create flow stores it (D3.2 §5):
/// Create defaults plus the fields a user fills in, under the Emulator Activity
/// taxonomy (§2.3: `outdoor_nature_walking/forest_walk` needs the `difficulty`
/// criterion). It is not a backend body.
CreateDraftEntity userActivityDraft({
  required String pageId,
  required String coverPath,
  List<String> galleryPaths = const <String>[],
  String? localId,
  String title = 'Ķemeri bog boardwalk loop',
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
  final ActivityDraftData activity =
      ActivityDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      ).copyWith(
        publisherRef: PublisherRef(type: PublisherType.page, id: pageId),
        location: const ActivityLocationDraft(
          latitude: 56.9142,
          longitude: 23.4706,
          pinConfirmed: true,
          addressLine: 'Ķemeri National Park, Jūrmala',
          accessNotes: 'Start at the car park by the visitor trail sign',
        ),
        typicalDurationMinutes: const ActivityIntRangeDraft(min: 60, max: 120),
        suggestedGroupSize: const ActivityIntRangeDraft(min: 1, max: 6),
        bestTime: const ActivityBestTimeDraft(
          timeOfDay: ActivityTimeOfDay.morning,
          season: ActivitySeason.any,
        ),
      );
  return base.copyWith(
    id: localId ?? base.id,
    objectType: CreateObjectType.activity,
    title: title,
    mainCategory: 'outdoor_nature_walking',
    subcategory: 'forest_walk',
    shortDescription: 'Easy boardwalk loop across the bog with a viewing tower',
    sectionData: <String, Object?>{
      'criteria': <String, Object?>{'difficulty': 'easy'},
    },
    activityData: activity,
    media: MediaEntity(coverImage: coverPath, gallery: galleryPaths),
  );
}

/// Inputs shared by the compatibility cases (D3.2 §5.7) and the fixture file
/// `packages/api_contracts/schema/content/v1/fixtures/activity_create_compat.json`.
const String compatAccountId = 'account-compat-1';
const String compatPageId = 'page-compat-1';
const String compatLocalDraftId = 'local-activity-compat-1';
const List<String> compatGallery = <String>[
  'C:/photos/bog-1.png',
  'C:/photos/bog-2.png',
];

ActivityPublicationScope compatScope() => ActivityPublicationScope(
  accountId: compatAccountId,
  publisherRef: const PublisherRef(type: PublisherType.page, id: compatPageId),
  localDraftId: compatLocalDraftId,
);

/// The uploaded assets of the compatibility drafts, by stable attachment id.
Map<String, String> compatAssetIds() {
  final ActivityPublicationScope scope = compatScope();
  return <String, String>{
    scope.coverAttachmentId: 'asset-cover',
    scope.galleryAttachmentId(compatGallery[0]): 'asset-gallery-1',
    scope.galleryAttachmentId(compatGallery[1]): 'asset-gallery-2',
  };
}

CreateDraftEntity _compatBase() => userActivityDraft(
  pageId: compatPageId,
  coverPath: 'C:/photos/bog-cover.png',
  galleryPaths: compatGallery,
  localId: compatLocalDraftId,
);

ActivityDraftData _activity(CreateDraftEntity draft) => draft.activityData!;

CreateDraftEntity _withActivity(
  ActivityDraftData Function(ActivityDraftData activity) change,
) {
  final CreateDraftEntity draft = _compatBase();
  return draft.copyWith(activityData: change(_activity(draft)));
}

ActivityLocationDraft _location({
  bool pinConfirmed = true,
  String accessNotes = 'Start at the car park by the visitor trail sign',
  ActivityAccessCautionDraft? accessCaution,
}) => ActivityLocationDraft(
  latitude: 56.9142,
  longitude: 23.4706,
  pinConfirmed: pinConfirmed,
  addressLine: 'Ķemeri National Park, Jūrmala',
  accessNotes: accessNotes,
  accessCaution: accessCaution,
);

/// A Create draft per case: the accepted one, then one per row of §5.7.
final Map<String, CreateDraftEntity Function()> activityCompatCases =
    <String, CreateDraftEntity Function()>{
      'valid': _compatBase,
      'cover_missing': () => _compatBase().copyWith(
        media: const MediaEntity(coverImage: '', gallery: compatGallery),
      ),
      'short_description_short': () =>
          _compatBase().copyWith(shortDescription: 'Bog walk'),
      'pin_unconfirmed': () => _withActivity(
        (activity) =>
            activity.copyWith(location: _location(pinConfirmed: false)),
      ),
      'access_notes_missing': () => _withActivity(
        (activity) => activity.copyWith(location: _location(accessNotes: '')),
      ),
      'informal_access_without_note': () => _withActivity(
        (activity) => activity.copyWith(
          location: _location(
            accessCaution: const ActivityAccessCautionDraft(isInformal: true),
          ),
        ),
      ),
      'contribution_note_missing': () => _withActivity(
        (activity) => activity.copyWith(
          optionalContribution: const ActivityOptionalContributionDraft(
            kind: ActivityContributionKind.donation,
          ),
        ),
      ),
      'contribution_currency_mismatch': () => _withActivity(
        (activity) => activity.copyWith(
          optionalContribution: const ActivityOptionalContributionDraft(
            kind: ActivityContributionKind.purchase,
            note: 'Parking at the trail head is paid',
            amountHint: ActivityContributionAmountDraft(
              amountMinor: 300,
              currencyCode: 'USD',
            ),
          ),
        ),
      ),
      'duration_range_invalid': () => _withActivity(
        (activity) => activity.copyWith(
          typicalDurationMinutes: const ActivityIntRangeDraft(
            min: 120,
            max: 60,
          ),
        ),
      ),
      'subcategory_not_applicable': () => _compatBase().copyWith(
        mainCategory: 'wellness_recharge',
        subcategory: 'sauna',
        sectionData: const <String, Object?>{},
      ),
      'criterion_missing': () =>
          _compatBase().copyWith(sectionData: const <String, Object?>{}),
    };
