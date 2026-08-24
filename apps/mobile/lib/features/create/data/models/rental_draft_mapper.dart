import '../../domain/entities/create_availability.dart';
import '../../domain/entities/rental_draft_data.dart';

class RentalDraftMapper {
  const RentalDraftMapper._();

  static RentalDraftData fromJson(
    Object? raw, {
    required RentalDraftData defaults,
  }) {
    if (raw is! Map) return defaults;
    final Map<String, Object?> json = raw.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final int version = _int(json['schemaVersion']) ?? 1;
    if (version > RentalDraftData.currentSchemaVersion) {
      throw const FormatException('Unsupported Rental draft schema version');
    }
    const Set<String> knownKeys = <String>{
      'schemaVersion',
      'revision',
      'publisherRef',
      'title',
      'shortDescription',
      'fullDescription',
      'categoryId',
      'subcategoryId',
      'brandModel',
      'mediaRefs',
      'inventoryGroups',
      'availability',
      'handover',
      'terms',
      'pricing',
      'fulfillment',
      'attestation',
      'categoryConfirmed',
    };
    final Map<String, Object?> unknownFields = <String, Object?>{
      for (final MapEntry<String, Object?> entry in json.entries)
        if (!knownKeys.contains(entry.key)) entry.key: entry.value,
    };
    return RentalDraftData(
      schemaVersion: RentalDraftData.currentSchemaVersion,
      revision: _int(json['revision']) ?? defaults.revision,
      publisherRef:
          _publisherRef(json['publisherRef']) ?? defaults.publisherRef,
      title: _string(json['title']) ?? defaults.title,
      shortDescription:
          _string(json['shortDescription']) ?? defaults.shortDescription,
      fullDescription:
          _string(json['fullDescription']) ?? defaults.fullDescription,
      categoryId: _string(json['categoryId']) ?? defaults.categoryId,
      subcategoryId: _string(json['subcategoryId']) ?? defaults.subcategoryId,
      brandModel: _string(json['brandModel']),
      mediaRefs: _stringList(json['mediaRefs']),
      inventoryGroups: _list(json['inventoryGroups'])
          .map(_inventoryGroup)
          .whereType<RentalInventoryGroup>()
          .toList(growable: false),
      availability: _availability(json['availability'], defaults.availability),
      handover: _handover(json['handover'], defaults.handover),
      terms: _terms(json['terms'], defaults.terms),
      pricing: _pricing(json['pricing'], defaults.pricing),
      fulfillment: _fulfillment(json['fulfillment']),
      attestation: _attestation(json['attestation'], defaults.attestation),
      categoryConfirmed: json['categoryConfirmed'] as bool? ?? false,
      unknownFields: unknownFields,
    );
  }

  static Map<String, Object?> toJson(RentalDraftData value) {
    return <String, Object?>{
      ...value.unknownFields,
      'schemaVersion': RentalDraftData.currentSchemaVersion,
      'revision': value.revision,
      'publisherRef': <String, Object?>{
        'type': value.publisherRef.type.name,
        'id': value.publisherRef.id,
      },
      'title': value.title,
      'shortDescription': value.shortDescription,
      'fullDescription': value.fullDescription,
      'categoryId': value.categoryId,
      'subcategoryId': value.subcategoryId,
      'brandModel': value.brandModel,
      'mediaRefs': value.mediaRefs,
      'inventoryGroups': value.inventoryGroups
          .map(_inventoryGroupToJson)
          .toList(growable: false),
      'availability': _availabilityToJson(value.availability),
      'handover': _handoverToJson(value.handover),
      'terms': _termsToJson(value.terms),
      'pricing': _pricingToJson(value.pricing),
      'fulfillment': <String, Object?>{
        'externalBookingUrl': value.fulfillment.externalBookingUrl,
      },
      'attestation': _attestationToJson(value.attestation),
      'categoryConfirmed': value.categoryConfirmed,
    };
  }

  static Map<String, Object?> _inventoryGroupToJson(RentalInventoryGroup g) =>
      <String, Object?>{
        'id': g.id,
        'label': g.label,
        'quantity': g.quantity,
        'condition': g.condition.name,
        'sizeOrVariant': g.sizeOrVariant,
        'includedAccessories': g.includedAccessories,
        'photoRefs': g.photoRefs,
        'status': g.status.name,
      };

