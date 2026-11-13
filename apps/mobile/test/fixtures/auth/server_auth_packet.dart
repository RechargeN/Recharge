final now = DateTime.utc(2026, 11, 5, 10);
Map<String, Object?> packet() => {
  'sessionContext': {
    'userId': '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
    'sessionId': '018FQ2Z8Q9N4M7K2T6V3W1X5YB',
    'sessionHandle': 'A' * 43,
    'installationId': 'dev-install',
    'expiresAtUtc': '2026-11-05T11:00:00.000Z',
  },
  'authContext': {
    'schemaVersion': 1,
    'profile': {
      'userId': '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
      'accountStatus': 'active',
      'systemRoles': ['User'],
    },
    'accessSnapshot': {
      'schemaVersion': 1,
      'userId': '018FQ2Z8Q9N4M7K2T6V3W1X5YA',
      'sessionId': '018FQ2Z8Q9N4M7K2T6V3W1X5YB',
      'accountRevision': 1,
      'sessionRevision': 1,
      'authzRevision': 1,
      'capabilityPolicyRevision': 1,
      'capabilityIds': ['booking.self_service'],
      'evaluatedAtUtc': '2026-11-05T10:00:00.000Z',
      'expiresAtUtc': '2026-11-05T11:00:00.000Z',
    },
  },
};
