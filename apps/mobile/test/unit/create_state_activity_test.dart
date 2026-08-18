import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/state/create_state.dart';
import 'package:recharge/features/create/domain/entities/activity_validation_issue.dart';

void main() {
  test('CreateState.initial starts at activityStep 0 with no issues', () {
    final CreateState state = CreateState.initial();
    expect(state.activityStep, 0);
    expect(state.activityValidationIssues, isEmpty);
  });

  test('copyWith sets and clears activityValidationIssues independently', () {
    final CreateState state = CreateState.initial();
    const List<ActivityValidationIssue> issues = <ActivityValidationIssue>[
      ActivityValidationIssue(
        code: 'access_notes_required',
        severity: ActivityValidationSeverity.error,
        sectionId: 'location',
        messageKey: 'activity.validation.access_notes_required',
      ),
    ];
    final CreateState withIssues = state.copyWith(
      activityStep: 2,
      activityValidationIssues: issues,
    );
    expect(withIssues.activityStep, 2);
    expect(withIssues.activityValidationIssues, issues);
    final CreateState cleared = withIssues.copyWith(
      clearActivityValidationIssues: true,
    );
    expect(cleared.activityValidationIssues, isEmpty);
    expect(cleared.activityStep, 2, reason: 'unrelated field must survive');
  });
}
