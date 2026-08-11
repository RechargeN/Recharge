import '../entities/scenario_budget_draft.dart';
import '../entities/scenario_draft_data.dart';
import '../entities/scenario_item_draft.dart';
import '../entities/scenario_logistics_draft.dart';
import '../entities/scenario_validation_issue.dart';
import 'validate_scenario_draft_usecase.dart';

class ScenarioReadinessResult {
  const ScenarioReadinessResult({
    required this.totals,
    required this.validation,
  });

  final ScenarioTotalsDraft totals;
  final ScenarioValidationResult validation;

  bool get canSaveToMyScenarios => validation.isValid;
}

class EvaluateScenarioReadinessUseCase {
  const EvaluateScenarioReadinessUseCase({
    this.validator = const ValidateScenarioDraftUseCase(),
  });

  final ValidateScenarioDraftUseCase validator;

  ScenarioReadinessResult call(
    ScenarioDraftData draft, {
    ScenarioValidationTarget target = ScenarioValidationTarget.myScenarios,
  }) {
    final ScenarioValidationResult validation = validator(
      draft,
      target: target,
    );
    final Set<String> activeIds = draft.activeScheduledItems
        .map((ScenarioItemDraft item) => item.id)
        .toSet();
    final Map<String, ScenarioItemDraft> itemsById =
        <String, ScenarioItemDraft>{
          for (final ScenarioItemDraft item in draft.items) item.id: item,
        };

    int activityMinutes = 0;
    int plannedBlockMinutes = 0;
    int localTravelMinutes = 0;
    int plannedTransportMinutes = 0;
    int implicitWaitingMinutes = 0;
    int stayNights = 0;
    int estimatedCostCount = 0;
    int unknownCostCount = 0;
    int unresolvedLegCount = 0;
    double localDistance = 0;
    double embeddedRouteDistance = 0;

    final Map<String, _MoneyAccumulator> currencyTotals =
        <String, _MoneyAccumulator>{};
    final _MoneyAccumulator experienceDisplay = _MoneyAccumulator();
    final _MoneyAccumulator stayDisplay = _MoneyAccumulator();
    final _MoneyAccumulator localTravelDisplay = _MoneyAccumulator();
    final _MoneyAccumulator transportDisplay = _MoneyAccumulator();

    for (final ScenarioItemDraft item in draft.items) {
      if (!activeIds.contains(item.id)) {
        continue;
      }
      final int duration = item.durationMinutes ?? _intervalMinutes(item) ?? 0;
      switch (item.kind) {
        case ScenarioItemKind.timeBlock:
          plannedBlockMinutes += duration;
        case ScenarioItemKind.plannedTransport:
          plannedTransportMinutes += duration;
        case ScenarioItemKind.stay:
          stayNights += _stayNights(item);
        case ScenarioItemKind.visit:
        case ScenarioItemKind.event:
        case ScenarioItemKind.activity:
        case ScenarioItemKind.route:
        case ScenarioItemKind.bookableSession:
          activityMinutes += duration;
      }
      if (item.kind == ScenarioItemKind.route &&
          item.source is ScenarioCatalogObjectSourceDraft) {
        final ScenarioCatalogObjectSourceDraft source =
            item.source as ScenarioCatalogObjectSourceDraft;
        final double? distance = source.snapshot.distanceM;
        if (distance != null &&
            distance >= 0 &&
            item.sourceStatus != ScenarioSourceStatus.unresolved) {
          embeddedRouteDistance += distance;
        }
      }
      final _CostCounts counts = _accumulateCost(
        item.cost,
        peopleCount: draft.party.peopleCount,
        childrenCount: draft.party.childrenCount ?? 0,
        stayNights: item.kind == ScenarioItemKind.stay ? _stayNights(item) : 0,
        displayCurrency: draft.displayCurrencyCode,
        currencyTotals: currencyTotals,
        displayTarget: switch (item.kind) {
          ScenarioItemKind.stay => stayDisplay,
          ScenarioItemKind.plannedTransport => transportDisplay,
          _ => experienceDisplay,
        },
      );
      estimatedCostCount += counts.estimated;
      unknownCostCount += counts.unknown + counts.unconverted;
    }

    for (final ScenarioLegDraft leg in draft.legs) {
      if (!_legIsRelevant(leg, activeIds, itemsById)) {
        continue;
      }
      if (leg.durationMinutes == null ||
          leg.status == ScenarioLegStatus.failed ||
          leg.status == ScenarioLegStatus.unavailable ||
          leg.status == ScenarioLegStatus.loading) {
        unresolvedLegCount += 1;
      } else {
        localTravelMinutes += leg.durationMinutes!;
      }
      if (leg.distanceM != null && leg.distanceM! >= 0) {
        localDistance += leg.distanceM!;
      }
      final _CostCounts counts = _accumulateCost(
        leg.cost,
        peopleCount: draft.party.peopleCount,
        childrenCount: draft.party.childrenCount ?? 0,
        stayNights: 0,
        displayCurrency: draft.displayCurrencyCode,
        currencyTotals: currencyTotals,
        displayTarget: localTravelDisplay,
      );
      estimatedCostCount += counts.estimated;
      unknownCostCount += counts.unknown + counts.unconverted;
    }

    final List<ScenarioDayTotalsDraft> dayTotals = draft.days
        .map((ScenarioDayDraft day) {
          int dayActivity = 0;
          int dayBlocks = 0;
          int dayTransport = 0;
          int dayTravel = 0;
          int unresolved = 0;
          for (final String itemId in day.itemIds) {
            if (!activeIds.contains(itemId)) {
              continue;
            }
            final ScenarioItemDraft? item = itemsById[itemId];
            if (item == null) {
              unresolved += 1;
              continue;
            }
            final int? duration =
                item.durationMinutes ?? _intervalMinutes(item);
            if (duration == null) {
              unresolved += 1;
            } else {
              switch (item.kind) {
                case ScenarioItemKind.timeBlock:
                  dayBlocks += duration;
                case ScenarioItemKind.plannedTransport:
                  dayTransport += duration;
                case ScenarioItemKind.stay:
                  break;
                case ScenarioItemKind.visit:
                case ScenarioItemKind.event:
                case ScenarioItemKind.activity:
                case ScenarioItemKind.route:
                case ScenarioItemKind.bookableSession:
                  dayActivity += duration;
              }
            }
          }
          for (final ScenarioLegDraft leg in draft.legs) {
            if (leg.dayId != day.id ||
                !_legIsRelevant(leg, activeIds, itemsById)) {
              continue;
            }
            if (leg.durationMinutes == null ||
                leg.status == ScenarioLegStatus.failed ||
                leg.status == ScenarioLegStatus.unavailable ||
                leg.status == ScenarioLegStatus.loading) {
              unresolved += 1;
            } else {
              dayTravel += leg.durationMinutes!;
            }
          }
          final int known = dayActivity + dayBlocks + dayTransport + dayTravel;
          return ScenarioDayTotalsDraft(
            dayId: day.id,
            activityMinutes: dayActivity,
            plannedBlockMinutes: dayBlocks,
            localTravelMinutes: dayTravel,
            plannedTransportMinutes: dayTransport,
            implicitWaitingMinutes: 0,
            elapsedMinutes: unresolved == 0 ? known : null,
            unresolvedValueCount: unresolved,
          );
        })
        .toList(growable: false);

    final _MoneyAccumulator displayTotal = _MoneyAccumulator()
      ..known =
          experienceDisplay.known +
          stayDisplay.known +
          localTravelDisplay.known +
          transportDisplay.known
      ..estimated =
          experienceDisplay.estimated +
          stayDisplay.estimated +
          localTravelDisplay.estimated +
          transportDisplay.estimated
      ..includedCount =
          experienceDisplay.includedCount +
          stayDisplay.includedCount +
          localTravelDisplay.includedCount +
          transportDisplay.includedCount
      ..incomplete =
          experienceDisplay.incomplete ||
          stayDisplay.incomplete ||
          localTravelDisplay.incomplete ||
          transportDisplay.incomplete;

    final ScenarioTotalsDraft totals = ScenarioTotalsDraft(
      activityMinutes: activityMinutes,
      plannedBlockMinutes: plannedBlockMinutes,
      localTravelMinutes: localTravelMinutes,
      plannedTransportMinutes: plannedTransportMinutes,
      implicitWaitingMinutes: implicitWaitingMinutes,
      stayNights: stayNights,
      dayTotals: dayTotals,
      displayIncludedExperienceCost: _moneyOrNull(
        experienceDisplay,
        draft.displayCurrencyCode,
      ),
      displayIncludedStayCost: _moneyOrNull(
        stayDisplay,
        draft.displayCurrencyCode,
      ),
      displayIncludedLocalTravelCost: _moneyOrNull(
        localTravelDisplay,
        draft.displayCurrencyCode,
      ),
      displayIncludedPlannedTransportCost: _moneyOrNull(
        transportDisplay,
        draft.displayCurrencyCode,
      ),
      displayFromTotalCost: _moneyOrNull(
        displayTotal,
        draft.displayCurrencyCode,
      ),
      originalCurrencySubtotals:
          currencyTotals.entries
              .map(
                (MapEntry<String, _MoneyAccumulator> entry) =>
                    ScenarioCurrencySubtotalDraft(
                      currencyCode: entry.key,
                      knownMinorUnits: entry.value.known,
                      estimatedMinorUnits: entry.value.estimated,
                    ),
              )
              .toList(growable: false)
            ..sort(
              (
                ScenarioCurrencySubtotalDraft a,
                ScenarioCurrencySubtotalDraft b,
              ) => a.currencyCode.compareTo(b.currencyCode),
            ),
      exchangeRateSnapshotId: null,
      estimatedCostCount: estimatedCostCount,
      unknownCostCount: unknownCostCount,
      knownLocalTravelDistanceM: localDistance,
      knownEmbeddedRouteDistanceM: embeddedRouteDistance,
      activeItemCount: activeIds.length,
      dayCount: draft.days.length,
      unresolvedLegCount: unresolvedLegCount,
      warningCount: validation.warningCount,
    );

    return ScenarioReadinessResult(totals: totals, validation: validation);
  }