  static RentalInventoryGroup? _inventoryGroup(Object? raw) {
    final Map<String, Object?>? json = _map(raw);
    if (json == null) return null;
    final String? id = _string(json['id']);
    final String? label = _string(json['label']);
    final int? quantity = _int(json['quantity']);
    if (id == null || label == null || quantity == null) return null;
    return RentalInventoryGroup(
      id: id,
      label: label,
      quantity: quantity,
      condition:
          _enumValue(RentalCondition.values, json['condition']) ??
          RentalCondition.good,
      sizeOrVariant: _string(json['sizeOrVariant']),
      includedAccessories: _stringList(json['includedAccessories']),
      photoRefs: _stringList(json['photoRefs']),
      status:
          _enumValue(RentalUnitGroupStatus.values, json['status']) ??
          RentalUnitGroupStatus.available,
    );
  }

  static Map<String, Object?> _availabilityToJson(
    RentalAvailabilityCalendar value,
  ) => <String, Object?>{
    'timeZoneId': value.timeZoneId,
    'coverage': value.coverage == null
        ? null
        : <String, Object?>{
            'startsAtUtc': value.coverage!.startsAtUtc.toIso8601String(),
            'endsAtUtc': value.coverage!.endsAtUtc.toIso8601String(),
            'confirmedAtUtc': value.coverage!.confirmedAtUtc.toIso8601String(),
          },
    'blocks': value.blocks.map(_blockToJson).toList(growable: false),
  };

  static RentalAvailabilityCalendar _availability(
    Object? raw,
    RentalAvailabilityCalendar defaults,
  ) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return RentalAvailabilityCalendar(
      timeZoneId: _string(json['timeZoneId']) ?? defaults.timeZoneId,
      coverage: _coverage(json['coverage']),
      blocks: _list(json['blocks'])
          .map(_block)
          .whereType<RentalAvailabilityBlock>()
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _blockToJson(RentalAvailabilityBlock b) =>
      <String, Object?>{
        'id': b.id,
        'groupId': b.groupId,
        'startsAtUtc': b.startsAtUtc.toIso8601String(),
        'endsAtUtc': b.endsAtUtc.toIso8601String(),
        'unitsBlocked': b.unitsBlocked,
        'source': b.source.name,
        'status': b.status.name,
        'revision': b.revision,
        'createdByUserId': b.createdByUserId,
        'createdAtUtc': b.createdAtUtc.toIso8601String(),
        'updatedAtUtc': b.updatedAtUtc.toIso8601String(),
      };

  static RentalAvailabilityBlock? _block(Object? raw) {
    final Map<String, Object?>? json = _map(raw);
    if (json == null) return null;
    final String? id = _string(json['id']);
    final String? groupId = _string(json['groupId']);
    final DateTime? starts = _dateTime(json['startsAtUtc']);
    final DateTime? ends = _dateTime(json['endsAtUtc']);
    final int? unitsBlocked = _int(json['unitsBlocked']);
    final String? createdByUserId = _string(json['createdByUserId']);
    final DateTime? createdAtUtc = _dateTime(json['createdAtUtc']);
    if (id == null ||
        groupId == null ||
        starts == null ||
        ends == null ||
        unitsBlocked == null ||
        createdByUserId == null ||
        createdAtUtc == null) {
      return null;
    }
    return RentalAvailabilityBlock(
      id: id,
      groupId: groupId,
      startsAtUtc: starts,
      endsAtUtc: ends,
      unitsBlocked: unitsBlocked,
      source:
          _enumValue(RentalBlockSource.values, json['source']) ??
          RentalBlockSource.other,
      status:
          _enumValue(RentalBlockStatus.values, json['status']) ??
          RentalBlockStatus.active,
      revision: _int(json['revision']) ?? 0,
      createdByUserId: createdByUserId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: _dateTime(json['updatedAtUtc']) ?? createdAtUtc,
    );
  }

  static RentalAvailabilityCoverage? _coverage(Object? raw) {
    final Map<String, Object?>? json = _map(raw);
    if (json == null) return null;
    final DateTime? starts = _dateTime(json['startsAtUtc']);
    final DateTime? ends = _dateTime(json['endsAtUtc']);
    final DateTime? confirmed = _dateTime(json['confirmedAtUtc']);
    if (starts == null || ends == null || confirmed == null) return null;
    return RentalAvailabilityCoverage(
      startsAtUtc: starts,
      endsAtUtc: ends,
      confirmedAtUtc: confirmed,
    );
  }

  static Map<String, Object?> _handoverToJson(RentalHandoverDraft value) =>
      <String, Object?>{
        'pickupPlaceName': value.pickupPlaceName,
        'publicAreaLabel': value.publicAreaLabel,
        'publicAddress': value.publicAddress,
        'publicLatitude': value.publicLatitude,
        'publicLongitude': value.publicLongitude,
        'publicGeoPrecisionMeters': value.publicGeoPrecisionMeters,
        'disclosure': value.disclosure.name,
        'scheduleMode': value.scheduleMode.name,
        'openingHours': value.openingHours
            .map((CreateOpeningHoursDraftRule r) => r.toMap())
            .toList(growable: false),
        'deliveryAvailable': value.deliveryAvailable,
        'deliveryRadiusKm': value.deliveryRadiusKm,
        'deliveryFee': value.deliveryFee?.toMap(),
        'deliveryTerms': value.deliveryTerms,
      };

  static RentalHandoverDraft _handover(
    Object? raw,
    RentalHandoverDraft defaults,
  ) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    final Object? feeRaw = json['deliveryFee'];
    return RentalHandoverDraft(
      pickupPlaceName:
          _string(json['pickupPlaceName']) ?? defaults.pickupPlaceName,
      publicAreaLabel:
          _string(json['publicAreaLabel']) ?? defaults.publicAreaLabel,
      publicAddress: _string(json['publicAddress']),
      publicLatitude: _double(json['publicLatitude']),
      publicLongitude: _double(json['publicLongitude']),
      publicGeoPrecisionMeters:
          _int(json['publicGeoPrecisionMeters']) ??
          defaults.publicGeoPrecisionMeters,
      disclosure:
          _enumValue(RentalLocationDisclosure.values, json['disclosure']) ??
          defaults.disclosure,
      scheduleMode:
          _enumValue(RentalScheduleMode.values, json['scheduleMode']) ??
          defaults.scheduleMode,
      openingHours: _list(json['openingHours'])
          .map(
            (Object? r) => r is Map
                ? CreateOpeningHoursDraftRule.fromMap(
                    r.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
                  )
                : null,
          )
          .whereType<CreateOpeningHoursDraftRule>()
          .toList(growable: false),
      deliveryAvailable: json['deliveryAvailable'] as bool? ?? false,
      deliveryRadiusKm: _double(json['deliveryRadiusKm']),
      deliveryFee: feeRaw is Map
          ? RentalMoneyDraft.fromMap(
              feeRaw.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
            )
          : null,
      deliveryTerms: _string(json['deliveryTerms']),
    );
  }

