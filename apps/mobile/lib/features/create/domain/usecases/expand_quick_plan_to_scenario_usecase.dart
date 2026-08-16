import '../../../../shared/primitives/id/id_generator.dart';
import '../../../../shared/primitives/money/currency_code.dart';
import '../../../../shared/primitives/money/money.dart';
import '../entities/quick_plan_conversion.dart';
import '../entities/scenario_budget_draft.dart';
import '../entities/scenario_draft_data.dart';
import '../entities/scenario_item_draft.dart';
import '../repositories/quick_plan_conversion_source_port.dart';
import 'evaluate_scenario_readiness_usecase.dart';

class ExpandQuickPlanToScenarioUseCase {
  const ExpandQuickPlanToScenarioUseCase({
    required QuickPlanConversionSourcePort source,
    required IdGenerator idGenerator,
    EvaluateScenarioReadinessUseCase evaluateReadiness =
        const EvaluateScenarioReadinessUseCase(),
  }) : _source = source,
       _idGenerator = idGenerator,
       _evaluateReadiness = evaluateReadiness;

  final QuickPlanConversionSourcePort _source;
  final IdGenerator _idGenerator;
  final EvaluateScenarioReadinessUseCase _evaluateReadiness;

  Future<ExpandQuickPlanToScenarioResult> call(
    ExpandQuickPlanToScenarioRequest request,
  ) async {
    final QuickPlanConversionSnapshot? source = await _source.loadForCopy(
      quickPlanId: request.quickPlanId,
      requesterId: request.requesterId,
    );
    if (source == null) {
      return const ExpandQuickPlanToScenarioResult(
        scenario: null,
        issues: <QuickPlanConversionIssue>[
          QuickPlanConversionIssue(
            code: QuickPlanConversionIssueCode.sourceNotFoundOrForbidden,
            severity: QuickPlanConversionIssueSeverity.error,
            message: 'Quick Plan is unavailable or cannot be copied',
          ),
        ],
        quickPlanStopIdToScenarioItemId: <String, String>{},
        privateNotesByScenarioItemId: <String, String>{},
        sourceRevision: null,
      );
    }

    final List<QuickPlanConversionIssue> issues = <QuickPlanConversionIssue>[];
    if (source.revision != request.expectedQuickPlanRevision) {
      issues.add(
        QuickPlanConversionIssue(
          code: QuickPlanConversionIssueCode.sourceRevisionMismatch,
          severity: request.continueWithLatestSnapshot
              ? QuickPlanConversionIssueSeverity.warning
              : QuickPlanConversionIssueSeverity.error,
          message:
              'Quick Plan changed from revision ${request.expectedQuickPlanRevision} to ${source.revision}',
        ),
      );
      if (!request.continueWithLatestSnapshot) {
        return ExpandQuickPlanToScenarioResult(
          scenario: null,
          issues: List<QuickPlanConversionIssue>.unmodifiable(issues),
          quickPlanStopIdToScenarioItemId: const <String, String>{},
          privateNotesByScenarioItemId: const <String, String>{},
          sourceRevision: source.revision,
        );
      }
    }

    if (request.selectedStopIds.isEmpty) {
      issues.add(
        const QuickPlanConversionIssue(
          code: QuickPlanConversionIssueCode.selectionEmpty,
          severity: QuickPlanConversionIssueSeverity.error,
          message: 'Select at least one stop to expand',
        ),
      );
      return ExpandQuickPlanToScenarioResult(
        scenario: null,
        issues: List<QuickPlanConversionIssue>.unmodifiable(issues),
        quickPlanStopIdToScenarioItemId: const <String, String>{},
        privateNotesByScenarioItemId: const <String, String>{},
        sourceRevision: source.revision,
      );
    }

    final String dayId = _idGenerator.generate();
    final List<ScenarioLocationDraft> locations = <ScenarioLocationDraft>[];
    final List<ScenarioItemDraft> items = <ScenarioItemDraft>[];
    final Map<String, String> itemIds = <String, String>{};
    final Map<String, String> privateNotes = <String, String>{};

    final Set<String> processedStopIds = <String>{};
    for (final QuickPlanConversionStopSnapshot stop in source.stops) {
      if (!request.selectedStopIds.contains(stop.id)) continue;
      processedStopIds.add(stop.id);
      if (!stop.available) {
        issues.add(
          QuickPlanConversionIssue(
            code: QuickPlanConversionIssueCode.stopUnavailable,
            severity: QuickPlanConversionIssueSeverity.warning,
            message:
                '${stop.title} is unavailable and must be resolved in Scenario',
            quickPlanStopId: stop.id,
          ),
        );
      }

      final String locationId = _idGenerator.generate();
      final String itemId = _idGenerator.generate();
      locations.add(
        ScenarioLocationDraft(
          id: locationId,
          point: ScenarioGeoPointDraft(
            latitude: stop.latitude,
            longitude: stop.longitude,
          ),
          title: stop.title,
          timezoneId: source.timezoneId,
          disclosure: ScenarioLocationDisclosure.private,
        ),
      );
      items.add(
        ScenarioItemDraft(
          id: itemId,
          dayId: dayId,
          startLocationId: locationId,
          endLocationId: locationId,
          kind: ScenarioItemKind.visit,
          source: ScenarioCustomLocationSourceDraft(locationId: locationId),
          sourceStatus: stop.available
              ? ScenarioSourceStatus.ready
              : ScenarioSourceStatus.unavailable,
          schedule: const ScenarioScheduleDraft(
            mode: ScenarioTimeMode.flexible,
            planned: ScenarioTemplatePlannedTimeDraft(startDayIndex: 0),
          ),
          durationMinutes: stop.durationMinutes,
          cost: _cost(stop, source.currency),
          orderLocked: false,
          timeLocked: false,
          role: ScenarioItemRole.mandatory,
          selected: true,
          publicNote: '',
        ),
      );
      itemIds[stop.id] = itemId;
      final String note = stop.requesterPrivateNote?.trim() ?? '';
      if (note.isNotEmpty) {
        if (request.copyPrivateNotes) {
          privateNotes[itemId] = note;
        } else {
          issues.add(
            QuickPlanConversionIssue(
              code: QuickPlanConversionIssueCode.privateNoteNotCopied,
              severity: QuickPlanConversionIssueSeverity.warning,
              message: 'Private note for ${stop.title} was not copied',
              quickPlanStopId: stop.id,
            ),
          );
        }
      }
      issues.add(
        QuickPlanConversionIssue(
          code: QuickPlanConversionIssueCode
              .legacyStopBecamePrivateCustomLocation,
          severity: QuickPlanConversionIssueSeverity.warning,
          message:
              '${stop.title} was copied as a private custom location because the legacy plan has no catalog object id',
          quickPlanStopId: stop.id,
        ),
      );
    }
    for (final String stopId in request.selectedStopIds.difference(
      processedStopIds,
    )) {
      issues.add(
        QuickPlanConversionIssue(
          code: QuickPlanConversionIssueCode.stopNotFound,
          severity: QuickPlanConversionIssueSeverity.warning,
          message: 'Selected stop no longer exists',
          quickPlanStopId: stopId,
        ),
      );
    }

    var scenario =
        ScenarioDraftData.defaults(
          timezoneId: source.timezoneId,
          currencyCode: source.currencyCode,
        ).copyWith(
          days: <ScenarioDayDraft>[
            ScenarioDayDraft(
              id: dayId,
              title: 'Day 1',
              dayIndex: 0,
              timezoneId: source.timezoneId,
              itemIds: items
                  .map((ScenarioItemDraft item) => item.id)
                  .toList(growable: false),
            ),
          ],
          locations: locations,
          items: items,
          origin: ScenarioOriginDraft(
            type: ScenarioOriginType.quickPlanConversion,
            sourceId: source.id,
            sourceRevision: source.revision,
          ),
        );
    scenario = scenario.copyWith(totals: _evaluateReadiness(scenario).totals);
    return ExpandQuickPlanToScenarioResult(
      scenario: scenario,
      issues: List<QuickPlanConversionIssue>.unmodifiable(issues),
      quickPlanStopIdToScenarioItemId: Map<String, String>.unmodifiable(
        itemIds,
      ),
      privateNotesByScenarioItemId: Map<String, String>.unmodifiable(
        privateNotes,
      ),
      sourceRevision: source.revision,
    );
  }

