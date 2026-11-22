import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/app/presentation/event_booking_panel.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/application/state/auth_state.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:recharge/features/booking/application/event_booking_controller.dart';
import 'package:recharge/features/booking/domain/repositories/event_booking_gateway.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

class _Auth implements AuthRepository {
  @override
  Future<AuthUserEntity?> getCurrentUser() async => null;

  @override
  Future<AuthResultEntity?> restoreSession() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) => throw UnimplementedError();
}

class _Analytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FixedAuthController extends AuthController {
  _FixedAuthController(this._fixed)
    : super(
        signInUseCase: SignInUseCase(_Auth()),
        restoreSessionUseCase: RestoreSessionUseCase(_Auth()),
        signOutUseCase: SignOutUseCase(_Auth()),
        getCurrentUserUseCase: GetCurrentUserUseCase(_Auth()),
        analyticsService: _Analytics(),
      );

  final AuthState _fixed;

  @override
  AuthState get state => _fixed;
}

class _Gateway implements EventBookingGateway {
  @override
  Future<EventBookingResult> activeFor(String occurrenceId) async =>
      const EventBookingResult(EventBookingOutcome.succeeded);

  @override
  Future<EventBookingTermsResult> termsFor({
    required String eventId,
    required String occurrenceId,
    String? channel,
  }) async =>
      const EventBookingTermsResult(EventBookingTermsOutcome.unavailable);

  @override
  Future<EventBookingResult> execute(EventBookingOperation operation) =>
      throw StateError('no Booking command without a network');

  @override
  Future<EventBookingResult> booking(String bookingId) async =>
      const EventBookingResult(EventBookingOutcome.succeeded);
}

class _Store implements EventBookingOperationStore {
  @override
  Future<EventBookingOperation?> read(String occurrenceId) async => null;

  @override
  Future<void> write(EventBookingOperation operation) async {}

  @override
  Future<void> clear(String occurrenceId) async {}
}

Future<void> _pump(WidgetTester tester, {required bool noNetwork}) async {
  final auth = _FixedAuthController(
    AuthState(
      status: AuthStatus.authenticated,
      networkUnavailable: noNetwork,
      user: const AuthUserEntity(
        id: 'server-user',
        email: '',
        role: 'user',
        capabilities: <String>['booking.self_service'],
        profileStatus: 'active',
      ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[authControllerProvider.overrideWith((ref) => auth)],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: EventBookingPanel(
              eventTimeZoneId: 'Europe/Riga',
              createController: () async => EventBookingController(
                gateway: _Gateway(),
                store: _Store(),
                occurrenceId: 'occ-1',
                inventoryPoolId: 'pool',
                channel: 'onsite',
                eventRevision: 1,
                maxParticipantUnits: 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await sl.reset();
    // The panel reads the Auth state only with the Auth composition present.
    sl.registerSingleton<RestoreSessionUseCase>(RestoreSessionUseCase(_Auth()));
  });
  tearDown(() => sl.reset());

  testWidgets('no network inside a valid snapshot: Booking is disabled', (
    tester,
  ) async {
    await _pump(tester, noNetwork: true);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('event-booking-create')),
    );
    expect(button.onPressed, isNull);
    expect(find.byKey(const Key('event-booking-offline')), findsOneWidget);
  });

  testWidgets('with a network Booking stays enabled', (tester) async {
    await _pump(tester, noNetwork: false);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('event-booking-create')),
    );
    expect(button.onPressed, isNotNull);
    expect(find.byKey(const Key('event-booking-offline')), findsNothing);
  });
}
