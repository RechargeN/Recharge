import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../entities/class_workshop_draft_data.dart';
import '../entities/create_draft_entity.dart';
import '../entities/event_draft_data.dart';
import '../entities/publisher_ref.dart';
import '../repositories/event_timezone_repository.dart';

/// Stable ids and keys of one Class / Workshop publication (D3.6): every id is
/// a UUIDv5 in [namespace] under a scope of the signed-in account, the
/// publisher and the local Create draft, so every save repeats them and no
/// other account, publisher or draft can reuse them.
final class ClassWorkshopPublicationScope {
  ClassWorkshopPublicationScope({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
  });

  /// D3.6; fixed here and in the shared fixture.
  static const String namespace = '25caab8f-7f58-4dc7-bcce-ada94cd28458';

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;

  String get value =>
      'recharge:class-workshop-publication:v1:$accountId:'
      '${publisherRef.type.wireName}:${publisherRef.id}:$localDraftId';

  String _id(String name) => const Uuid().v5(namespace, '$value:$name');

  String occurrenceId(String localId) => _id('occurrence:$localId');

  String moduleId(String localId) => _id('module:$localId');

  String get coverAttachmentId => _id('attachment:cover');

  /// Stable for the photo reference in the Create draft, not its position.
  String galleryAttachmentId(String localMediaRef) =>
      _id('attachment:gallery:$localMediaRef');

  /// The Media intent of one exact upload: same attachment and bytes, same id.
  String uploadIntentId(String attachmentId, String sha256Hex) =>
      _id('upload:$attachmentId:$sha256Hex');

  /// Prefix of every Content idempotency key of this publication.
  String get keyBase =>
      'cw1-${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';
}

/// One medium of the Class: the cover or a gallery photo of the Create draft.
final class ClassWorkshopMediaAttachment {
  const ClassWorkshopMediaAttachment({
    required this.attachmentId,
    required this.role,
    required this.localRef,
  });

  final String attachmentId;

  /// `cover` or `gallery`.
  final String role;
  final String localRef;
}

final class ClassWorkshopContentBody {
  const ClassWorkshopContentBody({
    required this.body,
    required this.unsupported,
    required this.attachments,
  });

  final Map<String, Object?> body;

  /// Draft content the CW-V1 body cannot carry; a draft that has any is not
  /// sent at all (nothing is dropped silently).
  final List<String> unsupported;

  /// Cover first, then the gallery in the draft's order.
  final List<ClassWorkshopMediaAttachment> attachments;
}

/// Class / Workshop v1.2 §34 (CW-V1) → D3.6 wire body.
final class ClassWorkshopContentBodyMapper {
  const ClassWorkshopContentBodyMapper(this._timezones);

  final EventTimezoneRepository _timezones;

  static const String pinSection = 'class_workshop_pin';
  static const String mediaSection = 'class_workshop_media';
  static const String persistenceSection = 'class_workshop_details';

  static Map<String, Object?> pinEvidence(CreateDraftEntity d) =>
      <String, Object?>{
        'latitude': d.latitude,
        'longitude': d.longitude,
        'address': d.addressLine1,
        'city': d.city,
        'venue': d.venueName,
      };

  /// The Creator confirmed exactly this point; any later change unconfirms it.
  static bool pinConfirmed(CreateDraftEntity d) =>
      d.latitude != null &&
      d.longitude != null &&
      jsonEncode(d.sectionData[pinSection]) == jsonEncode(pinEvidence(d));

