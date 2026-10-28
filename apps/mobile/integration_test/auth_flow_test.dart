import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recharge/app/app.dart';
import 'package:recharge/app/bootstrap.dart';
import 'package:recharge/app/di/content_server_path_composition.dart';
import 'package:recharge/app/di/service_locator.dart';
import 'package:recharge/core/localization/app_locale_policy.dart';
import 'package:recharge/core/localization/locale_controller.dart';
import 'package:recharge/core/localization/locale_preference_store.dart';
import 'package:recharge/core/localization/locale_providers.dart';
import 'package:recharge/core/product_analytics/product_analytics_recorder.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:recharge/features/auth/presentation/pages/sign_in_page.dart';
import 'package:recharge/features/create/application/content_server_path.dart';
import 'package:recharge/features/explore/presentation/pages/profile_page.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest -> auth gate -> sign in -> profile', (tester) async {
    await bootstrap();

    // The mock repository signs a fresh install in as the demo user on
    // restore; the guest start keeps restore empty, sign-in stays real.
    final AuthRepository repository = _GuestStartAuthRepository(
      sl<AuthRepository>(),
    );
    final AuthController auth = AuthController(
      signInUseCase: SignInUseCase(repository),
      restoreSessionUseCase: RestoreSessionUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      analyticsService: sl(),
      productAnalytics: sl.isRegistered<ProductAnalyticsRecorder>()
          ? sl<ProductAnalyticsRecorder>()
          : null,
    );
    // The UI language is fixed so the flow does not depend on the device.
    final LocaleController locale = LocaleController(
      policy: AppLocalePolicy(
        supportedLanguageCodes: AppLocalePolicy.r1LanguageCodes,
        fallbackLanguageCode: 'en',
      ),
      store: InMemoryLocalePreferenceStore(),
    );
    await locale.select(AppLocaleChoice.en);
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServerPathProvider.overrideWithValue(
            contentServerPathFromDi(),
          ),
          authControllerProvider.overrideWith((ref) => auth),
          localeControllerProvider.overrideWith((ref) => locale),
        ],
        child: const RechargeApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(auth.state.user, isNull);

    // Guest opens Profile from the bottom navigation: the router's auth
    // gate sends them to sign-in with Profile as the origin.
    await tester.tap(find.byKey(const ValueKey<String>('bottom-nav-profile')));
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);
    expect(find.text(l10n.authSignInHeadline), findsOneWidget);

    await tester.enterText(
      find.byKey(SignInPage.emailFieldKey),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(SignInPage.passwordFieldKey),
      'password123',
    );
    await tester.tap(find.byKey(SignInPage.submitButtonKey));
    await tester.pumpAndSettle();

    // Signed in, back at the origin: Profile, selected in the navigation.
    expect(auth.state.user, isNotNull);
    expect(find.byType(SignInPage), findsNothing);
    expect(find.byType(ProfilePage), findsOneWidget);
    final NavigationBar navigation = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigation.selectedIndex, 4);
  });
}

/// Delegates to the app repository but restores no session, so the app
/// starts as a guest instead of the mock demo account.
final class _GuestStartAuthRepository implements AuthRepository {
  _GuestStartAuthRepository(this._delegate);

  final AuthRepository _delegate;

  @override
  Future<AuthResultEntity?> restoreSession() async => null;

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) => _delegate.signIn(
    email: email,
    password: password,
    deviceName: deviceName,
    platform: platform,
    appVersion: appVersion,
  );

  @override
  Future<AuthUserEntity?> getCurrentUser() => _delegate.getCurrentUser();

  @override
  Future<void> signOut() => _delegate.signOut();
}
