import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/scenario_create_coordinator.dart';
import 'package:recharge/features/create/application/scenario_generation_coordinator.dart';
import 'package:recharge/features/create/data/datasources/catalog_object_picker_mock_datasource.dart';
import 'package:recharge/features/create/data/datasources/scenario_proposal_mock_datasource.dart';
import 'package:recharge/features/create/domain/entities/scenario_generation_proposal.dart';
import 'package:recharge/features/create/domain/entities/scenario_item_draft.dart';
import 'package:recharge/features/create/domain/repositories/scenario_proposal_generator_port.dart';
import 'package:recharge/features/create/domain/usecases/generate_scenario_proposal_usecase.dart';

void main() {
  late ScenarioCreateCoordinator createCoordinator;
  late ScenarioGenerationCoordinator generationCoordinator;
  late MockCatalogObjectPickerDataSource catalog;

  setUp(() {
    catalog = const MockCatalogObjectPickerDataSource();
    createCoordinator = ScenarioCreateCoordinator(
      idGenerator: _SequentialIdGenerator(),
    );
    generationCoordinator = ScenarioGenerationCoordinator(
      generateProposal: GenerateScenarioProposalUseCase(
        MockScenarioProposalDataSource(catalog: catalog),
      ),
      scenarioCreateCoordinator: createCoordinator,
    );
  });

  test(
    'local demo returns bounded catalog proposal without mutating draft',
    () async {
      final draft = createCoordinator.initial(
        timezoneId: 'Europe/Riga',
        currencyCode: 'EUR',
      );
      final int sourceRevision = draft.revision;

      final ScenarioGenerationPreview preview = await generationCoordinator
          .generate(
            prompt: 'Calm culture walk and dinner',
            marketCityId: 'riga',
            draft: draft,
          );

      expect(draft.revision, sourceRevision);
      expect(draft.items, isEmpty);
      expect(preview.proposal.mode, ScenarioGenerationMode.localDemo);
      expect(preview.proposal.sourceRevision, sourceRevision);
      expect(preview.proposal.items, isNotEmpty);
      expect(preview.proposal.items.length, lessThanOrEqualTo(3));
      expect(
        preview.proposal.items.every(
          (ScenarioGeneratedCatalogItem item) =>
              item.confidence == ScenarioGenerationConfidence.catalogSnapshot,
        ),
        isTrue,
      );
      expect(
        preview.proposal.issues.map(
          (ScenarioGenerationIssue issue) => issue.code,
        ),
        containsAll(<ScenarioGenerationIssueCode>[
          ScenarioGenerationIssueCode.travelNotCalculated,
          ScenarioGenerationIssueCode.liveAvailabilityNotChecked,
          ScenarioGenerationIssueCode.costsUnknown,
        ]),
      );
    },
  );

  test(
    'existing catalog stop is preserved and excluded from proposal',
    () async {
      final candidates = await catalog.search('');
      var draft = createCoordinator.initial(
        timezoneId: 'Europe/Riga',
        currencyCode: 'EUR',
      );
      draft = createCoordinator.addCatalogItem(draft, candidates.first);

      final ScenarioGenerationPreview preview = await generationCoordinator
          .generate(
            prompt: 'Calm afternoon',
            marketCityId: 'riga',
            draft: draft,
          );
      final next = generationCoordinator.apply(draft, preview.proposal);

      expect(
        preview.proposal.items.map(
          (ScenarioGeneratedCatalogItem item) => item.objectId,
        ),
        isNot(contains(candidates.first.id)),
      );
      final catalogObjectIds = next.items
          .map((ScenarioItemDraft item) => item.source)
          .whereType<ScenarioCatalogObjectSourceDraft>()
          .map((ScenarioCatalogObjectSourceDraft source) => source.objectId)
          .toList();
      expect(
        catalogObjectIds.where((String id) => id == candidates.first.id),
        hasLength(1),
      );
      expect(next.items.length, 1 + preview.proposal.items.length);
    },
  );

  test('apply rejects proposal after source revision changes', () async {
    final draft = createCoordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    final ScenarioGenerationPreview preview = await generationCoordinator
        .generate(
          prompt: 'Culture and coffee',
          marketCityId: 'riga',
          draft: draft,
        );
    final changed = createCoordinator.addTimeBlock(
      draft,
      title: 'Locked anchor',
      durationMinutes: 30,
    );

    expect(
      () => generationCoordinator.apply(changed, preview.proposal),
      throwsA(isA<ScenarioGenerationStaleFailure>()),
    );
  });

  test('empty prompt is rejected before the generator runs', () async {
    final draft = createCoordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );

    await expectLater(
      generationCoordinator.generate(
        prompt: '   ',
        marketCityId: 'riga',
        draft: draft,
      ),
      throwsA(
        isA<ScenarioGenerationFailure>().having(
          (ScenarioGenerationFailure error) => error.code,
          'code',
          ScenarioGenerationFailureCode.emptyPrompt,
        ),
      ),
    );
  });

  test('invalid provider result fails closed before preview', () async {
    final draft = createCoordinator.initial(
      timezoneId: 'Europe/Riga',
      currencyCode: 'EUR',
    );
    final ScenarioGenerationCoordinator invalidCoordinator =
        ScenarioGenerationCoordinator(
          generateProposal: const GenerateScenarioProposalUseCase(
            _InvalidProposalGenerator(),
          ),
          scenarioCreateCoordinator: createCoordinator,
        );

    await expectLater(
      invalidCoordinator.generate(
        prompt: 'Culture and coffee',
        marketCityId: 'riga',
        draft: draft,
      ),
      throwsA(
        isA<ScenarioGenerationFailure>().having(
          (ScenarioGenerationFailure error) => error.code,
          'code',
          ScenarioGenerationFailureCode.invalidProposal,
        ),
      ),
    );
  });
}

class _SequentialIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() => 'scenario-generation-id-${_value++}';
}

class _InvalidProposalGenerator implements ScenarioProposalGeneratorPort {
  const _InvalidProposalGenerator();

  @override
  Future<ScenarioGenerationProposal> generate(
    ScenarioGenerationRequest request,
  ) async {
    return ScenarioGenerationProposal(
      id: '',
      mode: ScenarioGenerationMode.localDemo,
      sourceRevision: request.sourceRevision,
      generatedAtUtc: DateTime.utc(2026, 7, 31),
      context: const ScenarioGenerationContext(
        marketLabel: 'Riga',
        formatLabel: 'Day plan',
        partyLabel: '1 person',
        paceLabel: 'Balanced pace',
        travelLabel: 'Walking',
        intentLabels: <String>[],
      ),
      items: const <ScenarioGeneratedCatalogItem>[],
      evidence: const <ScenarioGenerationEvidence>[],
      issues: const <ScenarioGenerationIssue>[],
      activityMinutes: 0,
    );
  }
}
