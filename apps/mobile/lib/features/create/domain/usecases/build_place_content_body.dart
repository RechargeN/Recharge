import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../entities/create_draft_entity.dart';
import '../entities/place_creation_policy.dart';
import '../entities/place_draft_data.dart';

/// Stable ids and keys of one Place publication (D3.1 §5.5): every id is a
/// UUIDv5 in [namespace] under a scope of the signed-in account, the publisher
/// and the local Create draft, so another account, another publisher or another
/// draft can never reuse them, and every save of the same draft repeats them.
final class PlacePublicationScope {
  PlacePublicationScope({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
  });

  /// D3.1 §5.5; fixed here and in the tests.
  static const String namespace = '7dd283c2-0e3c-41e1-b60f-7ed6bb9e0735';

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;

  String get value =>
      'recharge:place-publication:v1:$accountId:'
      '${publisherRef.type.wireName}:${publisherRef.id}:$localDraftId';

  String _id(String name) => const Uuid().v5(namespace, '$value:$name');

  String periodId(String localPeriodId) => _id('period:$localPeriodId');

  String exceptionId(String localExceptionId) =>
      _id('exception:$localExceptionId');

  String exceptionPeriodId(String localExceptionId, String localPeriodId) =>
      _id('exception:$localExceptionId:period:$localPeriodId');

  String get coverAttachmentId => _id('attachment:cover');

  /// Stable for the photo reference in the Create draft, not its position:
  /// reordering the gallery keeps every id.
  String galleryAttachmentId(String localMediaRef) =>
      _id('attachment:gallery:$localMediaRef');

  /// The Media intent of one exact upload: same attachment and bytes, same id.
  String uploadIntentId(String attachmentId, String sha256Hex) =>
      _id('upload:$attachmentId:$sha256Hex');

  /// Prefix of every Content idempotency key of this publication.
  String get keyBase =>
      'pp1-${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';
}

/// One medium of the Place: the cover or a gallery photo of the Create draft.
final class PlaceMediaAttachment {
  const PlaceMediaAttachment({
    required this.attachmentId,
    required this.role,
    required this.localRef,
  });

  final String attachmentId;

  /// `cover` or `gallery`.
  final String role;

  /// The reference in the Create draft (a local file).
  final String localRef;
}

final class PlaceContentBody {
  const PlaceContentBody({
    required this.body,
    required this.unsupported,
    required this.attachments,
  });

  final Map<String, Object?> body;

  /// Draft content the Content Place body cannot carry; a draft that has any is
  /// not sent at all (nothing is dropped silently).
  final List<String> unsupported;

  /// Cover first, then the gallery in the draft's order.
  final List<PlaceMediaAttachment> attachments;
}

/// Maps a Create Place draft to the Content Place body (D3.1 §5.2, §5.3). Only
/// what the Create form itself treats as active under [PlaceCreationPolicy] is
/// sent; inactive values stay in the local draft and are neither removed nor
/// sent. Nothing is invented: a value the draft does not hold is not sent, and
/// the server's own rules decide the rest.
final class PlaceContentBodyMapper {
  const PlaceContentBodyMapper();

  PlaceContentBody map(
    CreateDraftEntity draft, {
    required PlacePublicationScope scope,
    required PlaceCreationPolicy policy,
    required String serverOwnerUserId,
    Map<String, String> assetIds = const <String, String>{},
  }) {
    final PlaceDraftData? place = draft.placeData;
    if (draft.objectType != CreateObjectType.place || place == null) {
      throw ArgumentError('Not a Place draft');
    }
    final List<String> unsupported = <String>[
      if (place.hours.mode == PlaceHoursMode.seasonal) 'hours.seasonal',
      if (place.unknownFields.isNotEmpty) 'unknown_fields',
    ];
    final List<PlaceMediaAttachment> attachments = attachmentsOf(draft, scope);
    String mediaId(PlaceMediaAttachment item) =>
        assetIds[item.attachmentId] ?? 'loc_${item.attachmentId}';

    final String shortDescription = draft.shortDescription.trim();
    final String fullDescription = draft.fullDescription.trim();
    final Object? criteria = draft.sectionData['criteria'];
    final Map<String, Object?> body = <String, Object?>{
      'title': draft.title.trim(),
      if (place.placeKind != null) 'placeKind': place.placeKind!.name,
      if (place.relationshipToPlace != null)
        'relationshipToPlace': place.relationshipToPlace!.name,
      if (shortDescription.isNotEmpty) 'shortDescription': shortDescription,
      if (fullDescription.isNotEmpty) 'fullDescription': fullDescription,
      'contentLocale': place.contentLocale,
      if (place.languages.isNotEmpty)
        'languages': place.languages.toList()..sort(),
      'categoryId': draft.mainCategory,
      'subcategoryId': draft.subcategory,
      if (draft.tags.isNotEmpty) 'tags': List<String>.of(draft.tags),
      if (criteria is Map && criteria.isNotEmpty)
        'criteria': Map<String, Object?>.from(criteria),
      'location': _location(place.location, policy),
      if (policy.hours.isVisible && place.hours.mode != null)
        'hours': _hours(place.hours, scope),
      'operationalStatus': _operationalStatus(place.operationalStatus),
      if (policy.visitPlanning.isVisible)
        'visitPlanning': _visitPlanning(place.visitPlanning),
      if (policy.amenities.isVisible && place.amenityIds.isNotEmpty)
        'amenityIds': place.amenityIds.toList()..sort(),
      if (policy.amenities.isVisible && place.amenityUnknownIds.isNotEmpty)
        'amenityUnknownIds': place.amenityUnknownIds.toList()..sort(),
      'pricing': _pricing(place.pricing, policy),
      if (_contacts(place.contacts, policy) case final Map<String, Object?> c)
        'contacts': c,
      'media': <String, Object?>{
        for (final PlaceMediaAttachment item in attachments)
          if (item.role == 'cover')
            'coverImage': <String, Object?>{'mediaId': mediaId(item)},
        'gallery': <Map<String, Object?>>[
          for (final PlaceMediaAttachment item in attachments)
            if (item.role == 'gallery')
              <String, Object?>{'mediaId': mediaId(item)},
        ],
      },
      'provenance': _provenance(place, serverOwnerUserId),
    };
    return PlaceContentBody(
      body: body,
      unsupported: unsupported,
      attachments: attachments,
    );
  }

