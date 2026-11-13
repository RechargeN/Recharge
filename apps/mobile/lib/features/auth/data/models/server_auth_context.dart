import '../../domain/entities/auth_result_entity.dart';
import '../../domain/entities/auth_session_entity.dart';
import '../../domain/entities/auth_user_entity.dart';

/// Server-issued personal projection; never deserialized from the Local auth cache.
final class ServerAuthContext {
  ServerAuthContext._(this.result, this.accountRevision);
  final AuthResultEntity result;
  final int accountRevision;

  factory ServerAuthContext.fromResponse(
    Map<String, Object?> data, {
    required String installationId,
    required DateTime now,
  }) {
    Never invalid() =>
        throw const FormatException('server_auth_context_invalid');
    Map<String, Object?> object(Object? value, Set<String> fields) {
      if (value is! Map || value.keys.any((key) => !fields.contains(key))) {
        invalid();
      }
      return Map<String, Object?>.from(value);
    }

    String text(Object? value) {
      if (value is! String || value.isEmpty || value.length > 512) {
        invalid();
      }
      return value;
    }

    DateTime instant(Object? value) {
      if (value is! String || !value.endsWith('Z')) {
        invalid();
      }
      final parsed = DateTime.tryParse(value);
      if (parsed == null || !parsed.isUtc) {
        invalid();
      }
      final shape = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?Z$',
      ).firstMatch(value);
      if (shape == null) {
        invalid();
      }
      final parts = [
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
      ];
      for (var i = 0; i < parts.length; i++) {
        if (parts[i] != int.parse(shape.group(i + 1)!)) {
          invalid();
        }
      }
      return parsed;
    }

    final session = object(data['sessionContext'], {
      'userId',
      'sessionId',
      'sessionHandle',
      'installationId',
      'expiresAtUtc',
    });
    final context = object(data['authContext'], {
      'schemaVersion',
      'profile',
      'accessSnapshot',
    });
    final profile = object(context['profile'], {
      'userId',
      'accountStatus',
      'systemRoles',
    });
    final snapshot = object(context['accessSnapshot'], {
      'schemaVersion',
      'userId',
      'sessionId',
      'accountRevision',
      'sessionRevision',
      'authzRevision',
      'capabilityPolicyRevision',
      'capabilityIds',
      'evaluatedAtUtc',
      'expiresAtUtc',
    });
    if (context['schemaVersion'] != 1 ||
        snapshot['schemaVersion'] != 1 ||
        profile['accountStatus'] != 'active') {
      invalid();
    }
    final userId = text(profile['userId']);
    final sessionId = text(session['sessionId']);
    final handle = text(session['sessionHandle']);
    if (!RegExp(
      r'^(?!__name__$)[A-Za-z0-9._:-]{1,128}$',
    ).hasMatch(installationId)) {
      invalid();
    }
    final entityId = RegExp(
      r'^(?:[0-9A-HJKMNP-TV-Z]{26}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$',
    );
    if (!entityId.hasMatch(userId) || !entityId.hasMatch(sessionId)) {
      invalid();
    }
    if (userId != snapshot['userId'] ||
        userId != session['userId'] ||
        sessionId != snapshot['sessionId'] ||
        session['installationId'] != installationId ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(handle)) {
      invalid();
    }
    for (final key in [
      'accountRevision',
      'sessionRevision',
      'authzRevision',
      'capabilityPolicyRevision',
    ]) {
      final revision = snapshot[key];
      if (revision is! int || revision < 0 || revision > 9007199254740991) {
        invalid();
      }
    }
    final roles = profile['systemRoles'];
    final capabilities = snapshot['capabilityIds'];
    if (roles is! List ||
        !roles.contains('User') ||
        roles.toSet().length != roles.length ||
        roles.any(
          (role) => !const {'User', 'Creator', 'Admin'}.contains(role),
        )) {
      invalid();
    }
    if (capabilities is! List ||
        capabilities.length > 64 ||
        capabilities.toSet().length != capabilities.length ||
        capabilities.any(
          (cap) =>
              cap is! String ||
              !RegExp(r'^[a-z][a-z0-9._-]{0,95}$').hasMatch(cap),
        )) {
      invalid();
    }
    final evaluated = instant(snapshot['evaluatedAtUtc']);
    final expires = instant(snapshot['expiresAtUtc']);
    if (instant(session['expiresAtUtc']) != expires ||
        !expires.isAfter(now.toUtc()) ||
        !expires.isAfter(evaluated) ||
        evaluated.isAfter(now.toUtc())) {
      invalid();
    }
    return ServerAuthContext._(
      AuthResultEntity(
        session: AuthSessionEntity.serverIssued(
          sessionId: sessionId,
          expiresAtUtc: expires,
          serverSessionHandle: handle,
          installationId: installationId,
        ),
        user: AuthUserEntity(
          id: userId,
          email: '', // Profile contract does not expose email.
          // ADR 0023: global roles are User and Admin; a legacy `Creator`
          // from an older server reads as `user` and grants nothing more.
          role: (roles).contains('Admin') ? 'admin' : 'user',
          capabilities: List<String>.unmodifiable(
            (capabilities).cast<String>(),
          ),
          profileStatus: 'active',
        ),
      ),
      snapshot['accountRevision'] as int,
    );
  }
}