  static ScenarioCostDraft _cost(
    QuickPlanConversionStopSnapshot stop,
    CurrencyCode currency,
  ) {
    if (stop.isFree) {
      return ScenarioCostDraft(
        components: <ScenarioMoneyEstimateDraft>[
          ScenarioMoneyEstimateDraft(
            componentCode: 'experience',
            knowledge: ScenarioPriceKnowledge.free,
            source: ScenarioPriceSource.manual,
            amount: ScenarioMoneyDraft.fromMoney(Money.zero(currency)),
            basis: ScenarioPriceBasis.perPerson,
          ),
        ],
      );
    }
    final Money? amount = stop.price;
    if (amount == null) {
      return const ScenarioCostDraft(
        components: <ScenarioMoneyEstimateDraft>[
          ScenarioMoneyEstimateDraft(
            componentCode: 'experience',
            knowledge: ScenarioPriceKnowledge.unknown,
            source: ScenarioPriceSource.manual,
          ),
        ],
      );
    }
    return ScenarioCostDraft(
      components: <ScenarioMoneyEstimateDraft>[
        ScenarioMoneyEstimateDraft(
          componentCode: 'experience',
          knowledge: ScenarioPriceKnowledge.estimated,
          source: ScenarioPriceSource.manual,
          amount: ScenarioMoneyDraft.fromMoney(amount),
          basis: ScenarioPriceBasis.perPerson,
          confidence: 0.5,
        ),
      ],
    );
  }
}
