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
              priceMinorUnits: step.isFree
                  ? 0
                  : (step.priceAmount * 100).round(),
              available: true,
            ),
          )
          .toList(growable: false),
      readableByUserIds: <String>{ownerId},
    );
  }
}
