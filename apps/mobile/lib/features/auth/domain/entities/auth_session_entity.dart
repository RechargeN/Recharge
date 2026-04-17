class AuthSessionEntity {
  const AuthSessionEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.expiresAtUtc,
  });

  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final DateTime expiresAtUtc;
}
