import '../../domain/entities/identity_access_snapshot.dart';

class MockIdentityFixture {
  const MockIdentityFixture();

  IdentityAccessSnapshot accessForUser(String userId) {
    return IdentityAccessSnapshot(
      userId: userId,
      globalRole: 'admin',
      creatorVerificationStatus: CreatorVerificationStatus.verified,
      globalCapabilities: const <String>{
        'discover.read',
        'favorites.write',
        'profile.read',
        'profile.update',
        'create.event',
        'create.place',
        'create.route',
        'create.scenario',
        'create.collection',
        'submit.event',
        'submit.place',
        'submit.route',
        'submit.scenario',
        'submit.collection',
        'page.create',
        'admin.tools.view',
        'admin.experience.preview',
        'moderate.route',
        // CLG-CRT-01 §6: this fixture backs the admin identity snapshot,
        // same rationale as `moderate.route` above — exercises the real
        // accept/reject path even though no dedicated moderation page
        // ships in this slice.
        'moderate.collection',
      },
      pages: const [],
      memberships: const [],
      revision: 1,
    );
  }
}
