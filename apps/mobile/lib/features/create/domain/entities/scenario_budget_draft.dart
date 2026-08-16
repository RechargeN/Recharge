import '../../../../shared/primitives/money/currency_code.dart';
import '../../../../shared/primitives/money/money.dart';

enum ScenarioPriceKnowledge { free, known, estimated, unknown }

enum ScenarioPriceSource { catalog, userOverride, provider, manual }

enum ScenarioPriceBasis {
  perPerson,
  perAdult,
  perChild,
  perGroup,
  perNight,
  perBooking,
}

class ScenarioMoneyDraft {
  const ScenarioMoneyDraft({
    required this.minorUnits,
    required this.currencyCode,
  });

  final int minorUnits;
  final String currencyCode;

  factory ScenarioMoneyDraft.fromMoney(Money money) => ScenarioMoneyDraft(
    minorUnits: money.minorUnits,
    currencyCode: money.currency.value,
  );

  Money get money =>
      Money(minorUnits: minorUnits, currency: CurrencyCode.parse(currencyCode));

  bool get isStructurallyValid =>
      minorUnits >= 0 && RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode);
}

class ScenarioMoneyEstimateDraft {
  const ScenarioMoneyEstimateDraft({
    required this.componentCode,
    required this.knowledge,
    required this.source,
    this.amount,
    this.basis,
    this.observedAtUtc,
    this.confidence,
  });

  final String componentCode;
  final ScenarioPriceKnowledge knowledge;
  final ScenarioMoneyDraft? amount;
  final ScenarioPriceBasis? basis;
  final ScenarioPriceSource source;
  final DateTime? observedAtUtc;
  final double? confidence;
}

class ScenarioCostDraft {
  const ScenarioCostDraft({
    this.components = const <ScenarioMoneyEstimateDraft>[],
  });

  final List<ScenarioMoneyEstimateDraft> components;
}

class ScenarioCurrencySubtotalDraft {
  const ScenarioCurrencySubtotalDraft({
    required this.currencyCode,
    required this.knownMinorUnits,
    required this.estimatedMinorUnits,
  });

  final String currencyCode;
  final int knownMinorUnits;
  final int estimatedMinorUnits;
}

class ScenarioDayTotalsDraft {
  const ScenarioDayTotalsDraft({
    required this.dayId,
    required this.activityMinutes,
    required this.plannedBlockMinutes,
    required this.localTravelMinutes,
    required this.plannedTransportMinutes,
    required this.implicitWaitingMinutes,
    required this.elapsedMinutes,
    required this.unresolvedValueCount,
  });

  final String dayId;
  final int activityMinutes;
  final int plannedBlockMinutes;
  final int localTravelMinutes;
  final int plannedTransportMinutes;
  final int implicitWaitingMinutes;
  final int? elapsedMinutes;
  final int unresolvedValueCount;
}

class ScenarioTotalsDraft {
  const ScenarioTotalsDraft({
    required this.activityMinutes,
    required this.plannedBlockMinutes,
    required this.localTravelMinutes,
    required this.plannedTransportMinutes,
    required this.implicitWaitingMinutes,
    required this.stayNights,
    required this.dayTotals,
    required this.displayIncludedExperienceCost,
    required this.displayIncludedStayCost,
    required this.displayIncludedLocalTravelCost,
    required this.displayIncludedPlannedTransportCost,
    required this.displayFromTotalCost,
    required this.originalCurrencySubtotals,
    required this.exchangeRateSnapshotId,
    required this.estimatedCostCount,
    required this.unknownCostCount,
    required this.knownLocalTravelDistanceM,
    required this.knownEmbeddedRouteDistanceM,
    required this.activeItemCount,
    required this.dayCount,
    required this.unresolvedLegCount,
    required this.warningCount,
  });

  const ScenarioTotalsDraft.empty()
    : activityMinutes = 0,
      plannedBlockMinutes = 0,
      localTravelMinutes = 0,
      plannedTransportMinutes = 0,
      implicitWaitingMinutes = 0,
      stayNights = 0,
      dayTotals = const <ScenarioDayTotalsDraft>[],
      displayIncludedExperienceCost = null,
      displayIncludedStayCost = null,
      displayIncludedLocalTravelCost = null,
      displayIncludedPlannedTransportCost = null,
      displayFromTotalCost = null,
      originalCurrencySubtotals = const <ScenarioCurrencySubtotalDraft>[],
      exchangeRateSnapshotId = null,
      estimatedCostCount = 0,
      unknownCostCount = 0,
      knownLocalTravelDistanceM = 0,
      knownEmbeddedRouteDistanceM = 0,
      activeItemCount = 0,
      dayCount = 0,
      unresolvedLegCount = 0,
      warningCount = 0;

  final int activityMinutes;
  final int plannedBlockMinutes;
  final int localTravelMinutes;
  final int plannedTransportMinutes;
  final int implicitWaitingMinutes;
  final int stayNights;
  final List<ScenarioDayTotalsDraft> dayTotals;
  final ScenarioMoneyDraft? displayIncludedExperienceCost;
  final ScenarioMoneyDraft? displayIncludedStayCost;
  final ScenarioMoneyDraft? displayIncludedLocalTravelCost;
  final ScenarioMoneyDraft? displayIncludedPlannedTransportCost;
  final ScenarioMoneyDraft? displayFromTotalCost;
  final List<ScenarioCurrencySubtotalDraft> originalCurrencySubtotals;
  final String? exchangeRateSnapshotId;
  final int estimatedCostCount;
  final int unknownCostCount;
  final double knownLocalTravelDistanceM;
  final double knownEmbeddedRouteDistanceM;
  final int activeItemCount;
  final int dayCount;
  final int unresolvedLegCount;
  final int warningCount;
}