  /// The draft's media in body order: the cover, then the gallery as ordered
  /// in the draft, each with its stable attachment id (§5.5).
  List<PlaceMediaAttachment> attachmentsOf(
    CreateDraftEntity draft,
    PlacePublicationScope scope,
  ) => <PlaceMediaAttachment>[
    if (draft.media.coverImage.trim().isNotEmpty)
      PlaceMediaAttachment(
        attachmentId: scope.coverAttachmentId,
        role: 'cover',
        localRef: draft.media.coverImage,
      ),
    for (final String ref in draft.media.gallery)
      PlaceMediaAttachment(
        attachmentId: scope.galleryAttachmentId(ref),
        role: 'gallery',
        localRef: ref,
      ),
  ];

  static Map<String, Object?> _location(
    PlaceLocationDraft location,
    PlaceCreationPolicy policy,
  ) {
    String? text(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();
    return <String, Object?>{
      'marketCityId': location.marketCityId,
      'countryCode': location.countryCode,
      'city': location.city,
      if (text(location.district) case final String value) 'district': value,
      if (text(location.formattedAddress) case final String value)
        'formattedAddress': value,
      if (text(location.locationLabel) case final String value)
        'locationLabel': value,
      if (policy.accessNote.isVisible)
        if (text(location.entranceHint) case final String value)
          'entranceHint': value,
      if (location.latitude != null && location.longitude != null)
        'point': <String, Object?>{
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
      'timezoneId': location.timezoneId,
      'accuracy': location.accuracy.name,
      'pinConfirmed': location.pinConfirmed,
      if (location.geocodedAtUtc != null)
        'geocodedAtUtc': _instant(location.geocodedAtUtc!),
    };
  }

  static Map<String, Object?> _period(
    LocalOpeningPeriod period,
    String id, {
    required bool withDay,
  }) => <String, Object?>{
    'id': id,
    if (withDay) 'dayOfWeek': period.dayOfWeek,
    'openMinute': period.openMinute,
    'closeMinute': period.closeMinute,
    'closesNextDay': period.closesNextDay,
  };

  static Map<String, Object?> _hours(
    PlaceHoursDraft hours,
    PlacePublicationScope scope,
  ) => <String, Object?>{
    'mode': hours.mode!.name,
    'weeklyPeriods': <Map<String, Object?>>[
      for (final LocalOpeningPeriod period in hours.weeklyPeriods)
        _period(period, scope.periodId(period.id), withDay: true),
    ],
    'exceptions': <Map<String, Object?>>[
      for (final OpeningException exception in hours.exceptions)
        <String, Object?>{
          'id': scope.exceptionId(exception.id),
          'localDate': exception.localDate,
          'kind': exception.kind.name,
          'periods': <Map<String, Object?>>[
            for (final LocalOpeningPeriod period in exception.periods)
              _period(
                period,
                scope.exceptionPeriodId(exception.id, period.id),
                withDay: false,
              ),
          ],
          if (exception.publicNote?.trim().isNotEmpty ?? false)
            'publicNote': exception.publicNote!.trim(),
        },
    ],
  };

  static Map<String, Object?> _operationalStatus(
    PlaceOperationalStatusDraft status,
  ) {
    final bool closed =
        status.status == PlaceOperationalStatus.temporarilyClosed;
    return <String, Object?>{
      'status': status.status.name,
      // Closure dates belong to a temporary closure only (§5.3).
      if (closed && status.closedFromLocalDate != null)
        'startLocalDate': status.closedFromLocalDate,
      if (closed && status.closedUntilLocalDate != null)
        'endLocalDate': status.closedUntilLocalDate,
      if (status.publicNote?.trim().isNotEmpty ?? false)
        'publicNote': status.publicNote!.trim(),
    };
  }

  static Map<String, Object?> _visitPlanning(PlaceVisitPlanningDraft plan) =>
      <String, Object?>{
        if (plan.recommendedVisitMinutes != null)
          'recommendedVisitMinutes': plan.recommendedVisitMinutes,
        if (plan.minimumVisitMinutes != null)
          'minimumVisitMinutes': plan.minimumVisitMinutes,
        'allowsShortVisit': plan.allowsShortVisit,
        if (plan.busyTimeNotes?.trim().isNotEmpty ?? false)
          'busyTimeNotes': plan.busyTimeNotes!.trim(),
        'weatherDependent': plan.weatherDependent,
        'arrivalBufferMinutes': plan.arrivalBufferMinutes,
        'exitBufferMinutes': plan.exitBufferMinutes,
      };

  static Map<String, Object?> _pricing(
    PlacePricingDraft pricing,
    PlaceCreationPolicy policy,
  ) {
    final bool admission = policy.admission.isVisible;
    final bool spend = policy.typicalSpend.isVisible;
    final PlaceEntryType? type = admission ? pricing.entryType : null;
    final bool pricedEntry =
        type == PlaceEntryType.paid || type == PlaceEntryType.mixed;
    final String? note = pricing.pricingNote?.trim();
    final String? url = pricing.officialPricingUrl?.trim();
    return <String, Object?>{
      if (type != null) 'entryType': type.name,
      if (pricedEntry && pricing.entryPriceFrom != null)
        'entryPriceFrom': pricing.entryPriceFrom!.minorUnits,
      if (pricedEntry && pricing.entryPriceTo != null)
        'entryPriceTo': pricing.entryPriceTo!.minorUnits,
      if (spend && pricing.typicalSpendFrom != null)
        'typicalSpendFrom': pricing.typicalSpendFrom!.minorUnits,
      if (spend && pricing.typicalSpendTo != null)
        'typicalSpendTo': pricing.typicalSpendTo!.minorUnits,
      'currencyCode': pricing.currencyCode,
      if ((admission || spend) && (note?.isNotEmpty ?? false))
        'pricingNote': note,
      if ((admission || spend) && (url?.isNotEmpty ?? false))
        'officialPricingUrl': url,
    };
  }

  static Map<String, Object?>? _contacts(
    PlaceContactsDraft contacts,
    PlaceCreationPolicy policy,
  ) {
    String? text(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();
    final Map<String, Object?> result = <String, Object?>{
      if (policy.contacts.isVisible) ...<String, Object?>{
        if (text(contacts.websiteUrl) case final String value) 'website': value,
        if (text(contacts.phone) case final String value) 'phone': value,
        if (text(contacts.email) case final String value) 'email': value,
        if (contacts.socialUrls.isNotEmpty)
          'socialUrls': List<String>.of(contacts.socialUrls),
      },
      if (policy.booking.isVisible)
        if (text(contacts.bookingUrl) case final String value)
          'bookingUrl': value,
    };
    return result.isEmpty ? null : result;
  }

  static Map<String, Object?> _provenance(
    PlaceDraftData place,
    String serverOwnerUserId,
  ) {
    final PlaceDataProvenance provenance = place.provenance;
    return <String, Object?>{
      'sourceType': provenance.sourceType.name,
      'submittedByUserId': serverOwnerUserId,
      if (place.relationshipToPlace != null)
        'relationshipClaim': place.relationshipToPlace!.name,
      'createdAtUtc': _instant(provenance.createdAtUtc),
      'lastConfirmedAtUtc': _instant(provenance.lastConfirmedAtUtc),
      if (provenance.hoursConfirmedAtUtc != null)
        'hoursConfirmedAtUtc': _instant(provenance.hoursConfirmedAtUtc!),
      if (provenance.pricingConfirmedAtUtc != null)
        'pricingConfirmedAtUtc': _instant(provenance.pricingConfirmedAtUtc!),
      if (provenance.contactsConfirmedAtUtc != null)
        'contactsConfirmedAtUtc': _instant(provenance.contactsConfirmedAtUtc!),
    };
  }

  static String _instant(DateTime value) => value.toUtc().toIso8601String();
}
