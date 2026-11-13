import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/legacy_planning_link_classifier.dart';
import 'package:recharge/app/adapters/legacy_planning_migration.dart';
import 'package:recharge/app/adapters/legacy_notification_route_resolver.dart';
import 'package:recharge/app/application/planning_navigation_intent.dart';
import 'package:recharge/app/application/planning_navigation_resolver.dart';

void main() {
  const resolver = PlanningNavigationResolver();

  test('each planning aggregate uses its typed stable-id address', () {
    expect(
      resolver.resolve(PlanningNavigationIntent.openScenario('scenario-1')),
      '/create/new/scenario?scenarioDraftId=scenario-1',
    );
    expect(
      resolver.resolve(PlanningNavigationIntent.openQuickPlan('quick-1')),
      '/quick-plan/quick-1',
    );
    expect(
      resolver.resolve(PlanningNavigationIntent.openRoute('route-1')),
      '/create/new/route?routeId=route-1',
    );
  });

  test('opening an aggregate without a stable id fails closed', () {
    expect(
      () => PlanningNavigationIntent.openScenario(''),
      throwsFormatException,
    );
    expect(
      () => PlanningNavigationIntent.openQuickPlan('loc_temporary'),
      throwsFormatException,
    );
  });

  test('legacy raw links are classified without guessing or rewriting', () {
    const classifier = LegacyPlanningLinkClassifier();
    expect(
      classifier.classify('/scenario-builder?mood=calm&duration=90').kind,
      LegacyPlanningPayloadKind.ambiguous,
    );
    final typed = classifier.classify(
      '/scenario-builder?scenarioDraftId=scenario-1',
    );
    expect(typed.kind, LegacyPlanningPayloadKind.scenario);
    expect(typed.targetId, 'scenario-1');
  });

  test('migration records result and never authorizes source deletion', () {
    const planner = LegacyPlanningMigrationPlanner();
    final ambiguous = planner.plan(
      sourceRecordId: 'notification-1',
      sourcePayload: '/scenario-builder?mood=calm',
    );
    expect(ambiguous.result, LegacyPlanningMigrationResult.retainedAmbiguous);
    expect(ambiguous.mayDeleteSource, isFalse);

    final typed = planner.plan(
      sourceRecordId: 'favorite-1',
      sourcePayload: '/legacy?quickPlanId=quick-1',
    );
    expect(typed.result, LegacyPlanningMigrationResult.migrated);
    expect(typed.targetId, 'quick-1');
    expect(typed.mayDeleteSource, isFalse);
  });

  test('old notification routes pass through compatibility resolver', () {
    const resolver = LegacyNotificationRouteResolver();
    expect(
      resolver.resolve('/legacy?scenarioDraftId=scenario-1'),
      '/create/new/scenario?scenarioDraftId=scenario-1',
    );
    expect(
      resolver.resolve('/scenario-builder?mood=calm'),
      '/scenario-builder?mood=calm',
    );
  });
}
