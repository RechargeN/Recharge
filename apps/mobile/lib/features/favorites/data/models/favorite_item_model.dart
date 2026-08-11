import '../../../../shared/primitives/money/currency_code.dart';
import '../../../../shared/primitives/money/money.dart';
import '../../../../shared/primitives/money/money_parse_result.dart';
import '../../../../shared/primitives/money/money_parser.dart';

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
    required this.price,
    required this.isFree,
    required this.savedAtUtcIso,
    required this.targetRoute,
    required this.coverImageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String city;
  final String category;
  final String startsAtUtcIso;
  final double distanceKm;
  final Money price;
  final bool isFree;
  final String savedAtUtcIso;
  final String? targetRoute;
  final String coverImageUrl;

  factory FavoriteItemModel.fromJson(
    Map<String, dynamic> json, {
    required CurrencyCode legacyCurrency,
  }) {
    final CurrencyCode currency = json.containsKey('currencyCode')
        ? CurrencyCode.parse(json['currencyCode']?.toString() ?? '')
        : legacyCurrency;
    final Money price = _readPrice(json, currency: currency);
    return FavoriteItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      city: json['city'] as String,
      category: json['category'] as String,
      startsAtUtcIso: json['startsAtUtcIso'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      price: price,
      isFree: json['isFree'] as bool,
      savedAtUtcIso: json['savedAtUtcIso'] as String,
      targetRoute: json['targetRoute'] as String?,
      coverImageUrl: json['coverImageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'city': city,
      'category': category,
      'startsAtUtcIso': startsAtUtcIso,
      'distanceKm': distanceKm,
      'priceMinorUnits': price.minorUnits,
      'currencyCode': price.currency.value,
      'isFree': isFree,
      'savedAtUtcIso': savedAtUtcIso,
      'targetRoute': targetRoute,
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
      price: entity.price,
      isFree: entity.isFree,
      savedAtUtcIso: entity.savedAtUtc.toUtc().toIso8601String(),
      targetRoute: entity.targetRoute,
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
      price: price,
      isFree: isFree,
      savedAtUtc: DateTime.parse(savedAtUtcIso).toUtc(),
      targetRoute: targetRoute,
      coverImageUrl: coverImageUrl,
    );
  }
}

Money _readPrice(Map<String, dynamic> json, {required CurrencyCode currency}) {
  final Object? canonical = json['priceMinorUnits'];
  if (canonical != null) {
    if (canonical is! int) {
      throw const FormatException(
        'Favorite price minor units must be an integer.',
      );
    }
    return Money(minorUnits: canonical, currency: currency);
  }
  final Object? legacy = json['priceAmount'];
  if (legacy is num) {
    final MoneyParseResult result = MoneyParser.parseLegacyNumber(
      legacy,
      currency: currency,
    );
    if (result is MoneyParseSuccess) return result.money;
  }
  throw const FormatException('Favorite price is invalid or ambiguous.');
}
