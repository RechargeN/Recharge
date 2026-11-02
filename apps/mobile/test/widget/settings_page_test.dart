import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recharge/app/router/route_names.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/core/localization/app_locale_policy.dart';
import 'package:recharge/core/localization/locale_controller.dart';
import 'package:recharge/core/localization/locale_preference_store.dart';
import 'package:recharge/core/localization/locale_providers.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/auth/application/auth_providers.dart';
import 'package:recharge/features/auth/application/controllers/auth_controller.dart';
import 'package:recharge/features/auth/domain/entities/auth_result_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_session_entity.dart';
import 'package:recharge/features/auth/domain/entities/auth_user_entity.dart';
import 'package:recharge/features/auth/domain/repositories/auth_repository.dart';
import 'package:recharge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:recharge/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:recharge/features/explore/application/controllers/explore_controller.dart';
import 'package:recharge/features/explore/application/explore_providers.dart';
import 'package:recharge/features/explore/domain/entities/profile_editable_entity.dart';
import 'package:recharge/features/explore/domain/entities/settings_entity.dart';
import 'package:recharge/features/explore/domain/repositories/explore_repository.dart';
import 'package:recharge/features/explore/domain/usecases/load_profile_editable_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/load_settings_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/save_profile_editable_usecase.dart';
import 'package:recharge/features/explore/domain/usecases/save_settings_usecase.dart';
import 'package:recharge/features/explore/presentation/pages/settings_page.dart';
import '../support/l10n/l10n_screenshot.dart';

