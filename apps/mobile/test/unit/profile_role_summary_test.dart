import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/explore/application/profile_role_summary.dart';

void main() {
  test('maps default user role to User tier', () {
    final ProfileRoleSummary summary = profileRoleSummaryFor(
      role: 'user',
      capabilities: const <String>['discover.read', 'favorites.write'],
    );

    expect(summary.tier, ProfileRoleTier.user);
    expect(summary.canCreate, isFalse);
    expect(summary.canGenerate, isFalse);
    expect(summary.primaryActionLabel, 'Open Saved');
  });

  test('does not promote a user from create capabilities alone', () {
    final ProfileRoleSummary summary = profileRoleSummaryFor(
      role: 'user',
      capabilities: const <String>['create.event', 'create.place'],
    );

    expect(summary.tier, ProfileRoleTier.user);
    expect(summary.canCreate, isFalse);
    expect(summary.canGenerate, isFalse);
    expect(summary.primaryActionLabel, 'Open Saved');
  });

  test('maps generator capabilities to Pro generator tier', () {
    final ProfileRoleSummary summary = profileRoleSummaryFor(
      role: 'creator',
      capabilities: const <String>['create.event', 'scenario.generate'],
    );

    expect(summary.tier, ProfileRoleTier.proGenerator);
    expect(summary.canCreate, isTrue);
    expect(summary.canGenerate, isTrue);
    expect(summary.primaryActionLabel, 'Open Builder');
  });
}