  ClassWorkshopContentBody map(
    CreateDraftEntity draft, {
    required ClassWorkshopPublicationScope scope,
    required String defaultContentLocale,
    Map<String, String> assetIds = const <String, String>{},
  }) {
    final ClassWorkshopDraftData? data = draft.classWorkshopData;
    if (draft.objectType != CreateObjectType.classWorkshop || data == null) {
      throw ArgumentError('Not a Class / Workshop draft');
    }
    final Object? rawMetadata = draft.sectionData[mediaSection];
    final Map<String, Object?> metadata = rawMetadata is Map<String, Object?>
        ? rawMetadata
        : <String, Object?>{};
    final Object locale = metadata['contentLocale'] ?? defaultContentLocale;
    final List<String> unsupported = <String>[
      if (rawMetadata != null && rawMetadata is! Map<String, Object?>)
        'media_metadata',
      for (final String key in metadata.keys)
        if (!const <String>{
          'contentLocale',
          'rightsConfirmed',
          'coverAltText',
          'galleryAltText',
        }.contains(key))
          'media_metadata:$key',
      if (locale is! String) 'content_locale',
      if (data.schemaVersion != ClassWorkshopDraftData.currentSchemaVersion)
        'schema_version',
      if (data.unknownFields.isNotEmpty) 'unknown_fields',
      // Generic legacy schedule and Booking flags have no CW-V1 meaning.
      if (draft.scheduleSlots.isNotEmpty) 'eventSlots',
      if (draft.waitlistEnabled ||
          draft.approvalRequired ||
          draft.currentParticipants != 0)
        'booking_claims',
      for (final String key in draft.sectionData.keys)
        if (!const <String>{'criteria', pinSection, mediaSection}.contains(key))
          'section:$key',
    ];

    final List<Map<String, Object?>> occurrences = <Map<String, Object?>>[];
    for (final (int index, ClassWorkshopOccurrence item)
        in data.occurrences.indexed) {
      final ({DateTime start, DateTime end})? utc = utcOf(data, item);
      if (utc == null) {
        unsupported.add('occurrence_time:${index + 1}');
        continue;
      }
      occurrences.add(<String, Object?>{
        'id': scope.occurrenceId(item.id),
        'local_date': item.localDate,
        'start_minute_local': item.startMinuteLocal,
        'end_minute_local': item.endMinuteLocal,
        if (item.fold != null) 'fold': item.fold!.wireName,
        'start_at_utc': utc.start.toIso8601String(),
        'end_at_utc': utc.end.toIso8601String(),
        if (item.title != null && item.title!.trim().isNotEmpty)
          'title': item.title!.trim(),
      });
    }

    final List<ClassWorkshopMediaAttachment> attachments = attachmentsOf(
      draft,
      scope,
    );
    Map<String, Object?> medium(ClassWorkshopMediaAttachment a) {
      final Object? gallery = metadata['galleryAltText'];
      final Object? alt = a.role == 'cover'
          ? metadata['coverAltText']
          : gallery is Map<String, Object?>
          ? gallery[a.localRef]
          : null;
      return <String, Object?>{
        'mediaId': assetIds[a.attachmentId] ?? 'loc_${a.attachmentId}',
        'altText': alt ?? <String, Object?>{},
      };
    }

    final ClassWorkshopDeliveryFormat format = data.deliveryFormat;
    final ClassWorkshopInstructor instructor = data.instructor;
    final ClassWorkshopPrice price = data.price;
    final ClassWorkshopEnrollment enrollment = data.enrollment;
    final Map<String, Object?> body = <String, Object?>{
      'title': draft.title.trim(),
      if (draft.shortDescription.trim().isNotEmpty)
        'shortDescription': draft.shortDescription.trim(),
      if (draft.fullDescription.trim().isNotEmpty)
        'fullDescription': draft.fullDescription.trim(),
      'contentLocale': locale,
      'categoryId': draft.mainCategory,
      'subcategoryId': draft.subcategory,
      if (draft.tags.isNotEmpty) 'tags': draft.tags,
      if (draft.sectionData['criteria']
          case final Map<String, Object?> criteria)
        'criteria': criteria,
      if (format.hasPlace)
        'location': <String, Object?>{
          'countryCode': draft.country,
          'city': draft.city,
          'venueName': draft.venueName,
          'addressLine1': draft.addressLine1,
          'latitude': draft.latitude,
          'longitude': draft.longitude,
          'pinConfirmed': pinConfirmed(draft),
        },
      'media': <String, Object?>{
        'coverImage': attachments
            .where((a) => a.role == 'cover')
            .map(medium)
            .firstOrNull,
        'gallery': attachments
            .where((a) => a.role == 'gallery')
            .map(medium)
            .toList(),
        'rightsConfirmed': metadata['rightsConfirmed'] == true,
      },
      'class_workshop': <String, Object?>{
        'schema_version': data.schemaVersion,
        if (data.offeringKind != null)
          'offering_kind': data.offeringKind!.wireName,
        'context_kind': data.contextKind.wireName,
        'delivery_format': format.wireName,
        if (format.hasPlace) 'public_location_mode': data.locationMode.wireName,
        if (format.hasPlace &&
            data.locationMode == ClassWorkshopLocationMode.areaOnly)
          'safe_area_label': data.safeAreaLabel.trim(),
        if (format == ClassWorkshopDeliveryFormat.onlineLive ||
            (format == ClassWorkshopDeliveryFormat.hybrid &&
                data.onlineProviderLabel.trim().isNotEmpty))
          'online_provider_label': data.onlineProviderLabel.trim(),
        'timezone_id': data.timezoneId,
        'timezone_confirmed': data.timezoneConfirmed,
        'dst_policy_version': data.dstPolicyVersion,
        'occurrences': occurrences,
        'instructor': <String, Object?>{
          'same_as_publisher': instructor.sameAsPublisher,
          if (!instructor.sameAsPublisher)
            'display_name': instructor.displayName.trim(),
          if (instructor.shortBio.trim().isNotEmpty)
            'short_bio': instructor.shortBio.trim(),
        },
        'learning': <String, Object?>{
          'outcomes': data.outcomes.map((v) => v.trim()).toList(),
          'modules': <Object?>[
            for (final ClassWorkshopModule module in data.modules)
              <String, Object?>{
                'id': scope.moduleId(module.id),
                'title': module.title.trim(),
              },
          ],
          if (data.prerequisitesListed != null)
            'prerequisites': <String, Object?>{
              'mode': data.prerequisitesListed! ? 'listed' : 'none',
              'items': data.prerequisitesListed!
                  ? data.prerequisites.map((v) => v.trim()).toList()
                  : const <String>[],
            },
          if (data.takeHomeResult.trim().isNotEmpty)
            'take_home_result': data.takeHomeResult.trim(),
        },
        'included_materials': data.includedMaterials
            .map((v) => v.trim())
            .toList(),
        'requirements': data.requirements.map((v) => v.trim()).toList(),
        if (data.declaredGroupLimit != null)
          'declared_group_limit': data.declaredGroupLimit,
        'price': <String, Object?>{
          'mode': price.mode.wireName,
          if (price.mode == ClassWorkshopPriceMode.fixed) ...<String, Object?>{
            'amount_minor': price.amountMinor,
            'currency_code': price.currencyCode,
            'scope': price.scope?.wireName,
          },
        },
        'enrollment': enrollment.mode == ClassWorkshopEnrollmentMode.external
            ? <String, Object?>{
                'mode': enrollment.mode.wireName,
                'external_url': enrollment.externalUrl.trim(),
              }
            : <String, Object?>{
                'mode': enrollment.mode.wireName,
                'information_reason': enrollment.informationReason.wireName,
              },
      },
    };
    return ClassWorkshopContentBody(
      body: body,
      unsupported: unsupported,
      attachments: attachments,
    );
  }

