import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../entities/activity_draft_data.dart';
import '../entities/create_draft_entity.dart';
import '../entities/publisher_ref.dart';

/// Stable ids and keys of one Activity publication (D3.2 §5.5): every id is a
/// UUIDv5 in [namespace] under a scope of the signed-in account, the publisher
/// and the local Create draft, so another account, another publisher or another
/// draft can never reuse them, and every save of the same draft repeats them.
final class ActivityPublicationScope {
  ActivityPublicationScope({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
  });

  /// D3.2 §5.5; fixed here and in the tests.
  static const String namespace = '82167158-6d3c-4536-aec4-b7f4f12b012b';

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;

  String get value =>
      'recharge:activity-publication:v1:$accountId:'
      '${publisherRef.type.wireName}:${publisherRef.id}:$localDraftId';

  String _id(String name) => const Uuid().v5(namespace, '$value:$name');

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
      'ap1-${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';
}

/// One medium of the Activity: the cover or a gallery photo of the Create
/// draft.
final class ActivityMediaAttachment {
  const ActivityMediaAttachment({
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

final class ActivityContentBody {
  const ActivityContentBody({
    required this.body,
    required this.unsupported,
    required this.attachments,
  });

  final Map<String, Object?> body;

  /// Draft content the Content Activity body cannot carry; a draft that has any
  /// is not sent at all (nothing is dropped silently).
  final List<String> unsupported;

  /// Cover first, then the gallery in the draft's order.
  final List<ActivityMediaAttachment> attachments;
}

/// Maps a Create Recharge Activity draft to the Content Activity body (D3.2
/// §5.2, §5.3) — the normalized contract of ACT-CRT-01 §12. Strings are
/// trimmed and empty optionals are left out (§13 step 4); a caution that is not
/// informal and has no note is no caution (§8 step 2). Nothing is invented: a
/// value the draft does not hold is not sent, and the server's own rules
/// decide the rest. A linked Place is never sent: the server cannot resolve it
/// yet (§2.4), so a draft that has one is refused before anything is sent.
final class ActivityContentBodyMapper {
  const ActivityContentBodyMapper();

  ActivityContentBody map(
    CreateDraftEntity draft, {
    required ActivityPublicationScope scope,
    Map<String, String> assetIds = const <String, String>{},
  }) {
    final ActivityDraftData? activity = draft.activityData;
    if (draft.objectType != CreateObjectType.activity || activity == null) {
      throw ArgumentError('Not an Activity draft');
    }
    final List<String> unsupported = <String>[
      if (_text(activity.location.linkedPlaceId) != null)
        'location.linked_place',
      if (draft.tags.isNotEmpty) 'tags',
      if (activity.unknownFields.isNotEmpty) 'unknown_fields',
    ];
    final List<ActivityMediaAttachment> attachments = attachmentsOf(
      draft,
      scope,
    );
    String mediaId(ActivityMediaAttachment item) =>
        assetIds[item.attachmentId] ?? 'loc_${item.attachmentId}';

    final Object? criteria = draft.sectionData['criteria'];
    final Map<String, Object?> body = <String, Object?>{
      'title': draft.title.trim(),
      'categoryId': draft.mainCategory,
      'subcategoryId': draft.subcategory,
      if (_text(draft.shortDescription) case final String value)
        'shortDescription': value,
      if (_text(draft.fullDescription) case final String value)
        'fullDescription': value,
      if (criteria is Map && criteria.isNotEmpty)
        'criteria': Map<String, Object?>.from(criteria),
      'media': <String, Object?>{
        for (final ActivityMediaAttachment item in attachments)
          if (item.role == 'cover')
            'coverImage': <String, Object?>{'mediaId': mediaId(item)},
        'gallery': <Map<String, Object?>>[
          for (final ActivityMediaAttachment item in attachments)
            if (item.role == 'gallery')
              <String, Object?>{'mediaId': mediaId(item)},
        ],
      },
      'location': _location(activity.location),
      'typicalDurationMinutes': _range(activity.typicalDurationMinutes),
      if (activity.suggestedGroupSize case final ActivityIntRangeDraft range)
        'suggestedGroupSize': _range(range),
      if (_contribution(activity.optionalContribution)
          case final Map<String, Object?> value)
        'optionalContribution': value,
      if (_bestTime(activity.bestTime) case final Map<String, Object?> value)
        'bestTime': value,
    };
    return ActivityContentBody(
      body: body,
      unsupported: unsupported,
      attachments: attachments,
    );
  }

  /// The draft's media in body order: the cover, then the gallery as ordered
  /// in the draft, each with its stable attachment id (§5.5).
  List<ActivityMediaAttachment> attachmentsOf(
    CreateDraftEntity draft,
    ActivityPublicationScope scope,
  ) => <ActivityMediaAttachment>[
    if (draft.media.coverImage.trim().isNotEmpty)
      ActivityMediaAttachment(
        attachmentId: scope.coverAttachmentId,
        role: 'cover',
        localRef: draft.media.coverImage,
      ),
    for (final String ref in draft.media.gallery)
      ActivityMediaAttachment(
        attachmentId: scope.galleryAttachmentId(ref),
        role: 'gallery',
        localRef: ref,
      ),
  ];

  static String? _text(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  static Map<String, Object?> _location(ActivityLocationDraft location) {
    final ActivityAccessCautionDraft? caution = location.accessCaution;
    final String? cautionNote = _text(caution?.note);
    return <String, Object?>{
      if (location.latitude != null) 'latitude': location.latitude,
      if (location.longitude != null) 'longitude': location.longitude,
      'pinConfirmed': location.pinConfirmed,
      if (_text(location.addressLine) case final String value)
        'addressLine': value,
      if (_text(location.accessNotes) case final String value)
        'accessNotes': value,
      if (caution != null && (caution.isInformal || cautionNote != null))
        'accessCaution': <String, Object?>{
          'isInformal': caution.isInformal,
          if (cautionNote != null) 'note': cautionNote,
        },
    };
  }

  static Map<String, Object?> _range(ActivityIntRangeDraft range) =>
      <String, Object?>{'min': range.min, 'max': range.max};

  static Map<String, Object?>? _contribution(
    ActivityOptionalContributionDraft? contribution,
  ) {
    if (contribution == null) return null;
    final String? note = _text(contribution.note);
    final ActivityContributionAmountDraft? amount = contribution.amountHint;
    if (contribution.kind == null && note == null && amount == null) {
      return null;
    }
    return <String, Object?>{
      if (contribution.kind != null) 'kind': contribution.kind!.name,
      if (note != null) 'note': note,
      if (amount != null)
        'amountHint': <String, Object?>{
          'amountMinor': amount.amountMinor,
          'currencyCode': amount.currencyCode,
        },
    };
  }

  static Map<String, Object?>? _bestTime(ActivityBestTimeDraft? bestTime) {
    if (bestTime == null ||
        (bestTime.timeOfDay == null && bestTime.season == null)) {
      return null;
    }
    return <String, Object?>{
      if (bestTime.timeOfDay != null) 'timeOfDay': bestTime.timeOfDay!.name,
      if (bestTime.season != null) 'season': bestTime.season!.name,
    };
  }
}
