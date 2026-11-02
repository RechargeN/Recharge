import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/config/market_config.dart';
import 'package:recharge/core/localization/app_locale_policy.dart';
import 'package:recharge/core/localization/locale_controller.dart';
import 'package:recharge/core/localization/locale_preference_store.dart';
import 'package:recharge/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:recharge/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:recharge/features/auth/data/models/auth_result_model.dart';
import 'package:recharge/features/auth/data/models/auth_session_model.dart';
import 'package:recharge/features/auth/data/models/auth_user_model.dart';
import 'package:recharge/features/auth/data/repositories/auth_repository_impl.dart';

/// L4 check 3: deterministic resolution, persistence across restart, an
/// unsupported language, and logout/login with the same and another user.
void main() {
  final AppLocalePolicy policy = AppLocalePolicy(
    supportedLanguageCodes: AppLocalePolicy.r1LanguageCodes,
    fallbackLanguageCode: MarketConfig.riga.defaultLocaleCode,
  );

  group('AppLocalePolicy', () {
    test('explicit choice wins over the device list', () {
      expect(
        policy.resolve(
          choice: AppLocaleChoice.lv,
          deviceLanguageTags: <String>['ru-RU'],
        ),
        'lv',
      );
    });

    test('system follows the first supported device language by subtag', () {
      expect(
        policy.resolve(
          choice: AppLocaleChoice.system,
          deviceLanguageTags: <String>['et-EE', 'lv-LV', 'ru'],
        ),
        'lv',
      );
      expect(
        policy.resolve(
          choice: AppLocaleChoice.system,
          deviceLanguageTags: <String>['ru_RU'],
        ),
        'ru',
      );
      expect(
        policy.resolve(
          choice: AppLocaleChoice.system,
          deviceLanguageTags: <String>['en-GB'],
        ),
        'en',
      );
    });

    test('unsupported languages fall back to the market default, never to a '
        '"close" language', () {
      for (final List<String> tags in <List<String>>[
        <String>['et-EE'],
        <String>['lt-LT'],
        <String>['de-DE', 'uk-UA'],
        <String>[],
      ]) {
        expect(
          policy.resolve(
            choice: AppLocaleChoice.system,
            deviceLanguageTags: tags,
          ),
          'en',
          reason: '$tags',
        );
      }
    });

    test('the fallback must itself be supported', () {
      expect(
        () => AppLocalePolicy(
          supportedLanguageCodes: AppLocalePolicy.r1LanguageCodes,
          fallbackLanguageCode: 'et',
        ),
        throwsArgumentError,
      );
    });

    test('the API locale names Latvian lv-LV; others pass', () {
      expect(AppLocalePolicy.canonicalLocaleOf('lv'), 'lv-LV');
      expect(AppLocalePolicy.canonicalLocaleOf('en'), 'en');
      expect(AppLocalePolicy.canonicalLocaleOf('ru'), 'ru');
      expect(AppLocalePolicy.canonicalLocaleOf('et'), isNull);
    });
  });

  group('LocaleController', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

    LocaleController controller(
      LocalePreferenceStore store, {
      List<String> device = const <String>['de-DE'],
    }) => LocaleController(
      policy: policy,
      store: store,
      deviceLanguageTags: device,
    );

    test('switch, then restart restores the choice', () async {
      final SecureLocalePreferenceStore store = SecureLocalePreferenceStore(
        const FlutterSecureStorage(),
      );
      final LocaleController first = controller(store);
      await first.load();
      expect(first.languageCode, 'en');
      int notified = 0;
      first.addListener(() => notified += 1);
      await first.select(AppLocaleChoice.ru);
      expect(first.languageCode, 'ru');
      expect(first.apiLocale, 'ru');
      expect(notified, 1);

      final LocaleController restarted = controller(store);
      await restarted.load();
      expect(restarted.choice, AppLocaleChoice.ru);
      expect(restarted.languageCode, 'ru');

      await restarted.select(AppLocaleChoice.system);
      final LocaleController third = controller(
        store,
        device: <String>['lv-LV'],
      );
      await third.load();
      expect(third.choice, AppLocaleChoice.system);
      expect(third.languageCode, 'lv');
      expect(third.apiLocale, 'lv-LV');
    });

    test(
      'an unknown or future stored value is ignored, not rewritten',
      () async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{
          SecureLocalePreferenceStore.storageKey: 'et',
        });
        const FlutterSecureStorage storage = FlutterSecureStorage();
        final LocaleController c = controller(
          SecureLocalePreferenceStore(storage),
        );
        await c.load();
        expect(c.choice, AppLocaleChoice.system);
        expect(c.languageCode, 'en');
        expect(
          await storage.read(key: SecureLocalePreferenceStore.storageKey),
          'et',
        );
      },
    );

    test('a device language change re-resolves only under system', () async {
      final LocaleController c = controller(InMemoryLocalePreferenceStore());
      c.updateDeviceLanguages(<String>['ru-RU']);
      expect(c.languageCode, 'ru');
      await c.select(AppLocaleChoice.lv);
      c.updateDeviceLanguages(<String>['en-US']);
      expect(c.languageCode, 'lv');
    });

    test('the choice is device-scoped: logout and login of the same or '
        'another user keep it; sign-out cleanup never touches it', () async {
      const FlutterSecureStorage storage = FlutterSecureStorage();
      final AuthRepositoryImpl auth = AuthRepositoryImpl(
        remoteDataSource: _TwoUsersRemote(),
        localDataSource: const AuthLocalDataSource(storage),
      );
      final SecureLocalePreferenceStore store = SecureLocalePreferenceStore(
        storage,
      );
      Future<String> appStart() async {
        final LocaleController c = controller(store);
        await c.load();
        return c.languageCode;
      }

      Future<void> signIn(String email) => auth.signIn(
        email: email,
        password: 'password123',
        deviceName: 'test',
        platform: 'test',
        appVersion: '1.0.0',
      );

      await signIn('a@example.com');
      final LocaleController session = controller(store);
      await session.load();
      await session.select(AppLocaleChoice.lv);
      await auth.signOut();
      expect(await storage.read(key: 'auth.session'), isNull);
      expect(await appStart(), 'lv');

      await signIn('a@example.com');
      expect(await appStart(), 'lv');
      await auth.signOut();

      await signIn('b@example.com');
      expect(await appStart(), 'lv');
      final LocaleController other = controller(store);
      await other.load();
      await other.select(AppLocaleChoice.ru);
      await auth.signOut();

      await signIn('a@example.com');
      expect(await appStart(), 'ru');
    });
  });
}

final class _TwoUsersRemote implements AuthRemoteDataSource {
  int _sessions = 0;

  @override
  Future<AuthResultModel> login({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) async {
    _sessions += 1;
    final String userId = email.startsWith('a@') ? 'user-a' : 'user-b';
    return AuthResultModel(
      session: AuthSessionModel(
        accessToken: 'access-$_sessions',
        refreshToken: 'refresh-$_sessions',
        sessionId: 'session-$_sessions',
        expiresInSeconds: 3600,
      ),
      user: AuthUserModel(
        id: userId,
        email: email,
        role: 'user',
        capabilities: const <String>[],
        profileStatus: 'active',
      ),
    );
  }

  @override
  Future<void> logout({required String sessionId}) async {}

  @override
  Future<AuthSessionModel> refresh({
    required String refreshToken,
    required String sessionId,
  }) => throw UnimplementedError();

  @override
  Future<AuthUserModel> me({required String accessToken}) =>
      throw UnimplementedError();
}
