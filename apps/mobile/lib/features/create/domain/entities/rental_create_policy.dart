/// Versioned policy bounds/whitelist for Rental, referenced by name (spec
/// §5, §10.1) rather than the general Category System — the catalog does
/// not know about rental (`CATEGORY_SYSTEM.md` §3 п.2). Concrete adaptive
/// per-category hints and named steps live in
/// `application/rental_create_config.dart`; this class is only the shape +
/// a safe fallback instance, mirroring `PlaceCreationPolicy`.
class RentalCreatePolicy {
  const RentalCreatePolicy({
    required this.defaultOfferedMinMinutes,
    required this.defaultOfferedMaxMinutes,
    required this.absoluteMinMinutes,
    required this.absoluteMaxMinutes,
    required this.categoryWhitelist,
    this.minRenterAgeRequiredCategoryIds = const <String>{},
    this.safetyNoticeRequiredCategoryIds = const <String>{},
    this.idRequiredCategoryIds = const <String>{},
    this.sizeVariantRequiredCategoryIds = const <String>{},
  });

  final int defaultOfferedMinMinutes;
  final int defaultOfferedMaxMinutes;
  final int absoluteMinMinutes;
  final int absoluteMaxMinutes;
  final Set<String> categoryWhitelist;
  final Set<String> minRenterAgeRequiredCategoryIds;
  final Set<String> safetyNoticeRequiredCategoryIds;
  final Set<String> idRequiredCategoryIds;
  final Set<String> sizeVariantRequiredCategoryIds;

  /// Spec §5 whitelist and §10.1 recommended V1 defaults
  /// (1h–3d offered range hint, 1h–90d absolute submit bounds).
  static const RentalCreatePolicy safeFallback = RentalCreatePolicy(
    defaultOfferedMinMinutes: 60,
    defaultOfferedMaxMinutes: 4320,
    absoluteMinMinutes: 60,
    absoluteMaxMinutes: 129600,
    categoryWhitelist: <String>{
      'sport',
      'water_activities',
      'winter_seasonal',
      'adrenaline_entertainment',
      'auto_moto',
    },
    minRenterAgeRequiredCategoryIds: <String>{
      'auto_moto',
      'adrenaline_entertainment',
    },
    safetyNoticeRequiredCategoryIds: <String>{
      'auto_moto',
      'adrenaline_entertainment',
      'water_activities',
    },
    idRequiredCategoryIds: <String>{'auto_moto'},
    sizeVariantRequiredCategoryIds: <String>{'sport', 'winter_seasonal'},
  );
}
