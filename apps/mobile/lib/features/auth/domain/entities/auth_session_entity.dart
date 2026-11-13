class AuthSessionEntity {
  const AuthSessionEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.expiresAtUtc,
  }) : serverSessionHandle = null,
       installationId = null;

  const AuthSessionEntity.serverIssued({
    required this.sessionId,
    required this.expiresAtUtc,
    required this.serverSessionHandle,
    required this.installationId,
  }) : accessToken = null,
       refreshToken = null;

  final String? accessToken;
  final String? refreshToken;
  final String? serverSessionHandle;
  final String? installationId;
  final String sessionId;
  final DateTime expiresAtUtc;
}