  static _CostCounts _accumulateCost(
    ScenarioCostDraft cost, {
    required int peopleCount,
    required int childrenCount,
    required int stayNights,
    required String displayCurrency,
    required Map<String, _MoneyAccumulator> currencyTotals,
    required _MoneyAccumulator displayTarget,
  }) {
    int estimated = 0;
    int unknown = 0;
    int unconverted = 0;
    for (final ScenarioMoneyEstimateDraft component in cost.components) {
      if (component.knowledge == ScenarioPriceKnowledge.unknown) {
        unknown += 1;
        continue;
      }
      if (component.knowledge == ScenarioPriceKnowledge.estimated) {
        estimated += 1;
      }
      final ScenarioMoneyDraft? money = component.amount;
      if (money == null || money.minorUnits < 0) {
        continue;
      }
      final int multiplier = switch (component.basis) {
        ScenarioPriceBasis.perPerson => peopleCount,
        ScenarioPriceBasis.perAdult => (peopleCount - childrenCount).clamp(
          0,
          peopleCount,
        ),
        ScenarioPriceBasis.perChild => childrenCount,
        ScenarioPriceBasis.perNight => stayNights,
        ScenarioPriceBasis.perGroup ||
        ScenarioPriceBasis.perBooking ||
        null => 1,
      };
      final int total = money.minorUnits * multiplier;
      final _MoneyAccumulator currency = currencyTotals.putIfAbsent(
        money.currencyCode,
        _MoneyAccumulator.new,
      );
      final bool isEstimate =
          component.knowledge == ScenarioPriceKnowledge.estimated;
      if (isEstimate) {
        currency.estimated += total;
      } else {
        currency.known += total;
      }
      if (money.currencyCode == displayCurrency) {
        displayTarget.includedCount += 1;
        if (isEstimate) {
          displayTarget.estimated += total;
        } else {
          displayTarget.known += total;
        }
      } else {
        displayTarget.incomplete = true;
        unconverted += 1;
      }
    }
    return _CostCounts(
      estimated: estimated,
      unknown: unknown,
      unconverted: unconverted,
    );
  }

