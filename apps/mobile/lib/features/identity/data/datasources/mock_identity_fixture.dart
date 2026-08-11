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
        'submit.event',
        'submit.place',
        'submit.route',
        'submit.scenario',
        'page.create',
        'admin.tools.view',
        'admin.experience.preview',
        'moderate.route',
      },
      pages: const [],
      memberships: const [],
      revision: 1,
    );
  }
}
