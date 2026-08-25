import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/published_rental_discovery_entity.dart';

/// Persisted local/mock index of active Rental listings (`DTL-OBJ-01`
/// §3.3) — same storage shape as
/// `PublishedCollectionDiscoveryLocalDataSource`. A corrupt or unreadable
/// record degrades to an empty index rather than crashing Discover.
class PublishedRentalDiscoveryLocalDataSource {
  PublishedRentalDiscoveryLocalDataSource(this._storage);

  static const String storageKey = 'recharge.rental.discovery.index.v1';

  final FlutterSecureStorage _storage;

  Future<List<PublishedRentalDiscoveryEntity>> loadAll() async {
    final String? raw = await _storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <PublishedRentalDiscoveryEntity>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
        return const <PublishedRentalDiscoveryEntity>[];
      }
      final Object? rentals = decoded['rentals'];
      if (rentals is! List<dynamic>) {
        return const <PublishedRentalDiscoveryEntity>[];
      }
      return rentals
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> map) => _fromMap(
              map.map(
                (Object? key, Object? value) =>
                    MapEntry<String, Object?>(key.toString(), value),
              ),
            ),
          )
          .where((PublishedRentalDiscoveryEntity r) => r.isCoherent)
          .toList(growable: false);
    } on FormatException {
      return const <PublishedRentalDiscoveryEntity>[];
    } on TypeError {
      return const <PublishedRentalDiscoveryEntity>[];
    }
  }

  Future<void> upsert(PublishedRentalDiscoveryEntity rental) async {
    if (!rental.isCoherent) {
      throw ArgumentError.value(
        rental,
        'rental',
        'Rental index entry is incoherent.',
      );
    }
    final List<PublishedRentalDiscoveryEntity> current = await loadAll();
    final List<PublishedRentalDiscoveryEntity> next =
        <PublishedRentalDiscoveryEntity>[
          for (final PublishedRentalDiscoveryEntity value in current)
            if (value.rentalId != rental.rentalId) value,
          rental,
        ]..sort(
          (
            PublishedRentalDiscoveryEntity left,
            PublishedRentalDiscoveryEntity right,
          ) => left.rentalId.compareTo(right.rentalId),
        );
    await _write(next);
  }

  Future<void> remove(String rentalId) async {
    final List<PublishedRentalDiscoveryEntity> current = await loadAll();
    final List<PublishedRentalDiscoveryEntity> next = current
        .where((PublishedRentalDiscoveryEntity r) => r.rentalId != rentalId)
        .toList(growable: false);
    await _write(next);
  }

  Future<void> clear() => _storage.delete(key: storageKey);

  Future<void> _write(List<PublishedRentalDiscoveryEntity> rentals) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'rentals': rentals.map(_toMap).toList(growable: false),
      }),
    );
  }

  static Map<String, Object?> _toMap(PublishedRentalDiscoveryEntity value) =>
      <String, Object?>{
        'rentalId': value.rentalId,
        'publisherId': value.publisherId,
        'title': value.title,
        'shortDescription': value.shortDescription,
        'fullDescription': value.fullDescription,
        'categoryId': value.categoryId,
        'subcategoryId': value.subcategoryId,
        'brandModel': value.brandModel,
        'mediaRefs': value.mediaRefs,
        'inventoryGroups': value.inventoryGroups
            .map(
              (PublishedRentalInventoryGroupRef g) => <String, Object?>{
                'id': g.id,
                'label': g.label,
                'quantity': g.quantity,
                'condition': g.condition,
                'sizeOrVariant': g.sizeOrVariant,
                'includedAccessories': g.includedAccessories,
                'status': g.status,
              },
            )
            .toList(growable: false),
        'totalUnitsAggregate': value.totalUnitsAggregate,
        'publicAreaLabel': value.publicAreaLabel,
        'publicAddress': value.publicAddress,
        'publicLatitude': value.publicLatitude,
        'publicLongitude': value.publicLongitude,
        'publicGeoPrecisionMeters': value.publicGeoPrecisionMeters,
        'deliveryAvailable': value.deliveryAvailable,
        'deliveryRadiusKm': value.deliveryRadiusKm,
        'deliveryFeeMinor': value.deliveryFeeMinor,
        'deliveryTerms': value.deliveryTerms,
        'offeredMinMinutes': value.offeredMinMinutes,
        'offeredMaxMinutes': value.offeredMaxMinutes,
        'minRenterAge': value.minRenterAge,
        'idRequiredAtHandover': value.idRequiredAtHandover,
        'usageRestrictions': value.usageRestrictions,
        'safetyNotice': value.safetyNotice,
        'currencyCode': value.currencyCode,
        'billingUnit': value.billingUnit,
        'rateSteps': value.rateSteps
            .map(
              (PublishedRentalRateStepRef s) => <String, Object?>{
                'minUnits': s.minUnits,
                'unitPriceMinor': s.unitPriceMinor,
              },
            )
            .toList(growable: false),
        'hasDeposit': value.hasDeposit,
        'depositAmountMinor': value.depositAmountMinor,
        'damagePolicy': value.damagePolicy,
        'lateReturnPolicy': value.lateReturnPolicy,
        'cancellationPolicyId': value.cancellationPolicyId,
        'cancellationPolicyNote': value.cancellationPolicyNote,
        'externalBookingUrl': value.externalBookingUrl,
        'publishedAtUtc': value.publishedAtUtc.toIso8601String(),
      };

  static PublishedRentalDiscoveryEntity _fromMap(Map<String, Object?> map) {
    final List<dynamic> rawGroups =
        map['inventoryGroups'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> rawSteps =
        map['rateSteps'] as List<dynamic>? ?? <dynamic>[];
    return PublishedRentalDiscoveryEntity(
      rentalId: map['rentalId']! as String,
      publisherId: map['publisherId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      shortDescription: map['shortDescription'] as String? ?? '',
      fullDescription: map['fullDescription'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      subcategoryId: map['subcategoryId'] as String? ?? '',
      brandModel: map['brandModel'] as String?,
      mediaRefs:
          (map['mediaRefs'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
      inventoryGroups: rawGroups
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> g) => PublishedRentalInventoryGroupRef(
              id: g['id']! as String,
              label: g['label'] as String? ?? '',
              quantity: (g['quantity'] as num?)?.toInt() ?? 0,
              condition: g['condition'] as String? ?? 'good',
              sizeOrVariant: g['sizeOrVariant'] as String?,
              includedAccessories:
                  (g['includedAccessories'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toList(growable: false) ??
                  const <String>[],
              status: g['status'] as String? ?? 'available',
            ),
          )
          .toList(growable: false),
      totalUnitsAggregate: (map['totalUnitsAggregate'] as num?)?.toInt() ?? 0,
      publicAreaLabel: map['publicAreaLabel'] as String? ?? '',
      publicAddress: map['publicAddress'] as String?,
      publicLatitude: (map['publicLatitude'] as num?)?.toDouble(),
      publicLongitude: (map['publicLongitude'] as num?)?.toDouble(),
      publicGeoPrecisionMeters:
          (map['publicGeoPrecisionMeters'] as num?)?.toInt() ?? 0,
      deliveryAvailable: map['deliveryAvailable'] as bool? ?? false,
      deliveryRadiusKm: (map['deliveryRadiusKm'] as num?)?.toDouble(),
      deliveryFeeMinor: (map['deliveryFeeMinor'] as num?)?.toInt(),
      deliveryTerms: map['deliveryTerms'] as String?,
      offeredMinMinutes: (map['offeredMinMinutes'] as num?)?.toInt() ?? 0,
      offeredMaxMinutes: (map['offeredMaxMinutes'] as num?)?.toInt() ?? 0,
      minRenterAge: (map['minRenterAge'] as num?)?.toInt(),
      idRequiredAtHandover: map['idRequiredAtHandover'] as bool? ?? false,
      usageRestrictions: map['usageRestrictions'] as String?,
      safetyNotice: map['safetyNotice'] as String?,
      currencyCode: map['currencyCode'] as String? ?? '',
      billingUnit: map['billingUnit'] as String? ?? 'day',
      rateSteps: rawSteps
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> s) => PublishedRentalRateStepRef(
              minUnits: (s['minUnits'] as num?)?.toInt() ?? 1,
              unitPriceMinor: (s['unitPriceMinor'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false),
      hasDeposit: map['hasDeposit'] as bool? ?? false,
      depositAmountMinor: (map['depositAmountMinor'] as num?)?.toInt(),
      damagePolicy: map['damagePolicy'] as String? ?? '',
      lateReturnPolicy: map['lateReturnPolicy'] as String?,
      cancellationPolicyId: map['cancellationPolicyId'] as String? ?? '',
      cancellationPolicyNote: map['cancellationPolicyNote'] as String?,
      externalBookingUrl: map['externalBookingUrl'] as String?,
      publishedAtUtc: DateTime.parse(
        map['publishedAtUtc']! as String,
      ).toUtc(),
    );
  }
}
