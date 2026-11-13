import '../entities/publisher_ref.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../entities/create_draft_entity.dart';
import '../entities/session_draft_data.dart';

/// Stable ids and keys of one Session publication (D3.5 §5.5): every id is a
/// UUIDv5 in [namespace] under a scope of the signed-in account, the publisher
/// and the local Create draft, so another account, another publisher or another
/// draft can never reuse them, and every save of the same draft repeats them.
final class SessionPublicationScope {
  SessionPublicationScope({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
  });

  /// D3.5 §5.5; fixed here and in the tests.
  static const String namespace = '5268bb1e-4fac-4bf1-aea8-135ec7efcf35';

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;

  String get value =>
      'recharge:session-publication:v1:$accountId:'
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
      'sp1-${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';
}

/// One medium of the Session: the cover or a gallery photo of the Create draft.
final class SessionMediaAttachment {
  const SessionMediaAttachment({
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

final class SessionContentBody {
  const SessionContentBody({
    required this.body,
    required this.unsupported,
    required this.attachments,
  });

  final Map<String, Object?> body;

  /// Draft content the Content Session body cannot carry; a draft that has any is
  /// not sent at all (nothing is dropped silently).
  final List<String> unsupported;

  /// Cover first, then the gallery in the draft's order.
  final List<SessionMediaAttachment> attachments;
}

/// Session v1.2 → D3.5 wire body; unsupported semantics are a local refusal.
final class SessionContentBodyMapper {
  const SessionContentBodyMapper();
  static Map<String, Object?> pinEvidence(CreateDraftEntity d) =>
      <String, Object?>{
        'latitude': d.latitude,
        'longitude': d.longitude,
        'address': d.addressLine1,
        'city': d.city,
        'venue': d.venueName,
      };
  static bool pinConfirmed(CreateDraftEntity d) =>
      d.latitude != null &&
      d.longitude != null &&
      jsonEncode(d.sectionData['session_pin']) == jsonEncode(pinEvidence(d));
  SessionContentBody map(
    CreateDraftEntity draft, {
    required SessionPublicationScope scope,
    required String serverOwnerUserId,
    required String defaultContentLocale,
    Map<String, String> assetIds = const <String, String>{},
  }) {
    final SessionDraftData? data = draft.sessionData;
    if (draft.objectType != CreateObjectType.session || data == null) {
      throw ArgumentError('Not a Session draft');
    }
    final rawMetadata = draft.sectionData['session_media'];
    final metadata = rawMetadata is Map<String, Object?>
        ? rawMetadata
        : <String, Object?>{};
    final locale = metadata['contentLocale'] ?? defaultContentLocale;
    final unsupported = <String>[
      if (rawMetadata != null && rawMetadata is! Map<String, Object?>)
        'media_metadata',
      for (final key in metadata.keys)
        if (!const <String>{
          'contentLocale',
          'rightsConfirmed',
          'coverAltText',
          'galleryAltText',
        }.contains(key))
          'media_metadata:$key',
      if (locale is! String) 'content_locale',

      if (data.schemaVersion != 1) 'schema_version',
      if (data.unknownFields.isNotEmpty) 'unknown_fields',
      if (data.legacySchedule != null) 'legacy_schedule',
      if (draft.scheduleSlots.isNotEmpty) 'eventSlots',
      if (draft.waitlistEnabled ||
          draft.approvalRequired ||
          draft.currentParticipants != 0)
        'booking_claims',
      for (final key in draft.sectionData.keys)
        if (!const <String>{
          'criteria',
          'session_pin',
          'session_media',
        }.contains(key))
          'section:$key',
    ];
    final attachments = attachmentsOf(draft, scope);
    Map<String, Object?> medium(SessionMediaAttachment a) {
      final gallery = metadata['galleryAltText'];
      final alt = a.role == 'cover'
          ? metadata['coverAltText']
          : gallery is Map<String, Object?>
          ? gallery[a.localRef]
          : null;
      return <String, Object?>{
        'mediaId': assetIds[a.attachmentId] ?? 'loc_${a.attachmentId}',
        'altText': alt ?? <String, Object?>{},
      };
    }

    final schedule = data.schedule;
    final body = <String, Object?>{
      'title': draft.title.trim(),
      'contentLocale': locale,
      if (draft.shortDescription.trim().isNotEmpty)
        'shortDescription': draft.shortDescription.trim(),
      if (draft.fullDescription.trim().isNotEmpty)
        'fullDescription': draft.fullDescription.trim(),
      'categoryId': draft.mainCategory,
      'subcategoryId': draft.subcategory,
      if (draft.tags.isNotEmpty) 'tags': draft.tags,
      if (draft.sectionData['criteria']
          case final Map<String, Object?> criteria)
        'criteria': criteria,
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
        'rightsConfirmed': metadata['rightsConfirmed'] == true,
        'coverImage': attachments
            .where((a) => a.role == 'cover')
            .map(medium)
            .firstOrNull,
        'gallery': attachments
            .where((a) => a.role == 'gallery')
            .map(medium)
            .toList(),
      },
      'session': <String, Object?>{
        'schema_version': data.schemaVersion,
        'resource_name': data.resourceName,
        'timezone_id': data.timezoneId,
        'timezone_confirmed': data.timezoneConfirmed,
        'amenity_ids': data.amenityIds.toList()..sort(),
        'max_party_size': data.maxPartySize,
        'revision': data.revision,
        'schedule': <String, Object?>{
          // Local authoring sequence starts at 0; wire candidate sequence starts at 1.
          'schedule_revision': schedule.scheduleRevision + 1,
          'dst_policy_version': schedule.dstPolicyVersion,
          'slot_duration_minutes': schedule.slotDurationMinutes,
          'buffer_after_slot_minutes': schedule.bufferAfterSlotMinutes,
          'min_notice_minutes': schedule.minNoticeMinutes,
          'projection_window_days': schedule.projectionWindowDays,
          'weekly_rules': schedule.weeklyRules
              .map(
                (rule) => <String, Object?>{
                  'id': scope.periodId(rule.id),
                  'iso_weekday': rule.isoWeekday,
                  'start_minute_local': rule.startMinuteLocal,
                  'end_minute_local_exclusive': rule.endMinuteLocalExclusive,
                },
              )
              .toList(),
        },
        'exceptions': data.exceptions
            .map(
              (ex) => <String, Object?>{
                'id': scope.exceptionId(ex.id),
                'start_date_local': ex.startDateLocal,
                'end_date_local': ex.endDateLocal,
                'all_day': ex.allDay,
                if (!ex.allDay) 'start_minute_local': ex.startMinuteLocal,
                if (!ex.allDay)
                  'end_minute_local_exclusive': ex.endMinuteLocalExclusive,
                if (ex.privateNote != null) 'private_note': ex.privateNote,
                'created_by_user_id': serverOwnerUserId,
                'created_at_utc': ex.createdAtUtc.toUtc().toIso8601String(),
              },
            )
            .toList(),
        'price': <String, Object?>{
          'mode': data.price.mode.name,
          if (data.price.amount != null)
            'amount_minor': data.price.amount!.amountMinor,
          if (data.price.amount != null)
            'currency_code': data.price.amount!.currencyCode,
        },
        'external_booking_url': data.externalBookingUrl,
        if (data.externalTermsUrl != null)
          'external_terms_url': data.externalTermsUrl,
      },
    };
    return SessionContentBody(
      body: body,
      unsupported: unsupported,
      attachments: attachments,
    );
  }

  List<SessionMediaAttachment> attachmentsOf(
    CreateDraftEntity d,
    SessionPublicationScope scope,
  ) => <SessionMediaAttachment>[
    if (d.media.coverImage.trim().isNotEmpty)
      SessionMediaAttachment(
        attachmentId: scope.coverAttachmentId,
        role: 'cover',
        localRef: d.media.coverImage,
      ),
    for (final ref in d.media.gallery)
      SessionMediaAttachment(
        attachmentId: scope.galleryAttachmentId(ref),
        role: 'gallery',
        localRef: ref,
      ),
  ];
}
