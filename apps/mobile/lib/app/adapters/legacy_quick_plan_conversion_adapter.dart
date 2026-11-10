import '../../shared/primitives/money/currency_code.dart';
import '../../features/create/domain/entities/quick_plan_conversion.dart';
import '../../features/create/domain/entities/scenario_item_draft.dart';
import '../../features/scenarios/domain/entities/scenario_draft_entity.dart';

class LegacyQuickPlanConversionAdapter {
  const LegacyQuickPlanConversionAdapter();

  QuickPlanConversionSnapshot toSnapshot({
    required ScenarioDraftEntity draft,
    required String ownerId,
    required String title,
    required String timezoneId,
    required String currencyCode,
  }) {
    final currency = CurrencyCode.parse(currencyCode);
    for (final step in draft.steps) {
      step.priceAmount.minorUnitsIn(currency);
    }
    return QuickPlanConversionSnapshot(
      id: draft.id,
      revision: draft.revision,
      ownerId: ownerId,
      title: title.trim().isEmpty ? 'Quick Plan' : title.trim(),
      timezoneId: timezoneId,
      currencyCode: currencyCode,
      stops: draft.steps
          .map(
            (ScenarioStepEntity step) => QuickPlanConversionStopSnapshot(
              id: step.id,
              title: step.title,
              durationMinutes: step.durationMinutes > 0
                  ? step.durationMinutes
                  : null,
              latitude: step.latitude,
              longitude: step.longitude,
              isFree: step.isFree,
              price: step.priceAmount,
              available: true,
              distanceKm: step.distanceKm,
              sourceObjectId: step.sourceObjectId,
              sourceObjectType: _catalogObjectType(step.sourceObjectType),
            ),
          )
          .toList(growable: false),
      readableByUserIds: <String>{ownerId},
    );
  }

  static ScenarioCatalogObjectType? _catalogObjectType(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    for (final ScenarioCatalogObjectType type
        in ScenarioCatalogObjectType.values) {
      if (type.name == normalized) return type;
    }
    return null;
  }
}
