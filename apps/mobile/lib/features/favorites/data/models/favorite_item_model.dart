import '../../../../shared/primitives/money/currency_metadata.dart';
import '../../../../core/parsing/money_legacy_adapter.dart';
import '../../../../shared/primitives/money/money_parse_result.dart';
import '../../../../shared/primitives/money/money.dart';
import '../../domain/entities/favorite_item_entity.dart';

class FavoriteItemModel {
  const FavoriteItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.category,
    required this.startsAtUtcIso,
    required this.distanceKm,
    required this.priceAmount,
    required this.isFree,
    required this.savedAtUtcIso,
    required this.targetRoute,
    required this.planningTargetKind,
    required this.planningTargetId,
    required this.coverImageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final String startsAtUtcIso;
  final double distanceKm;
  final Money priceAmount;
  final bool isFree;
  final String savedAtUtcIso;
  final String? targetRoute;
  final String? planningTargetKind;
  final String? planningTargetId;
  final String coverImageUrl;

  factory FavoriteItemModel.fromJson(
    Map<String, dynamic> json, {
    String? legacyCurrencyCode,
  }) {
    final price =
        MoneyLegacyAdapter().readOptional(
          hasCanonicalMinorUnits: json.containsKey('priceMinorUnits'),
          canonicalMinorUnits: json['priceMinorUnits'],
          legacyMajorAmount: json['priceAmount'],
          currencyCode: json.containsKey('currencyCode')
              ? json['currencyCode']
              : legacyCurrencyCode,
        ) ??
        (throw const MoneyReadException(MoneyParseError.invalidCanonicalValue));
    if (price.minorUnits < 0) {
      throw const MoneyReadException(MoneyParseError.outOfRange);
    }
    return FavoriteItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      city: json['city'] as String,
      category: json['category'] as String,
      startsAtUtcIso: json['startsAtUtcIso'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      priceAmount: price,
      isFree: json['isFree'] as bool,
      savedAtUtcIso: json['savedAtUtcIso'] as String,
      targetRoute: json['targetRoute'] as String?,
      planningTargetKind: json['planningTargetKind'] as String?,
      planningTargetId: json['planningTargetId'] as String?,
      coverImageUrl: json['coverImageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    if (CurrencyMetadataRegistry.eurOnly.lookup(priceAmount.currency) == null) {
      throw const MoneyReadException(MoneyParseError.unknownCurrency);
    }
    if (priceAmount.minorUnits < 0) {
      throw const MoneyReadException(MoneyParseError.outOfRange);
    }
    return <String, dynamic>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'city': city,
      'category': category,
      'startsAtUtcIso': startsAtUtcIso,
      'distanceKm': distanceKm,
      'priceMinorUnits': priceAmount.minorUnits,
      'currencyCode': priceAmount.currency.value,
      'isFree': isFree,
      'savedAtUtcIso': savedAtUtcIso,
      'targetRoute': targetRoute,
      'planningTargetKind': planningTargetKind,
      'planningTargetId': planningTargetId,
      'coverImageUrl': coverImageUrl,
    };
  }

  factory FavoriteItemModel.fromEntity(FavoriteItemEntity entity) {
    return FavoriteItemModel(
      id: entity.id,
      title: entity.title,
      subtitle: entity.subtitle,
      city: entity.city,
      category: entity.category,
      startsAtUtcIso: entity.startsAtUtc.toUtc().toIso8601String(),
      distanceKm: entity.distanceKm,
      priceAmount: entity.priceAmount,
      isFree: entity.isFree,
      savedAtUtcIso: entity.savedAtUtc.toUtc().toIso8601String(),
      targetRoute: entity.targetRoute,
      planningTargetKind: entity.planningTargetKind?.name,
      planningTargetId: entity.planningTargetId,
      coverImageUrl: entity.coverImageUrl,
    );
  }

  FavoriteItemEntity toEntity() {
    return FavoriteItemEntity(
      id: id,
      title: title,
      subtitle: subtitle,
      city: city,
      category: category,
      startsAtUtc: DateTime.parse(startsAtUtcIso).toUtc(),
      distanceKm: distanceKm,
      priceAmount: priceAmount,
      isFree: isFree,
      savedAtUtc: DateTime.parse(savedAtUtcIso).toUtc(),
      targetRoute: targetRoute,
      planningTargetKind: FavoritePlanningTargetKind.values
          .where((value) => value.name == planningTargetKind)
          .firstOrNull,
      planningTargetId: planningTargetId,
      coverImageUrl: coverImageUrl,
    );
  }
}