  List<ClassWorkshopMediaAttachment> attachmentsOf(
    CreateDraftEntity d,
    ClassWorkshopPublicationScope scope,
  ) => <ClassWorkshopMediaAttachment>[
    if (d.media.coverImage.trim().isNotEmpty)
      ClassWorkshopMediaAttachment(
        attachmentId: scope.coverAttachmentId,
        role: 'cover',
        localRef: d.media.coverImage,
      ),
    for (final String ref in d.media.gallery)
      ClassWorkshopMediaAttachment(
        attachmentId: scope.galleryAttachmentId(ref),
        role: 'gallery',
        localRef: ref,
      ),
  ];

  /// Wall time → UTC with the explicit fold; a gap, an unresolved overlap or
  /// an unknown zone is null and the draft is refused before anything is sent.
  ({DateTime start, DateTime end})? utcOf(
    ClassWorkshopDraftData data,
    ClassWorkshopOccurrence item,
  ) {
    final DateTime? date = DateTime.tryParse('${item.localDate}T00:00:00Z');
    if (date == null ||
        item.startMinuteLocal < 0 ||
        item.endMinuteLocal > 1440 ||
        item.startMinuteLocal >= item.endMinuteLocal) {
      return null;
    }
    DateTime? resolve(DateTime day, int minute) {
      try {
        final ResolvedEventLocalTime resolved = _timezones.resolve(
          timezoneId: data.timezoneId,
          year: day.year,
          month: day.month,
          day: day.day,
          minuteOfDay: minute,
          gapPolicy: EventDstGapPolicy.reject,
          overlapPolicy: item.fold == ClassWorkshopFold.later
              ? EventDstOverlapPolicy.laterOffset
              : EventDstOverlapPolicy.earlierOffset,
        );
        if (resolved.ambiguousLocalTime && item.fold == null) return null;
        return resolved.utc.toUtc();
      } on EventLocalTimeException {
        return null;
      }
    }

    final DateTime? start = resolve(date, item.startMinuteLocal);
    final DateTime? end = item.endMinuteLocal == 1440
        ? resolve(date.add(const Duration(days: 1)), 0)
        : resolve(date, item.endMinuteLocal);
    if (start == null || end == null) return null;
    return (start: start, end: end);
  }

  /// True when the wall time exists twice in the zone (DST overlap), so the
  /// Creator must choose the earlier or later offset.
  bool isAmbiguous(String timezoneId, String localDate, int minuteOfDay) {
    final DateTime? date = DateTime.tryParse('${localDate}T00:00:00Z');
    if (date == null) return false;
    try {
      return _timezones
          .resolve(
            timezoneId: timezoneId,
            year: date.year,
            month: date.month,
            day: date.day,
            minuteOfDay: minuteOfDay % 1440,
            gapPolicy: EventDstGapPolicy.reject,
            overlapPolicy: EventDstOverlapPolicy.earlierOffset,
          )
          .ambiguousLocalTime;
    } on EventLocalTimeException {
      return false;
    }
  }
}
