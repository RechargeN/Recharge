import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/auth/data/models/server_auth_context.dart';

import '../fixtures/auth/server_auth_packet.dart';

// A34 2026-11-24 (RC 15df1cb, staging): Session, Class/Workshop and Route
// were refused on the phone with "Публикация недоступна для этого владельца"
// before any request left it. The server (ADR 0023) grants every active user
// the generic `content.create`, `content.submit`, `content.publish`; Create
// gates on per-type ids (`submit.session`, `create.route`, ...). The server
// answer is translated once, at the boundary, for the types the cloud
// publishes; the server stays the authority on every command.
void main() {
  ServerAuthContext parse(List<String> capabilityIds) {
    final data = packet();
    final auth = Map<String, Object?>.from(data['authContext']! as Map);
    final snapshot = Map<String, Object?>.from(auth['accessSnapshot']! as Map)
      ..['capabilityIds'] = capabilityIds;
    auth['accessSnapshot'] = snapshot;
    data['authContext'] = auth;
    return ServerAuthContext.fromResponse(
      data,
      installationId: 'dev-install',
      now: now,
    );
  }

  const cloudTypes = ['event', 'place', 'session', 'class_workshop', 'route'];

  test('ADR 0023 personal capabilities open Create for the cloud types', () {
    final caps = parse(const [
      'booking.self_service',
      'content.create',
      'content.publish',
      'content.submit',
    ]).result.user.capabilities;
    for (final type in cloudTypes) {
      expect(caps, contains('create.$type'), reason: type);
      expect(caps, contains('submit.$type'), reason: type);
      expect(caps, contains('publish.$type.direct'), reason: type);
    }
    // The server ids stay as they are.
    expect(
      caps,
      containsAll(const ['booking.self_service', 'content.publish']),
    );
  });

  test('without content capabilities nothing is granted', () {
    final caps = parse(const ['booking.self_service']).result.user.capabilities;
    expect(caps, ['booking.self_service']);
  });

  test('each server capability maps only to its own verb', () {
    final caps = parse(const ['content.submit']).result.user.capabilities;
    expect(caps, contains('submit.session'));
    expect(caps.where((c) => c.startsWith('create.')), isEmpty);
    expect(caps.where((c) => c.startsWith('publish.')), isEmpty);
  });

  test('types the cloud does not publish are not opened', () {
    final caps = parse(const [
      'content.create',
      'content.submit',
      'content.publish',
    ]).result.user.capabilities;
    for (final type in const [
      'scenario',
      'collection',
      'rental',
      'activity',
      'find_people',
    ]) {
      expect(caps.where((c) => c.contains(type)), isEmpty, reason: type);
    }
  });
}
