import 'create_availability.dart';
import 'publisher_ref.dart';

export 'publisher_ref.dart';

/// Temporary ad-hoc money representation for Rental, mirroring
/// `EventMoneyDraft`. Migrates to the shared `Money` primitive
/// (`shared/primitives/money/`) without semantic change once M2-B lands —
/// see docs/architecture/MOBILE_ARCHITECTURE_M2_PRIMITIVE_RECONCILIATION_PLAN.md.
class RentalMoneyDraft {
  const RentalMoneyDraft({
    required this.amountMinor,
    required this.currencyCode,
  });

  final int amountMinor;
  final String currencyCode;

  RentalMoneyDraft copyWith({int? amountMinor, String? currencyCode}) {
    return RentalMoneyDraft(
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'amountMinor': amountMinor,
    'currencyCode': currencyCode,
  };

  factory RentalMoneyDraft.fromMap(Map<String, Object?> map) =>
      RentalMoneyDraft(
        amountMinor: (map['amountMinor'] as num).toInt(),
        currencyCode: map['currencyCode']! as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RentalMoneyDraft &&
          amountMinor == other.amountMinor &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => Object.hash(amountMinor, currencyCode);
}

enum RentalCondition { rentalNew, likeNew, good, worn }

enum RentalUnitGroupStatus { available, paused, retired }

class RentalInventoryGroup {
  const RentalInventoryGroup({
    required this.id,
    required this.label,
    required this.quantity,
    required this.condition,
    this.sizeOrVariant,
    this.includedAccessories = const <String>[],
    this.photoRefs = const <String>[],
    this.status = RentalUnitGroupStatus.available,
  });

  final String id;
  final String label;
  final int quantity;
  final RentalCondition condition;
  final String? sizeOrVariant;
  final List<String> includedAccessories;
  final List<String> photoRefs;
  final RentalUnitGroupStatus status;

  RentalInventoryGroup copyWith({
    String? id,
    String? label,
    int? quantity,
    RentalCondition? condition,
    String? sizeOrVariant,
    bool clearSizeOrVariant = false,
    List<String>? includedAccessories,
    List<String>? photoRefs,
    RentalUnitGroupStatus? status,
  }) {
    return RentalInventoryGroup(
      id: id ?? this.id,
      label: label ?? this.label,
      quantity: quantity ?? this.quantity,
      condition: condition ?? this.condition,
      sizeOrVariant: clearSizeOrVariant
          ? null
          : (sizeOrVariant ?? this.sizeOrVariant),
      includedAccessories: includedAccessories ?? this.includedAccessories,
      photoRefs: photoRefs ?? this.photoRefs,
      status: status ?? this.status,
    );
  }
}

enum RentalBlockSource {
  manualExternalRental,
  maintenance,
  ownerUnavailable,
  other,
}

enum RentalBlockStatus { active, cancelled }

/// Half-open UTC interval `[startsAtUtc, endsAtUtc)` during which
/// `unitsBlocked` units of `groupId` are unavailable. Manually maintained by
/// Creator — never inferred from a real booking backend (spec §8).
class RentalAvailabilityBlock {
  const RentalAvailabilityBlock({
    required this.id,
    required this.groupId,
    required this.startsAtUtc,
    required this.endsAtUtc,
    required this.unitsBlocked,
    required this.source,
    this.status = RentalBlockStatus.active,
    this.revision = 0,
    required this.createdByUserId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String id;
  final String groupId;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
  final int unitsBlocked;
  final RentalBlockSource source;
  final RentalBlockStatus status;
  final int revision;
  final String createdByUserId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  bool get isActive => status == RentalBlockStatus.active;

  bool overlaps(DateTime instantUtc) =>
      !instantUtc.isBefore(startsAtUtc) && instantUtc.isBefore(endsAtUtc);

  bool overlapsRange(DateTime rangeStartUtc, DateTime rangeEndUtc) =>
      startsAtUtc.isBefore(rangeEndUtc) && rangeStartUtc.isBefore(endsAtUtc);

  RentalAvailabilityBlock copyWith({
    DateTime? startsAtUtc,
    DateTime? endsAtUtc,
    int? unitsBlocked,
    RentalBlockSource? source,
    RentalBlockStatus? status,
    int? revision,
    DateTime? updatedAtUtc,
  }) {
    return RentalAvailabilityBlock(
      id: id,
      groupId: groupId,
      startsAtUtc: startsAtUtc ?? this.startsAtUtc,
      endsAtUtc: endsAtUtc ?? this.endsAtUtc,
      unitsBlocked: unitsBlocked ?? this.unitsBlocked,
      source: source ?? this.source,
      status: status ?? this.status,
      revision: revision ?? this.revision,
      createdByUserId: createdByUserId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}

/// The interval Creator has explicitly reviewed and confirmed, plus when.
/// Absence or staleness of this confirmation is what makes an otherwise
/// "empty blocks" result honestly `unknown` rather than a fabricated
/// `declared_available` (spec §8.3).
class RentalAvailabilityCoverage {
  const RentalAvailabilityCoverage({
    required this.startsAtUtc,
    required this.endsAtUtc,
    required this.confirmedAtUtc,
  });

  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
  final DateTime confirmedAtUtc;

  bool covers(DateTime rangeStartUtc, DateTime rangeEndUtc) =>
      !rangeStartUtc.isBefore(startsAtUtc) && !rangeEndUtc.isAfter(endsAtUtc);

  RentalAvailabilityCoverage copyWith({
    DateTime? startsAtUtc,
    DateTime? endsAtUtc,
    DateTime? confirmedAtUtc,
  }) {
    return RentalAvailabilityCoverage(
      startsAtUtc: startsAtUtc ?? this.startsAtUtc,
      endsAtUtc: endsAtUtc ?? this.endsAtUtc,
      confirmedAtUtc: confirmedAtUtc ?? this.confirmedAtUtc,
    );
  }
}

class RentalAvailabilityCalendar {
  const RentalAvailabilityCalendar({
    required this.timeZoneId,
    this.coverage,
    this.blocks = const <RentalAvailabilityBlock>[],
  });

  final String timeZoneId;
  final RentalAvailabilityCoverage? coverage;
  final List<RentalAvailabilityBlock> blocks;

  RentalAvailabilityCalendar copyWith({
    String? timeZoneId,
    RentalAvailabilityCoverage? coverage,
    bool clearCoverage = false,
    List<RentalAvailabilityBlock>? blocks,
  }) {
    return RentalAvailabilityCalendar(
      timeZoneId: timeZoneId ?? this.timeZoneId,
      coverage: clearCoverage ? null : (coverage ?? this.coverage),
      blocks: blocks ?? this.blocks,
    );
  }
}

enum RentalLocationDisclosure { approximateArea, publicBusinessAddress }

enum RentalScheduleMode { openingHours, byArrangement }

class RentalHandoverDraft {
  const RentalHandoverDraft({
    required this.pickupPlaceName,
    required this.publicAreaLabel,
    this.publicAddress,
    this.publicLatitude,
    this.publicLongitude,
    this.publicGeoPrecisionMeters = 500,
    this.disclosure = RentalLocationDisclosure.approximateArea,
    this.scheduleMode = RentalScheduleMode.openingHours,
    this.openingHours = const <CreateOpeningHoursDraftRule>[],
    this.deliveryAvailable = false,
    this.deliveryRadiusKm,
    this.deliveryFee,
    this.deliveryTerms,
  });

  final String pickupPlaceName;
  final String publicAreaLabel;
  final String? publicAddress;
  final double? publicLatitude;
  final double? publicLongitude;
  final int publicGeoPrecisionMeters;
  final RentalLocationDisclosure disclosure;
  final RentalScheduleMode scheduleMode;
  final List<CreateOpeningHoursDraftRule> openingHours;
  final bool deliveryAvailable;
  final double? deliveryRadiusKm;
  final RentalMoneyDraft? deliveryFee;
  final String? deliveryTerms;

  bool get hasPublicGeo => publicLatitude != null && publicLongitude != null;

  RentalHandoverDraft copyWith({
    String? pickupPlaceName,
    String? publicAreaLabel,
    String? publicAddress,
    bool clearPublicAddress = false,
    double? publicLatitude,
    bool clearPublicLatitude = false,
    double? publicLongitude,
    bool clearPublicLongitude = false,
    int? publicGeoPrecisionMeters,
    RentalLocationDisclosure? disclosure,
    RentalScheduleMode? scheduleMode,
    List<CreateOpeningHoursDraftRule>? openingHours,
    bool? deliveryAvailable,
    double? deliveryRadiusKm,
    bool clearDeliveryRadiusKm = false,
    RentalMoneyDraft? deliveryFee,
    bool clearDeliveryFee = false,
    String? deliveryTerms,
    bool clearDeliveryTerms = false,
  }) {
    final bool nextDeliveryAvailable =
        deliveryAvailable ?? this.deliveryAvailable;
    return RentalHandoverDraft(
      pickupPlaceName: pickupPlaceName ?? this.pickupPlaceName,
      publicAreaLabel: publicAreaLabel ?? this.publicAreaLabel,
      publicAddress: clearPublicAddress
          ? null
          : (publicAddress ?? this.publicAddress),
      publicLatitude: clearPublicLatitude
          ? null
          : (publicLatitude ?? this.publicLatitude),
      publicLongitude: clearPublicLongitude
          ? null
          : (publicLongitude ?? this.publicLongitude),
      publicGeoPrecisionMeters:
          publicGeoPrecisionMeters ?? this.publicGeoPrecisionMeters,
      disclosure: disclosure ?? this.disclosure,
      scheduleMode: scheduleMode ?? this.scheduleMode,
      openingHours: openingHours ?? this.openingHours,
      deliveryAvailable: nextDeliveryAvailable,
      deliveryRadiusKm: !nextDeliveryAvailable || clearDeliveryRadiusKm
          ? null
          : (deliveryRadiusKm ?? this.deliveryRadiusKm),
      deliveryFee: !nextDeliveryAvailable || clearDeliveryFee
          ? null
          : (deliveryFee ?? this.deliveryFee),
      deliveryTerms: !nextDeliveryAvailable || clearDeliveryTerms
          ? null
          : (deliveryTerms ?? this.deliveryTerms),
    );
  }
}

class RentalTerms {
  const RentalTerms({
    required this.offeredMinMinutes,
    required this.offeredMaxMinutes,
    this.minRenterAge,
    this.idRequiredAtHandover = false,
    this.usageRestrictions,
    this.safetyNotice,
    this.includedAccessoriesConfirmation = false,
  });

  final int offeredMinMinutes;
  final int offeredMaxMinutes;
  final int? minRenterAge;
  final bool idRequiredAtHandover;
  final String? usageRestrictions;
  final String? safetyNotice;
  final bool includedAccessoriesConfirmation;

  RentalTerms copyWith({
    int? offeredMinMinutes,
    int? offeredMaxMinutes,
    int? minRenterAge,
    bool clearMinRenterAge = false,
    bool? idRequiredAtHandover,
    String? usageRestrictions,
    bool clearUsageRestrictions = false,
    String? safetyNotice,
    bool clearSafetyNotice = false,
    bool? includedAccessoriesConfirmation,
  }) {
    return RentalTerms(
      offeredMinMinutes: offeredMinMinutes ?? this.offeredMinMinutes,
      offeredMaxMinutes: offeredMaxMinutes ?? this.offeredMaxMinutes,
      minRenterAge: clearMinRenterAge
          ? null
          : (minRenterAge ?? this.minRenterAge),
      idRequiredAtHandover: idRequiredAtHandover ?? this.idRequiredAtHandover,
      usageRestrictions: clearUsageRestrictions
          ? null
          : (usageRestrictions ?? this.usageRestrictions),
      safetyNotice: clearSafetyNotice
          ? null
          : (safetyNotice ?? this.safetyNotice),
      includedAccessoriesConfirmation:
          includedAccessoriesConfirmation ??
          this.includedAccessoriesConfirmation,
    );
  }
}

/// Billing unit in minutes: hour (60), day (1440) or week (10080). A listing
/// has exactly one billing unit — mixing units on one rate plan is forbidden
/// (spec §10.2 rule 1).
enum RentalBillingUnit {
  hour(60),
  day(1440),
  week(10080);

  const RentalBillingUnit(this.minutes);

  final int minutes;
}

/// One step of a monotonically-non-increasing rate ladder: from `minUnits`
/// billable units onward, `unitPrice` applies per unit (spec §10.2).
class RentalRateStep {
  const RentalRateStep({required this.minUnits, required this.unitPrice});

  final int minUnits;
  final RentalMoneyDraft unitPrice;

  RentalRateStep copyWith({int? minUnits, RentalMoneyDraft? unitPrice}) {
    return RentalRateStep(
      minUnits: minUnits ?? this.minUnits,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

enum RentalDepositCollectionMethod { none, atHandover, externalProvider, other }

class RentalDepositPolicy {
  const RentalDepositPolicy({
    required this.amount,
    required this.collectionMethod,
    this.terms,
  });

  final RentalMoneyDraft amount;
  final RentalDepositCollectionMethod collectionMethod;
  final String? terms;

  bool get isZero => amount.amountMinor == 0;

  RentalDepositPolicy copyWith({
    RentalMoneyDraft? amount,
    RentalDepositCollectionMethod? collectionMethod,
    String? terms,
    bool clearTerms = false,
  }) {
    return RentalDepositPolicy(
      amount: amount ?? this.amount,
      collectionMethod: collectionMethod ?? this.collectionMethod,
      terms: clearTerms ? null : (terms ?? this.terms),
    );
  }
}

class RentalPricingPolicy {
  const RentalPricingPolicy({
    required this.currencyCode,
    required this.billingUnit,
    this.rateSteps = const <RentalRateStep>[],
    required this.deposit,
    required this.damagePolicy,
    this.lateReturnPolicy,
    required this.cancellationPolicyId,
    this.cancellationPolicyNote,
  });

  final String currencyCode;
  final RentalBillingUnit billingUnit;
  final List<RentalRateStep> rateSteps;
  final RentalDepositPolicy deposit;
  final String damagePolicy;
  final String? lateReturnPolicy;
  final String cancellationPolicyId;
  final String? cancellationPolicyNote;

  RentalPricingPolicy copyWith({
    String? currencyCode,
    RentalBillingUnit? billingUnit,
    List<RentalRateStep>? rateSteps,
    RentalDepositPolicy? deposit,
    String? damagePolicy,
    String? lateReturnPolicy,
    bool clearLateReturnPolicy = false,
    String? cancellationPolicyId,
    String? cancellationPolicyNote,
    bool clearCancellationPolicyNote = false,
  }) {
    return RentalPricingPolicy(
      currencyCode: currencyCode ?? this.currencyCode,
      billingUnit: billingUnit ?? this.billingUnit,
      rateSteps: rateSteps ?? this.rateSteps,
      deposit: deposit ?? this.deposit,
      damagePolicy: damagePolicy ?? this.damagePolicy,
      lateReturnPolicy: clearLateReturnPolicy
          ? null
          : (lateReturnPolicy ?? this.lateReturnPolicy),
      cancellationPolicyId: cancellationPolicyId ?? this.cancellationPolicyId,
      cancellationPolicyNote: clearCancellationPolicyNote
          ? null
          : (cancellationPolicyNote ?? this.cancellationPolicyNote),
    );
  }
}

/// V1 only supports `externalBookingUrl`; there is no `contact_host` — an
/// approved, deliberate V1 trade-off (spec §12, §22).
class RentalExternalFulfillment {
  const RentalExternalFulfillment({this.externalBookingUrl});

  final String? externalBookingUrl;

  bool get isConfigured =>
      externalBookingUrl != null && externalBookingUrl!.trim().isNotEmpty;

  RentalExternalFulfillment copyWith({
    String? externalBookingUrl,
    bool clearExternalBookingUrl = false,
  }) {
    return RentalExternalFulfillment(
      externalBookingUrl: clearExternalBookingUrl
          ? null
          : (externalBookingUrl ?? this.externalBookingUrl),
    );
  }
}

class RentalPublisherAttestation {
  const RentalPublisherAttestation({
    required this.policyVersion,
    this.acceptedAtUtc,
    this.acceptedByUserId,
    this.hasRightToOffer = false,
    this.listingAccurate = false,
    this.prohibitedItemsAcknowledged = false,
  });

  final String policyVersion;
  final DateTime? acceptedAtUtc;
  final String? acceptedByUserId;
  final bool hasRightToOffer;
  final bool listingAccurate;
  final bool prohibitedItemsAcknowledged;

  bool get isComplete =>
      acceptedAtUtc != null &&
      (acceptedByUserId?.isNotEmpty ?? false) &&
      hasRightToOffer &&
      listingAccurate &&
      prohibitedItemsAcknowledged;

  RentalPublisherAttestation copyWith({
    String? policyVersion,
    DateTime? acceptedAtUtc,
    bool clearAcceptedAtUtc = false,
    String? acceptedByUserId,
    bool clearAcceptedByUserId = false,
    bool? hasRightToOffer,
    bool? listingAccurate,
    bool? prohibitedItemsAcknowledged,
  }) {
    return RentalPublisherAttestation(
      policyVersion: policyVersion ?? this.policyVersion,
      acceptedAtUtc: clearAcceptedAtUtc
          ? null
          : (acceptedAtUtc ?? this.acceptedAtUtc),
      acceptedByUserId: clearAcceptedByUserId
          ? null
          : (acceptedByUserId ?? this.acceptedByUserId),
      hasRightToOffer: hasRightToOffer ?? this.hasRightToOffer,
      listingAccurate: listingAccurate ?? this.listingAccurate,
      prohibitedItemsAcknowledged:
          prohibitedItemsAcknowledged ?? this.prohibitedItemsAcknowledged,
    );
  }
}

/// Typed authoring payload for `CreateObjectType.rental` (spec §7.2).
///
/// Exact private handover data (address/geo/instructions/notes) is
/// deliberately NOT a field here — it lives only in
/// `RentalPrivateAuthoringData`, stored through a separate repository, so
/// the public/private boundary (spec §7.3, AC 12) is enforced by physical
/// storage separation, not just by omission from a serializer.
class RentalDraftData {
  const RentalDraftData({
    required this.schemaVersion,
    required this.revision,
    required this.publisherRef,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.categoryId,
    required this.subcategoryId,
    this.brandModel,
    this.mediaRefs = const <String>[],
    this.inventoryGroups = const <RentalInventoryGroup>[],
    required this.availability,
    required this.handover,
    required this.terms,
    required this.pricing,
    this.fulfillment = const RentalExternalFulfillment(),
    required this.attestation,
    this.categoryConfirmed = false,
    this.unknownFields = const <String, Object?>{},
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int revision;
  final PublisherRef publisherRef;

  final String title;
  final String shortDescription;
  final String fullDescription;
  final String categoryId;
  final String subcategoryId;
  final String? brandModel;
  final List<String> mediaRefs;

  final List<RentalInventoryGroup> inventoryGroups;
  final RentalAvailabilityCalendar availability;
  final RentalHandoverDraft handover;
  final RentalTerms terms;
  final RentalPricingPolicy pricing;
  final RentalExternalFulfillment fulfillment;
  final RentalPublisherAttestation attestation;

  final bool categoryConfirmed;
  final Map<String, Object?> unknownFields;

  int get totalUnitsAggregate => inventoryGroups
      .where(
        (RentalInventoryGroup g) => g.status == RentalUnitGroupStatus.available,
      )
      .fold(0, (int sum, RentalInventoryGroup g) => sum + g.quantity);

  factory RentalDraftData.defaults({
    required String userId,
    required String currencyCode,
    required String timeZoneId,
    String categoryId = 'sport',
    String subcategoryId = 'cycling',
  }) {
    return RentalDraftData(
      schemaVersion: currentSchemaVersion,
      revision: 0,
      publisherRef: PublisherRef(type: PublisherType.user, id: userId),
      title: '',
      shortDescription: '',
      fullDescription: '',
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      inventoryGroups: const <RentalInventoryGroup>[],
      availability: RentalAvailabilityCalendar(timeZoneId: timeZoneId),
      handover: const RentalHandoverDraft(
        pickupPlaceName: '',
        publicAreaLabel: '',
      ),
      terms: const RentalTerms(offeredMinMinutes: 60, offeredMaxMinutes: 4320),
      pricing: RentalPricingPolicy(
        currencyCode: currencyCode,
        billingUnit: RentalBillingUnit.day,
        deposit: RentalDepositPolicy(
          amount: RentalMoneyDraft(amountMinor: 0, currencyCode: currencyCode),
          collectionMethod: RentalDepositCollectionMethod.none,
        ),
        damagePolicy: '',
        cancellationPolicyId: 'standard',
      ),
      attestation: const RentalPublisherAttestation(policyVersion: '1.0'),
    );
  }

  RentalDraftData copyWith({
    int? revision,
    PublisherRef? publisherRef,
    String? title,
    String? shortDescription,
    String? fullDescription,
    String? categoryId,
    String? subcategoryId,
    String? brandModel,
    bool clearBrandModel = false,
    List<String>? mediaRefs,
    List<RentalInventoryGroup>? inventoryGroups,
    RentalAvailabilityCalendar? availability,
    RentalHandoverDraft? handover,
    RentalTerms? terms,
    RentalPricingPolicy? pricing,
    RentalExternalFulfillment? fulfillment,
    RentalPublisherAttestation? attestation,
    bool? categoryConfirmed,
    Map<String, Object?>? unknownFields,
  }) {
    return RentalDraftData(
      schemaVersion: schemaVersion,
      revision: revision ?? this.revision,
      publisherRef: publisherRef ?? this.publisherRef,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      brandModel: clearBrandModel ? null : (brandModel ?? this.brandModel),
      mediaRefs: mediaRefs ?? this.mediaRefs,
      inventoryGroups: inventoryGroups ?? this.inventoryGroups,
      availability: availability ?? this.availability,
      handover: handover ?? this.handover,
      terms: terms ?? this.terms,
      pricing: pricing ?? this.pricing,
      fulfillment: fulfillment ?? this.fulfillment,
      attestation: attestation ?? this.attestation,
      categoryConfirmed: categoryConfirmed ?? this.categoryConfirmed,
      unknownFields: unknownFields ?? this.unknownFields,
    );
  }

  RentalDraftData nextRevision() => copyWith(revision: revision + 1);

  /// Replaces every `loc_*` child id (inventory groups, availability
  /// blocks) with a permanent id from [generateId]. The envelope id itself
  /// is replaced by the caller (`CreateDraftEntity`/repository layer), not
  /// here.
  RentalDraftData replaceLocalIds(String Function() generateId) {
    final Map<String, String> groupIdMap = <String, String>{
      for (final RentalInventoryGroup group in inventoryGroups)
        group.id: group.id.startsWith('loc_') ? generateId() : group.id,
    };
    final List<RentalInventoryGroup> nextGroups = inventoryGroups
        .map((RentalInventoryGroup g) => g.copyWith(id: groupIdMap[g.id]))
        .toList(growable: false);
    final List<RentalAvailabilityBlock> nextBlocks = availability.blocks
        .map(
          (RentalAvailabilityBlock block) => RentalAvailabilityBlock(
            id: block.id.startsWith('loc_') ? generateId() : block.id,
            groupId: groupIdMap[block.groupId] ?? block.groupId,
            startsAtUtc: block.startsAtUtc,
            endsAtUtc: block.endsAtUtc,
            unitsBlocked: block.unitsBlocked,
            source: block.source,
            status: block.status,
            revision: block.revision,
            createdByUserId: block.createdByUserId,
            createdAtUtc: block.createdAtUtc,
            updatedAtUtc: block.updatedAtUtc,
          ),
        )
        .toList(growable: false);
    return copyWith(
      inventoryGroups: nextGroups,
      availability: availability.copyWith(blocks: nextBlocks),
    );
  }
}