  static Map<String, Object?> _termsToJson(
    RentalTerms value,
  ) => <String, Object?>{
    'offeredMinMinutes': value.offeredMinMinutes,
    'offeredMaxMinutes': value.offeredMaxMinutes,
    'minRenterAge': value.minRenterAge,
    'idRequiredAtHandover': value.idRequiredAtHandover,
    'usageRestrictions': value.usageRestrictions,
    'safetyNotice': value.safetyNotice,
    'includedAccessoriesConfirmation': value.includedAccessoriesConfirmation,
  };

  static RentalTerms _terms(Object? raw, RentalTerms defaults) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return RentalTerms(
      offeredMinMinutes:
          _int(json['offeredMinMinutes']) ?? defaults.offeredMinMinutes,
      offeredMaxMinutes:
          _int(json['offeredMaxMinutes']) ?? defaults.offeredMaxMinutes,
      minRenterAge: _int(json['minRenterAge']),
      idRequiredAtHandover: json['idRequiredAtHandover'] as bool? ?? false,
      usageRestrictions: _string(json['usageRestrictions']),
      safetyNotice: _string(json['safetyNotice']),
      includedAccessoriesConfirmation:
          json['includedAccessoriesConfirmation'] as bool? ?? false,
    );
  }

  static Map<String, Object?> _pricingToJson(RentalPricingPolicy value) =>
      <String, Object?>{
        'currencyCode': value.currencyCode,
        'billingUnit': value.billingUnit.name,
        'rateSteps': value.rateSteps
            .map(
              (RentalRateStep s) => <String, Object?>{
                'minUnits': s.minUnits,
                'unitPrice': s.unitPrice.toMap(),
              },
            )
            .toList(growable: false),
        'deposit': <String, Object?>{
          'amount': value.deposit.amount.toMap(),
          'collectionMethod': value.deposit.collectionMethod.name,
          'terms': value.deposit.terms,
        },
        'damagePolicy': value.damagePolicy,
        'lateReturnPolicy': value.lateReturnPolicy,
        'cancellationPolicyId': value.cancellationPolicyId,
        'cancellationPolicyNote': value.cancellationPolicyNote,
      };

  static RentalPricingPolicy _pricing(
    Object? raw,
    RentalPricingPolicy defaults,
  ) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    final String currencyCode =
        _string(json['currencyCode']) ?? defaults.currencyCode;
    final Map<String, Object?> depositJson =
        _map(json['deposit']) ?? const <String, Object?>{};
    final Object? amountRaw = depositJson['amount'];
    return RentalPricingPolicy(
      currencyCode: currencyCode,
      billingUnit:
          _enumValue(RentalBillingUnit.values, json['billingUnit']) ??
          defaults.billingUnit,
      rateSteps: _list(
        json['rateSteps'],
      ).map(_rateStep).whereType<RentalRateStep>().toList(growable: false),
      deposit: RentalDepositPolicy(
        amount: amountRaw is Map
            ? RentalMoneyDraft.fromMap(
                amountRaw.map(
                  (Object? k, Object? v) => MapEntry(k.toString(), v),
                ),
              )
            : RentalMoneyDraft(amountMinor: 0, currencyCode: currencyCode),
        collectionMethod:
            _enumValue(
              RentalDepositCollectionMethod.values,
              depositJson['collectionMethod'],
            ) ??
            RentalDepositCollectionMethod.none,
        terms: _string(depositJson['terms']),
      ),
      damagePolicy: _string(json['damagePolicy']) ?? defaults.damagePolicy,
      lateReturnPolicy: _string(json['lateReturnPolicy']),
      cancellationPolicyId:
          _string(json['cancellationPolicyId']) ??
          defaults.cancellationPolicyId,
      cancellationPolicyNote: _string(json['cancellationPolicyNote']),
    );
  }

  static RentalRateStep? _rateStep(Object? raw) {
    final Map<String, Object?>? json = _map(raw);
    if (json == null) return null;
    final int? minUnits = _int(json['minUnits']);
    final Object? priceRaw = json['unitPrice'];
    if (minUnits == null || priceRaw is! Map) return null;
    return RentalRateStep(
      minUnits: minUnits,
      unitPrice: RentalMoneyDraft.fromMap(
        priceRaw.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
      ),
    );
  }

  static RentalExternalFulfillment _fulfillment(Object? raw) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return RentalExternalFulfillment(
      externalBookingUrl: _string(json['externalBookingUrl']),
    );
  }

  static Map<String, Object?> _attestationToJson(
    RentalPublisherAttestation value,
  ) => <String, Object?>{
    'policyVersion': value.policyVersion,
    'acceptedAtUtc': value.acceptedAtUtc?.toIso8601String(),
    'acceptedByUserId': value.acceptedByUserId,
    'hasRightToOffer': value.hasRightToOffer,
    'listingAccurate': value.listingAccurate,
    'prohibitedItemsAcknowledged': value.prohibitedItemsAcknowledged,
  };

  static RentalPublisherAttestation _attestation(
    Object? raw,
    RentalPublisherAttestation defaults,
  ) {
    final Map<String, Object?> json = _map(raw) ?? const <String, Object?>{};
    return RentalPublisherAttestation(
      policyVersion: _string(json['policyVersion']) ?? defaults.policyVersion,
      acceptedAtUtc: _dateTime(json['acceptedAtUtc']),
      acceptedByUserId: _string(json['acceptedByUserId']),
      hasRightToOffer: json['hasRightToOffer'] as bool? ?? false,
      listingAccurate: json['listingAccurate'] as bool? ?? false,
      prohibitedItemsAcknowledged:
          json['prohibitedItemsAcknowledged'] as bool? ?? false,
    );
  }

  static PublisherRef? _publisherRef(Object? raw) {
    final Map<String, Object?>? json = _map(raw);
    if (json == null) return null;
    final PublisherType? type = _enumValue(PublisherType.values, json['type']);
    final String? id = _string(json['id']);
    return type == null || id == null ? null : PublisherRef(type: type, id: id);
  }

  static Map<String, Object?>? _map(Object? raw) {
    if (raw is! Map) return null;
    return raw.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
  }

  static List<Object?> _list(Object? raw) =>
      raw is List ? raw.cast<Object?>() : const <Object?>[];

  static List<String> _stringList(Object? raw) =>
      _list(raw).map(_string).whereType<String>().toList(growable: false);

  static String? _string(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  static int? _int(Object? raw) => raw is num ? raw.toInt() : null;
  static double? _double(Object? raw) => raw is num ? raw.toDouble() : null;
  static DateTime? _dateTime(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

  static T? _enumValue<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final T value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
