import '../../shared/primitives/money/currency_code.dart';
import '../../shared/primitives/money/money.dart';

import '../../features/create/domain/entities/quick_plan_conversion.dart';
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
    final CurrencyCode currency = CurrencyCode.parse(currencyCode);
    return QuickPlanConversionSnapshot(
      id: draft.id,
      revision: draft.revision,
      ownerId: ownerId,
      title: title.trim().isEmpty ? 'Quick Plan' : title.trim(),
      timezoneId: timezoneId,
      currency: currency,
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
              price: step.isFree ? Money.zero(currency) : step.price,
              available: true,
            ),
          )
          .toList(growable: false),
      readableByUserIds: <String>{ownerId},
    );
  }
}
