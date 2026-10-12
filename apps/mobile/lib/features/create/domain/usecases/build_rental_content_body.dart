import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../entities/create_availability.dart';
import '../entities/create_draft_entity.dart';
import '../entities/rental_draft_data.dart';

/// Stable ids and keys of one Rental publication (D3.3 §4): every id is a
/// UUIDv5 in [namespace] under a scope of the signed-in account, the publisher
/// and the local Create draft, so another account, publisher or draft can never
/// reuse them, and every save of the same draft repeats them.
final class RentalPublicationScope {
  RentalPublicationScope({
    required this.accountId,
    required this.publisherRef,
    required this.localDraftId,
  });

  /// D3.3 §4; fixed here and in the tests.
  static const String namespace = '9e258ab9-3a98-4009-aa3e-4005091488aa';

  final String accountId;
  final PublisherRef publisherRef;
  final String localDraftId;

  String get value =>
      'recharge:rental-publication:v1:$accountId:'
      '${publisherRef.type.wireName}:${publisherRef.id}:$localDraftId';

  String _id(String name) => const Uuid().v5(namespace, '$value:$name');

  String groupId(String localGroupId) => _id('group:$localGroupId');

  String blockId(String localBlockId) => _id('block:$localBlockId');

  String hoursId(int index) => _id('hours:$index');

  String get coverAttachmentId => _id('attachment:cover');

  /// Stable for the photo reference in the Create draft, not its position.
  String galleryAttachmentId(String localMediaRef) =>
      _id('attachment:gallery:$localMediaRef');

  /// The Media intent of one exact upload: same attachment and bytes, same id.
  String uploadIntentId(String attachmentId, String sha256Hex) =>
      _id('upload:$attachmentId:$sha256Hex');

  /// Prefix of every Content idempotency key of this publication.
  String get keyBase =>
      'rp1-${sha256.convert(utf8.encode(value)).toString().substring(0, 24)}';
}