  static ScenarioMoneyDraft? _moneyOrNull(
    _MoneyAccumulator value,
    String currencyCode,
  ) {
    final int total = value.known + value.estimated;
    return value.includedCount == 0 || value.incomplete
        ? null
        : ScenarioMoneyDraft(minorUnits: total, currencyCode: currencyCode);
  }

  static bool _legIsRelevant(
    ScenarioLegDraft leg,
    Set<String> activeIds,
    Map<String, ScenarioItemDraft> itemsById,
  ) {
    final bool fromActive =
        leg.fromItemId == null ||
        (activeIds.contains(leg.fromItemId) &&
            itemsById.containsKey(leg.fromItemId));
    final bool toActive =
        leg.toItemId == null ||
        (activeIds.contains(leg.toItemId) &&
            itemsById.containsKey(leg.toItemId));
    return fromActive && toActive;
  }

  static int? _intervalMinutes(ScenarioItemDraft item) {
    final ScenarioPlannedTimeDraft planned = item.schedule.planned;
    if (planned is ScenarioDatedPlannedTimeDraft &&
        planned.fixedStartAtUtc != null &&
        planned.fixedEndAtUtc != null &&
        planned.fixedEndAtUtc!.isAfter(planned.fixedStartAtUtc!)) {
      return planned.fixedEndAtUtc!
          .difference(planned.fixedStartAtUtc!)
          .inMinutes;
    }
    if (planned is ScenarioTemplatePlannedTimeDraft &&
        planned.preferredStart != null &&
        planned.preferredEnd != null) {
      final int start =
          planned.startDayIndex * 1440 + planned.preferredStart!.minuteOfDay;
      final int end =
          (planned.endDayIndex ?? planned.startDayIndex) * 1440 +
          planned.preferredEnd!.minuteOfDay;
      return end > start ? end - start : null;
    }
    return null;
  }

  static int _stayNights(ScenarioItemDraft item) {
    final ScenarioPlannedTimeDraft planned = item.schedule.planned;
    if (planned is ScenarioDatedPlannedTimeDraft &&
        planned.fixedStartAtUtc != null &&
        planned.fixedEndAtUtc != null) {
      final int days = planned.fixedEndAtUtc!
          .difference(planned.fixedStartAtUtc!)
          .inDays;
      return days < 0 ? 0 : days;
    }
    if (planned is ScenarioTemplatePlannedTimeDraft &&
        planned.endDayIndex != null) {
      final int days = planned.endDayIndex! - planned.startDayIndex;
      return days < 0 ? 0 : days;
    }
    return 0;
  }
}

class _MoneyAccumulator {
  int known = 0;
  int estimated = 0;
  int includedCount = 0;
  bool incomplete = false;
}

class _CostCounts {
  const _CostCounts({
    required this.estimated,
    required this.unknown,
    required this.unconverted,
  });

  final int estimated;
  final int unknown;
  final int unconverted;
}
