import '../../domain/entities/auth_session_entity.dart';

class AuthSessionModel {
  const AuthSessionModel({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.expiresInSeconds,
    this.expiresAtUtcIso,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      sessionId: json['session_id'] as String,
      expiresInSeconds: json['expires_in'] as int? ?? 3600,
      expiresAtUtcIso: json['expires_at_utc'] as String?,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final int expiresInSeconds;
  final String? expiresAtUtcIso;

  Map<String, dynamic> toJson() {
    final expiresAt = expiresAtUtcIso ??
        DateTime.now().toUtc().add(Duration(seconds: expiresInSeconds)).toIso8601String();
    return <String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'session_id': sessionId,
      'expires_in': expiresInSeconds,
      'expires_at_utc': expiresAt,
    };
  }

  AuthSessionEntity toEntity() {
    final expiresAt = expiresAtUtcIso == null
        ? DateTime.now().toUtc().add(Duration(seconds: expiresInSeconds))
        : DateTime.parse(expiresAtUtcIso!).toUtc();
    return AuthSessionEntity(
      accessToken: accessToken,
      refreshToken: refreshToken,
      sessionId: sessionId,
      expiresAtUtc: expiresAt,
    );
  }
}
