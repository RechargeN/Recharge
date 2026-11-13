import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/l10n_context.dart';
import '../core/localization/locale_controller.dart';
import '../core/localization/locale_providers.dart';
import '../core/telemetry/analytics_service.dart';
import 'di/dev_push_registrar.dart';
import 'di/service_locator.dart';
import 'observers/app_lifecycle_observer.dart';
import 'router/app_router.dart';
import 'router/route_names.dart';

class RechargeApp extends ConsumerStatefulWidget {
  const RechargeApp({super.key});

  @override
  ConsumerState<RechargeApp> createState() => _RechargeAppState();
}

class _RechargeAppState extends ConsumerState<RechargeApp>
    with WidgetsBindingObserver {
  late final AppLifecycleObserver _lifecycleObserver;
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = AppLifecycleObserver(
      analyticsService: sl<AnalyticsService>(),
    );
    _lifecycleObserver.attach();
    WidgetsBinding.instance.addObserver(this);
    // N3c (dev flavor, N3C_DEV_PUSH only): a tap on a push opens the inbox.
    if (sl.isRegistered<DevPushRegistrar>()) {
      unawaited(
        sl<DevPushRegistrar>().attach(
          openInbox: _openInbox,
          foreground: _announcePush,
        ),
      );
    }
  }

  void _openInbox() => ref.read(appRouterProvider).go(RouteNames.notifications);

  /// Android does not show a push while the app is open; the inbox has it.
  void _announcePush() {
    final ScaffoldMessengerState? messenger = _messenger.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(messenger.context.l10n.notificationsPushArrived),
        action: SnackBarAction(
          label: messenger.context.l10n.notificationsPushOpen,
          onPressed: _openInbox,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleObserver.detach();
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    ref
        .read(localeControllerProvider)
        .updateDeviceLanguages(
          (locales ?? const <Locale>[])
              .map((Locale locale) => locale.toLanguageTag())
              .toList(growable: false),
        );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final LocaleController locale = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      theme: RechargeTheme.light(),
      routerConfig: router,
      scaffoldMessengerKey: _messenger,
      // L4: one resolved language from LocaleController; Flutter's own
      // resolution is not used, so the fallback stays deterministic.
      locale: Locale(locale.languageCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
