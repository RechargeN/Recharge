import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'booking_callable_adapter.dart';
import 'booking_functions_transport.dart';

final class BookingAuthEmulatorConfig {
  const BookingAuthEmulatorConfig({
    required this.host,
    this.port = 9099,
    this.projectId = 'demo-recharge',
  });

  final String host;
  final int port;
  final String projectId;
}

typedef BookingFirebaseAuthFactory = Future<FirebaseAuth> Function();

/// Dev-only lazy provider. Constructing it performs no Firebase work.
final class FirebaseAuthIdTokenProvider
    implements BookingFirebaseIdTokenProvider {
  FirebaseAuthIdTokenProvider(this._authFactory);

  final BookingFirebaseAuthFactory _authFactory;
  FirebaseAuth? _auth;

  Future<FirebaseAuth> _instance() async => _auth ??= await _authFactory();

  @override
  Future<String?> currentIdToken({bool forceRefresh = false}) async {
    final auth = await _instance();
    return auth.currentUser?.getIdToken(forceRefresh);
  }

  /// CI/dev helper only: Auth Emulator accepts a synthetic Google ID token.
  Future<UserCredential> signInWithMockGoogleIdToken(String idToken) async {
    if (idToken.trim().isEmpty) {
      throw const FormatException('Mock Google ID token is empty');
    }
    final auth = await _instance();
    return auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }
}

BookingFirebaseIdTokenProvider bookingFirebaseTokenProviderFor({
  required BookingBackendEndpoint endpoint,
  required BookingAuthEmulatorConfig? emulator,
  bool releaseMode = kReleaseMode,
  BookingFirebaseAuthFactory? authFactory,
}) {
  if (releaseMode ||
      endpoint.binding != BookingBackendBinding.devEmulator ||
      emulator == null) {
    return const DisabledBookingFirebaseIdTokenProvider();
  }
  return FirebaseAuthIdTokenProvider(
    authFactory ?? () => _initializeAuthEmulator(emulator),
  );
}

Future<FirebaseAuth> _initializeAuthEmulator(
  BookingAuthEmulatorConfig config,
) async {
  const appName = 'recharge-booking-auth-emulator';
  FirebaseApp app;
  try {
    app = Firebase.app(appName);
  } on FirebaseException {
    app = await Firebase.initializeApp(
      name: appName,
      options: FirebaseOptions(
        apiKey: 'demo-recharge-emulator-only',
        appId: '1:1234567890:android:demo-recharge-emulator',
        messagingSenderId: '1234567890',
        projectId: config.projectId,
      ),
    );
  }
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(config.host, config.port, automaticHostMapping: false);
  return auth;
}
