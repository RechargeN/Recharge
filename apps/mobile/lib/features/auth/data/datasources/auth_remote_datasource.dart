import 'dart:math';

import '../models/auth_result_model.dart';
import '../models/auth_session_model.dart';
import '../models/auth_user_model.dart';

class AuthRemoteException implements Exception {
  const AuthRemoteException(this.code, this.message);

  final String code;
  final String message;
}

abstract class AuthRemoteDataSource {
  Future<AuthResultModel> login({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  });

  Future<AuthSessionModel> refresh({
    required String refreshToken,
    required String sessionId,
  });

  Future<void> logout({
    required String sessionId,
  });

  Future<AuthUserModel> me({
    required String accessToken,
  });
}

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  static const String _allowedEmail = 'user@example.com';
  static const String _allowedPassword = 'password123';
  static const String demoUserId = 'demo_full_access';
  static const String demoEmail = 'demo@recharge.local';
  static const List<String> demoCapabilities = <String>[
    'discover.read',
    'favorites.write',
    'profile.read',
    'profile.update',
    'create.event',
    'create.quick_plan',
    'create.social_request',
    'create.private_plan',
    'create.route',
    'create.place',
    'create.venue',
    'create.bookable_slot',
    'create.offer',
    'create.announcement',
    'scenario.generate',
    'manage_page',
    'view_insights',
    'manage_bookings',
  ];

  final Map<String, String> _sessionToUser = <String, String>{};

  @override
  Future<AuthResultModel> login({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (email != _allowedEmail || password != _allowedPassword) {
      throw const AuthRemoteException(
        'AUTH_INVALID_CREDENTIALS',
        'Invalid email or password',
      );
    }

    final sessionId = 'sess_${Random().nextInt(999999)}';
    _sessionToUser[sessionId] = demoUserId;

    return AuthResultModel.fromLoginJson(<String, dynamic>{
      'access_token': 'acc_${DateTime.now().millisecondsSinceEpoch}',
      'refresh_token': 'ref_${DateTime.now().millisecondsSinceEpoch}',
      'session_id': sessionId,
      'expires_in': 3600,
      'user': <String, dynamic>{
        'id': demoUserId,
        'email': _allowedEmail,
        'role': 'creator',
        'capabilities': demoCapabilities,
        'profile_status': 'active',
      },
    });
  }

  @override
  Future<AuthSessionModel> refresh({
    required String refreshToken,
    required String sessionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    if (!refreshToken.startsWith('ref_')) {
      throw const AuthRemoteException(
        'AUTH_REFRESH_INVALID',
        'Refresh token invalid',
      );
    }
    _sessionToUser[sessionId] = demoUserId;

    return AuthSessionModel.fromJson(<String, dynamic>{
      'access_token': 'acc_${DateTime.now().millisecondsSinceEpoch}',
      'refresh_token': 'ref_${DateTime.now().millisecondsSinceEpoch}',
      'session_id': sessionId,
      'expires_in': 3600,
    });
  }

  @override
  Future<void> logout({required String sessionId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _sessionToUser.remove(sessionId);
  }

  @override
  Future<AuthUserModel> me({required String accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!accessToken.startsWith('acc_')) {
      throw const AuthRemoteException(
        'UNAUTHORIZED',
        'Access token invalid',
      );
    }
    return AuthUserModel.fromJson(<String, dynamic>{
      'id': demoUserId,
      'email': demoEmail,
      'role': 'creator',
      'capabilities': demoCapabilities,
      'profile_status': 'active',
    });
  }
}
