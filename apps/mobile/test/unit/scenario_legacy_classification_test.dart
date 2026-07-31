import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/usecases/classify_legacy_planning_draft_usecase.dart';

void main() {
  const ClassifyLegacyPlanningDraftUseCase classify =
      ClassifyLegacyPlanningDraftUseCase();

  test('keeps private_plan and lightweight quick_plan as Quick Plan', () {
    expect(
      classify(<String, Object?>{'objectType': 'private_plan'}).target,
      LegacyPlanningTarget.quickPlan,
    );
    final LegacyPlanningClassification quickPlan = classify(<String, Object?>{
      'objectType': 'quick_plan',
      'stops': <Object?>[
        <String, Object?>{'id': 'place-1'},
        <String, Object?>{'id': 'place-2'},
      ],
    });
    expect(quickPlan.target, LegacyPlanningTarget.quickPlan);
    expect(quickPlan.requiresUserConfirmation, isFalse);
  });

  test('classifies Scenario-shaped legacy Create draft with confirmation', () {
    final LegacyPlanningClassification result = classify(<String, Object?>{
      'objectType': 'quick_plan',
      'sectionData': <String, Object?>{
        'scenario_details': <String, Object?>{
          'scenarioSchemaVersion': 1,
          'days': <Object?>[
            <String, Object?>{'id': 'day-1'},
          ],
          'legs': <Object?>[
            <String, Object?>{'id': 'leg-1'},
          ],
        },
      },
    });

    expect(result.target, LegacyPlanningTarget.scenario);
    expect(result.requiresUserConfirmation, isTrue);
    expect(result.reasonCodes, contains('legacy_quick_plan_slot'));
  });

  test('classifies continuous geometry as Route', () {
    final LegacyPlanningClassification result = classify(<String, Object?>{
      'objectType': 'route',
      'gpx': '<gpx />',
      'elevationGainM': 180,
    });

    expect(result.target, LegacyPlanningTarget.route);
    expect(result.requiresUserConfirmation, isFalse);
  });

  test('does not guess ambiguous scenario-route handoff', () {
    final LegacyPlanningClassification result = classify(<String, Object?>{
      'objectType': 'route',
      'mode': 'scenario',
      'title': 'Scenario route for tonight',
      'stops': <Object?>[
        <String, Object?>{'id': 'place-1'},
        <String, Object?>{'id': 'place-2'},
      ],
    });

    expect(result.target, LegacyPlanningTarget.unresolved);
    expect(result.requiresUserConfirmation, isTrue);
    expect(result.reasonCodes, contains('ambiguous_scenario_route_handoff'));
  });

  test('mixed track and Scenario evidence stays unresolved', () {
    final LegacyPlanningClassification result = classify(<String, Object?>{
      'objectType': 'quick_plan',
      'geometry': <Object?>[
        <double>[56.9, 24.1],
      ],
      'days': <Object?>[
        <String, Object?>{'id': 'day-1'},
      ],
    });

    expect(result.target, LegacyPlanningTarget.unresolved);
    expect(result.reasonCodes, contains('mixed_route_scenario_evidence'));
  });

  test('canonical scenario type is classified without confirmation', () {
    final LegacyPlanningClassification result = classify(<String, Object?>{
      'objectType': 'scenario',
    });

    expect(result.target, LegacyPlanningTarget.scenario);
    expect(result.requiresUserConfirmation, isFalse);
  });
}