void main() {
  testWidgets('renders settings controls for authenticated user', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    final authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'user@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );

    final exploreRepository = _FakeExploreRepository();
    final exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    await exploreController.ensureLoaded(
      userId: 'u',
      email: 'user@example.com',
      role: 'user',
      favoritesCount: 0,
    );

    final router = GoRouter(
      initialLocation: RouteNames.settings,
      routes: [
        GoRoute(
          path: RouteNames.settings,
          builder: (_, _) => const SettingsPage(),
        ),
        GoRoute(
          path: RouteNames.discover,
          builder: (_, _) => const Scaffold(body: Text('Logged out home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT AND WORKSPACE'), findsOneWidget);
    expect(find.text('Switch workspace'), findsOneWidget);
    expect(
      find.text('Personal profile, Professional Pages and Admin access'),
      findsOneWidget,
    );
    expect(find.text('Profile information'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Avatar URL/Path'), findsOneWidget);
    const longName =
        'Очень длинное имя пользователя для проверки доступности действий';
    await tester.enterText(find.byType(TextField).first, longName);
    await tester.scrollUntilVisible(
      find.text('Save profile'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(exploreRepository.profiles['u']?.displayName, longName);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('CONTENT & ACTIVITY'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('CONTENT & ACTIVITY'), findsOneWidget);
    expect(find.text('Saved plans'), findsOneWidget);
    expect(find.text('Search and conditions'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Notifications'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Inbox and route updates'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Notification preferences'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    // L4.9.4: the currency that did nothing is gone; currency comes from data.
    expect(find.text('Currency'), findsNothing);
    expect(find.text('USD'), findsNothing);
    expect(find.text('Notification preferences'), findsOneWidget);
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(exploreRepository.settings['u']?.notificationsEnabled, isFalse);

    await tester.scrollUntilVisible(
      find.text('Support / Help'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Support / Help'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(authController.state.isAuthenticated, isFalse);
    expect(find.text('Logged out home'), findsOneWidget);
    expect(
      (await exploreRepository.loadProfileEditable('u'))?.displayName,
      longName,
    );
    expect(
      (await exploreRepository.loadSettings('u'))?.notificationsEnabled,
      isFalse,
    );
    expect(await exploreRepository.loadProfileEditable('another-user'), isNull);
  });

  testWidgets('L4: switching the language changes only text; the choice '
      'persists and market, currency and account settings stay', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    final authController = AuthController(
      signInUseCase: SignInUseCase(_NoopAuthRepository()),
      restoreSessionUseCase: RestoreSessionUseCase(_NoopAuthRepository()),
      signOutUseCase: SignOutUseCase(_NoopAuthRepository()),
      getCurrentUserUseCase: GetCurrentUserUseCase(_NoopAuthRepository()),
      analyticsService: _NoopAnalyticsService(),
    );
    await authController.signIn(
      email: 'user@example.com',
      password: 'password123',
      sourceScreen: 'test',
      sourceAction: 'seed',
    );
    final exploreRepository = _FakeExploreRepository();
    final exploreController = ExploreController(
      loadProfileEditableUseCase: LoadProfileEditableUseCase(exploreRepository),
      saveProfileEditableUseCase: SaveProfileEditableUseCase(exploreRepository),
      loadSettingsUseCase: LoadSettingsUseCase(exploreRepository),
      saveSettingsUseCase: SaveSettingsUseCase(exploreRepository),
      analyticsService: _NoopAnalyticsService(),
    );
    await exploreController.ensureLoaded(
      userId: 'u',
      email: 'user@example.com',
      role: 'user',
      favoritesCount: 0,
    );
    final SettingsEntity settingsBefore = exploreController.state.settings;
    final InMemoryLocalePreferenceStore store = InMemoryLocalePreferenceStore();
    final LocaleController locale = LocaleController(
      policy: AppLocalePolicy(
        supportedLanguageCodes: AppLocalePolicy.r1LanguageCodes,
        fallbackLanguageCode: MarketConfig.riga.defaultLocaleCode,
      ),
      store: store,
      deviceLanguageTags: const <String>['de-DE'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith((ref) => authController),
          exploreControllerProvider.overrideWith((ref) => exploreController),
          localeControllerProvider.overrideWith((ref) => locale),
        ],
        // The same root wiring as RechargeApp: one resolved language.
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: Locale(ref.watch(localeControllerProvider).languageCode),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<Object>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    for (final (String option, String title, String code)
        in <(String, String, String)>[
          ('Latviešu', 'Iestatījumi', 'lv'),
          ('Русский', 'Настройки', 'ru'),
          ('English', 'Settings', 'en'),
        ]) {
      final Finder selector = find.byKey(const Key('settings-language'));
      await tester.scrollUntilVisible(
        selector,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(locale.languageCode, code);
      expect(await store.read(), AppLocaleChoice.values.byName(code));
      expect(tester.takeException(), isNull);
      await l10nCaptureScreen(tester, suffix: code);
      // Text only: account settings and the market are untouched by the
      // language, and the choice stays on the device.
      expect(
        exploreController.state.settings.notificationsEnabled,
        settingsBefore.notificationsEnabled,
      );
      expect(exploreRepository.settings['u'], isNull);
      expect(MarketConfig.riga.currencyCode, 'EUR');
      expect(MarketConfig.riga.timezoneId, 'Europe/Riga');
      expect(MarketConfig.riga.countryCode, 'LV');
    }
  });
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _NoopAuthRepository implements AuthRepository {
  @override
  Future<AuthUserEntity?> getCurrentUser() async => null;

  @override
  Future<AuthResultEntity?> restoreSession() async => null;

  @override
  Future<AuthResultEntity> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    return AuthResultEntity(
      session: AuthSessionEntity(
        accessToken: 'acc',
        refreshToken: 'ref',
        sessionId: 'sess',
        expiresAtUtc: DateTime.now().toUtc(),
      ),
      user: const AuthUserEntity(
        id: 'u',
        email: 'user@example.com',
        role: 'user',
        capabilities: <String>['profile.read', 'profile.update'],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> signOut() async {}
}

class _FakeExploreRepository implements ExploreRepository {
  final profiles = <String, ProfileEditableEntity>{};
  final settings = <String, SettingsEntity>{};
  @override
  Future<ProfileEditableEntity?> loadProfileEditable(String userId) async =>
      profiles[userId];

  @override
  Future<SettingsEntity?> loadSettings(String userId) async => settings[userId];

  @override
  Future<void> saveProfileEditable(
    String userId,
    ProfileEditableEntity profile,
  ) async {
    profiles[userId] = profile;
  }

  @override
  Future<void> saveSettings(String userId, SettingsEntity settings) async {
    this.settings[userId] = settings;
  }
}