/// One listing photo of the Rental: the cover or a gallery photo of the shared
/// Create media (§2 Q2).
final class RentalMediaAttachment {
  const RentalMediaAttachment({
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

final class RentalContentBody {
  const RentalContentBody({
    required this.body,
    required this.unsupported,
    required this.attachments,
  });

  final Map<String, Object?> body;

  /// Draft content the Content Rental body cannot carry, or must not carry for
  /// this account; a draft that has any is not sent at all.
  final List<String> unsupported;

  /// Cover first, then the gallery in the draft's order.
  final List<RentalMediaAttachment> attachments;
}

/// Maps a Create Rental draft to the public Content Rental body (D3.3 §4,
/// RNT-CRT-01 §7). The private authoring data is never read here. Listing
/// photos come from the shared Create media (§2 Q2): the cover, then the
/// gallery. Local ids become stable UUIDv5. The attestation and the occupancy
/// blocks carry the server id of the signed-in user [serverActorUserId] only
/// when this same account gave them in Create ([localAccountId]); someone
/// else's confirmation is never rewritten (§2 Q3) and stops the whole draft.
final class RentalContentBodyMapper {
  const RentalContentBodyMapper();

  RentalContentBody map(
    CreateDraftEntity draft, {
    required RentalPublicationScope scope,
    required String localAccountId,
    required String serverActorUserId,
    Map<String, String> assetIds = const <String, String>{},
  }) {
    final RentalDraftData? rental = draft.rentalData;
    if (draft.objectType != CreateObjectType.rental || rental == null) {
      throw ArgumentError('Not a Rental draft');
    }
    final String? attestedBy = rental.attestation.acceptedByUserId;
    final List<String> unsupported = <String>[
      if (rental.mediaRefs.isNotEmpty) 'rental.listing_media',
      if (rental.inventoryGroups.any((group) => group.photoRefs.isNotEmpty))
        'rental.group_photos',
      if (attestedBy != null &&
          attestedBy.isNotEmpty &&
          attestedBy != localAccountId)
        'rental.attestation_foreign',
      if (rental.availability.blocks.any(
        (block) => block.createdByUserId != localAccountId,
      ))
        'rental.block_foreign',
      if (rental.handover.scheduleMode == RentalScheduleMode.openingHours &&
          rental.handover.openingHours.any(
            (rule) => rule.exceptionDateIso != null || rule.dayOfWeek == null,
          ))
        'rental.hours_exceptions',
      if (rental.unknownFields.isNotEmpty) 'unknown_fields',
    ];
    final List<RentalMediaAttachment> attachments = attachmentsOf(draft, scope);
    String mediaId(RentalMediaAttachment item) =>
        assetIds[item.attachmentId] ?? 'loc_${item.attachmentId}';
    String groupId(String id) => id.startsWith('loc_') ? scope.groupId(id) : id;

    final Map<String, Object?> body = <String, Object?>{
      'title': rental.title.trim(),
      'shortDescription': rental.shortDescription.trim(),
      'fullDescription': rental.fullDescription.trim(),
      'categoryId': rental.categoryId.trim(),
      'subcategoryId': rental.subcategoryId.trim(),
      'categoryConfirmed': rental.categoryConfirmed,
      if (_text(rental.brandModel) case final String value) 'brandModel': value,
      'mediaRefs': <String>[
        for (final RentalMediaAttachment item in attachments) mediaId(item),
      ],
      'inventoryGroups': <Map<String, Object?>>[
        for (final RentalInventoryGroup group in rental.inventoryGroups)
          <String, Object?>{
            'id': groupId(group.id),
            'label': group.label.trim(),
            'quantity': group.quantity,
            'condition': _condition(group.condition),
            if (_text(group.sizeOrVariant) case final String value)
              'sizeOrVariant': value,
            if (group.includedAccessories.isNotEmpty)
              'includedAccessories': List<String>.of(group.includedAccessories),
            'status': group.status.name,
          },
      ],
      'availability': <String, Object?>{
        'timeZoneId': rental.availability.timeZoneId,
        if (rental.availability.coverage
            case final RentalAvailabilityCoverage coverage)
          'coverage': <String, Object?>{
            'startsAtUtc': _instant(coverage.startsAtUtc),
            'endsAtUtc': _instant(coverage.endsAtUtc),
            'confirmedAtUtc': _instant(coverage.confirmedAtUtc),
          },
        'blocks': <Map<String, Object?>>[
          for (final RentalAvailabilityBlock block
              in rental.availability.blocks)
            <String, Object?>{
              'id': block.id.startsWith('loc_')
                  ? scope.blockId(block.id)
                  : block.id,
              'groupId': groupId(block.groupId),
              'startsAtUtc': _instant(block.startsAtUtc),
              'endsAtUtc': _instant(block.endsAtUtc),
              'unitsBlocked': block.unitsBlocked,
              'source': _blockSource(block.source),
              'status': block.status.name,
              // Create counts block revisions from 0 (never revised); the
              // contract counts from 1 (§4). A renumbering, not a new value.
              'revision': block.revision + 1,
              'createdByUserId': serverActorUserId,
              'createdAtUtc': _instant(block.createdAtUtc),
              'updatedAtUtc': _instant(block.updatedAtUtc),
            },
        ],
      },
      'handover': _handover(rental.handover, scope),
      'terms': _terms(rental.terms),
      'pricing': _pricing(rental.pricing),
      'fulfillment': <String, Object?>{
        'mode': 'external_link',
        if (_text(rental.fulfillment.externalBookingUrl) case final String url)
          'externalBookingUrl': url,
      },
      'attestation': <String, Object?>{
        'policyVersion': rental.attestation.policyVersion,
        if (rental.attestation.acceptedAtUtc case final DateTime at)
          'acceptedAtUtc': _instant(at),
        if (attestedBy != null && attestedBy.isNotEmpty)
          'acceptedByUserId': serverActorUserId,
        'hasRightToOffer': rental.attestation.hasRightToOffer,
        'listingAccurate': rental.attestation.listingAccurate,
        'prohibitedItemsAcknowledged':
            rental.attestation.prohibitedItemsAcknowledged,
      },
    };
    return RentalContentBody(
      body: body,
      unsupported: unsupported,
      attachments: attachments,
    );
  }

  /// The listing photos in body order: the cover, then the gallery as ordered
  /// in the draft, each with its stable attachment id.
  List<RentalMediaAttachment> attachmentsOf(
    CreateDraftEntity draft,
    RentalPublicationScope scope,
  ) => <RentalMediaAttachment>[
    if (draft.media.coverImage.trim().isNotEmpty)
      RentalMediaAttachment(
        attachmentId: scope.coverAttachmentId,
        role: 'cover',
        localRef: draft.media.coverImage,
      ),
    for (final String ref in draft.media.gallery)
      RentalMediaAttachment(
        attachmentId: scope.galleryAttachmentId(ref),
        role: 'gallery',
        localRef: ref,
      ),
  ];

  static String? _text(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  static String _instant(DateTime value) => value.toUtc().toIso8601String();

  static Map<String, Object?> _money(RentalMoneyDraft money) =>
      <String, Object?>{
        'minorUnits': money.amountMinor,
        'currencyCode': money.currencyCode,
      };

  static String _condition(RentalCondition value) => switch (value) {
    RentalCondition.rentalNew => 'new',
    RentalCondition.likeNew => 'like_new',
    RentalCondition.good => 'good',
    RentalCondition.worn => 'worn',
  };

  static String _blockSource(RentalBlockSource value) => switch (value) {
    RentalBlockSource.manualExternalRental => 'manual_external_rental',
    RentalBlockSource.maintenance => 'maintenance',
    RentalBlockSource.ownerUnavailable => 'owner_unavailable',
    RentalBlockSource.other => 'other',
  };

  static Map<String, Object?> _handover(
    RentalHandoverDraft handover,
    RentalPublicationScope scope,
  ) {
    final bool business =
        handover.disclosure == RentalLocationDisclosure.publicBusinessAddress;
    final bool hours = handover.scheduleMode == RentalScheduleMode.openingHours;
    final List<CreateOpeningHoursDraftRule> weekly = handover.openingHours
        .where(
          (rule) =>
              rule.dayOfWeek != null &&
              rule.exceptionDateIso == null &&
              !rule.isClosedAllDay &&
              rule.openMinutesSinceLocalMidnight != null &&
              rule.closeMinutesSinceLocalMidnight != null,
        )
        .toList();
    return <String, Object?>{
      'pickupPlaceName': handover.pickupPlaceName.trim(),
      'publicAreaLabel': handover.publicAreaLabel.trim(),
      // An approximate area never carries an address (as the public projection).
      if (business)
        if (_text(handover.publicAddress) case final String value)
          'publicAddress': value,
      if (handover.publicLatitude != null && handover.publicLongitude != null)
        'publicGeo': <String, Object?>{
          'latitude': handover.publicLatitude,
          'longitude': handover.publicLongitude,
        },
      'publicGeoPrecisionMeters': handover.publicGeoPrecisionMeters,
      'disclosure': business ? 'public_business_address' : 'approximate_area',
      'scheduleMode': hours ? 'opening_hours' : 'by_arrangement',
      if (hours)
        'openingHours': <Map<String, Object?>>[
          for (final (int index, CreateOpeningHoursDraftRule rule)
              in weekly.indexed)
            <String, Object?>{
              'id': scope.hoursId(index),
              'dayOfWeek': rule.dayOfWeek,
              'openMinute': rule.openMinutesSinceLocalMidnight,
              'closeMinute': rule.closeMinutesSinceLocalMidnight,
              'closesNextDay':
                  rule.closeMinutesSinceLocalMidnight! <
                  rule.openMinutesSinceLocalMidnight!,
            },
        ],
      'deliveryAvailable': handover.deliveryAvailable,
      // A disabled option carries no children (RNT-CRT-01 §9 п.8).
      if (handover.deliveryAvailable) ...<String, Object?>{
        if (handover.deliveryRadiusKm != null)
          'deliveryRadiusKm': handover.deliveryRadiusKm,
        if (handover.deliveryFee case final RentalMoneyDraft fee)
          'deliveryFee': _money(fee),
        if (_text(handover.deliveryTerms) case final String value)
          'deliveryTerms': value,
      },
    };
  }

  static Map<String, Object?> _terms(RentalTerms terms) => <String, Object?>{
    'offeredMinMinutes': terms.offeredMinMinutes,
    'offeredMaxMinutes': terms.offeredMaxMinutes,
    if (terms.minRenterAge != null) 'minRenterAge': terms.minRenterAge,
    'idRequiredAtHandover': terms.idRequiredAtHandover,
    if (_text(terms.usageRestrictions) case final String value)
      'usageRestrictions': value,
    if (_text(terms.safetyNotice) case final String value)
      'safetyNotice': value,
    'includedAccessoriesConfirmation': terms.includedAccessoriesConfirmation,
  };

  static Map<String, Object?> _pricing(RentalPricingPolicy pricing) {
    final RentalDepositPolicy deposit = pricing.deposit;
    return <String, Object?>{
      'currencyCode': pricing.currencyCode,
      'billingUnitMinutes': pricing.billingUnit.minutes,
      'rateSteps': <Map<String, Object?>>[
        for (final RentalRateStep step in pricing.rateSteps)
          <String, Object?>{
            'minUnits': step.minUnits,
            'unitPrice': _money(step.unitPrice),
          },
      ],
      // RNT-CRT-01 §10.2: V1 always bills every started unit.
      'billingRounding': 'started_unit',
      'deposit': <String, Object?>{
        'amount': _money(deposit.amount),
        'collectionMethod': switch (deposit.collectionMethod) {
          RentalDepositCollectionMethod.none => 'none',
          RentalDepositCollectionMethod.atHandover => 'at_handover',
          RentalDepositCollectionMethod.externalProvider => 'external_provider',
          RentalDepositCollectionMethod.other => 'other',
        },
        if (_text(deposit.terms) case final String value) 'terms': value,
      },
      'damagePolicy': pricing.damagePolicy.trim(),
      if (_text(pricing.lateReturnPolicy) case final String value)
        'lateReturnPolicy': value,
      'cancellationPolicyId': pricing.cancellationPolicyId,
      if (_text(pricing.cancellationPolicyNote) case final String value)
        'cancellationPolicyNote': value,
    };
  }
}
