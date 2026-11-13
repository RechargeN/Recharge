import 'package:recharge/features/create/domain/entities/class_workshop_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/usecases/build_class_workshop_content_body.dart';

/// The typed Class / Workshop Create draft whose wire body is the shared
/// `class_workshop_create_compat.json` "valid" case (D3.6, CW-V1).
CreateDraftEntity userClassWorkshopDraft({
  required String userId,
  required String coverPath,
  List<String> galleryPaths = const <String>[],
  String localId = 'local-class-1',
  String title = 'Riga pottery workshop',
  List<ClassWorkshopOccurrence> occurrences = const <ClassWorkshopOccurrence>[
    ClassWorkshopOccurrence(
      id: 'loc_occ_1',
      localDate: '2027-05-15',
      startMinuteLocal: 600,
      endMinuteLocal: 780,
    ),
  ],
}) {
  final base = CreateDraftEntity.defaults(
    organizerId: userId,
    organizerEmail: 'creator@example.org',
    organizerName: 'Creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  );
  final draft = base.copyWith(
    id: localId,
    objectType: CreateObjectType.classWorkshop,
    clearEventData: true,
    title: title,
    shortDescription: 'Hands-on wheel throwing for beginners in Riga.',
    fullDescription:
        'A guided pottery workshop: learn centring and throwing on the wheel, then take home your own cup after firing.',
    mainCategory: 'workshops_masterclasses',
    subcategory: 'pottery',
    venueName: 'Clay studio',
    addressLine1: 'Riga studio 1',
    latitude: 56.9496,
    longitude: 24.1052,
    media: MediaEntity(coverImage: coverPath, gallery: galleryPaths),
    classWorkshopData: ClassWorkshopDraftData(
      offeringKind: ClassWorkshopOfferingKind.workshop,
      timezoneId: 'Europe/Riga',
      timezoneConfirmed: true,
      occurrences: occurrences,
      outcomes: const <String>[
        'Centre clay on the wheel',
        'Throw a simple cup',
      ],
      modules: const <ClassWorkshopModule>[
        ClassWorkshopModule(id: 'loc_mod_1', title: 'Wedging and centring'),
        ClassWorkshopModule(id: 'loc_mod_2', title: 'Throwing a cup'),
      ],
      prerequisitesListed: false,
      takeHomeResult: 'Your own glazed cup after firing',
      includedMaterials: const <String>['Clay', 'Glazes'],
      declaredGroupLimit: 8,
      price: const ClassWorkshopPrice(
        mode: ClassWorkshopPriceMode.fixed,
        amountMinor: 4500,
        currencyCode: 'EUR',
        scope: ClassWorkshopPriceScope.perPersonPerClass,
      ),
      enrollment: const ClassWorkshopEnrollment(
        mode: ClassWorkshopEnrollmentMode.external,
        externalUrl: 'https://studio.example.org/pottery',
      ),
    ),
  );
  return draft.copyWith(
    sectionData: <String, Object?>{
      'criteria': <String, Object?>{
        'skill_level': 'beginner',
        'equipment_provided': 'provided',
      },
      ClassWorkshopContentBodyMapper.pinSection:
          ClassWorkshopContentBodyMapper.pinEvidence(draft),
      ClassWorkshopContentBodyMapper.mediaSection: <String, Object?>{
        'contentLocale': 'en',
        'rightsConfirmed': true,
        'coverAltText': <String, Object?>{'en': 'Potter at the wheel'},
        'galleryAltText': <String, Object?>{
          for (final ref in galleryPaths)
            ref: <String, Object?>{'en': 'Pottery gallery image'},
        },
      },
    },
  );
}

extension ClassWorkshopDraftFixtureEdits on CreateDraftEntity {
  /// The same draft before the Creator confirmed the image rights.
  CreateDraftEntity withoutRightsConfirmation() {
    final Object? media =
        sectionData[ClassWorkshopContentBodyMapper.mediaSection];
    return copyWith(
      sectionData: <String, Object?>{
        ...sectionData,
        ClassWorkshopContentBodyMapper.mediaSection: <String, Object?>{
          if (media is Map<String, Object?>) ...media,
          'rightsConfirmed': false,
        },
      },
    );
  }
}
