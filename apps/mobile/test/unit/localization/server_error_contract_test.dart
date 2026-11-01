import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/localization/app_locale_policy.dart';
import 'package:recharge/core/localization/user_message_catalog.dart';
import 'package:recharge/features/create/application/state/create_notice.dart';
import 'package:recharge/features/create/domain/entities/quick_plan_conversion.dart';
import 'package:recharge/features/create/presentation/widgets/create_texts.dart';
import 'package:recharge/features/create/presentation/widgets/route/route_issue_texts.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

/// L4 check 2: every typed code the R1 server contracts can return, and every
/// refusal code the client produces itself, has a localized disposition.
const String _schemas = '../../packages/api_contracts/schema';

/// The schema enum behind each server family (file, JSON pointer path).
const Map<UserMessageFamily, (String, List<String>)> _serverContracts =
    <UserMessageFamily, (String, List<String>)>{
      UserMessageFamily.booking: (
        'booking/v1/booking_error.schema.json',
        <String>['properties', 'code', 'enum'],
      ),
      UserMessageFamily.content: (
        'content/v1/content_result.schema.json',
        <String>[r'$defs', 'failureCode', 'enum'],
      ),
      UserMessageFamily.media: (
        'media/v1/media_result.schema.json',
        <String>[r'$defs', 'failureCode', 'enum'],
      ),
      UserMessageFamily.publisherEligibility: (
        'identity/v1/publisher_eligibility.schema.json',
        <String>['properties', 'reason', 'enum'],
      ),
      UserMessageFamily.platform: (
        'platform/v1/error.schema.json',
        <String>['properties', 'code', 'enum'],
      ),
      UserMessageFamily.notificationContent: (
        'notifications/v1/notifications_result.schema.json',
        <String>[r'$defs', 'item', 'properties', 'contentStatus', 'enum'],
      ),
      // L4.8: the module refusal contracts (L4-G09).
      UserMessageFamily.library: (
        'library/v1/library_refusal.schema.json',
        <String>[r'$defs', 'refusalCode', 'enum'],
      ),
      UserMessageFamily.quickPlan: (
        'quick_plan/v1/quick_plan_refusal.schema.json',
        <String>[r'$defs', 'refusalCode', 'enum'],
      ),
      UserMessageFamily.scenario: (
        'scenario/v1/scenario_refusal.schema.json',
        <String>[r'$defs', 'refusalCode', 'enum'],
      ),
      UserMessageFamily.route: (
        'route/v1/route_refusal.schema.json',
        <String>[r'$defs', 'refusalCode', 'enum'],
      ),
      UserMessageFamily.privacyIntake: (
        'privacy/v1/privacy_intake_refusal.schema.json',
        <String>[r'$defs', 'refusalCode', 'enum'],
      ),
      UserMessageFamily.identitySession: (
        'identity/v1/identity_session_result.schema.json',
        <String>[r'$defs', 'failureCode', 'enum'],
      ),
    };

List<String> _schemaCodes(String file, List<String> path) {
  Object? node = jsonDecode(File('$_schemas/$file').readAsStringSync());
  for (final String step in path) {
    node = (node! as Map<String, dynamic>)[step];
  }
  return (node! as List<dynamic>).cast<String>();
}

/// Codes of [family] that have no registered disposition.
List<String> unregistered(UserMessageFamily family, Iterable<String> codes) =>
    codes
        .where((String code) => !UserMessageCatalog.isRegistered(family, code))
        .toList();

void main() {
  final List<AppLocalizations> languages = AppLocalePolicy.r1LanguageCodes
      .map((String code) => lookupAppLocalizations(Locale(code)))
      .toList();

  for (final MapEntry<UserMessageFamily, (String, List<String>)> contract
      in _serverContracts.entries) {
    test('${contract.key.name}: every schema code is registered and every '
        'registered code is a schema code', () {
      final List<String> codes = _schemaCodes(
        contract.value.$1,
        contract.value.$2,
      );
      expect(codes, isNotEmpty);
      expect(unregistered(contract.key, codes), isEmpty);
      expect(
        UserMessageCatalog.codes(contract.key).difference(codes.toSet()),
        isEmpty,
        reason: 'the catalog must not invent server codes',
      );
    });
  }

  test('positive control: a new server code that is not registered is '
      'detected, and still shows the safe generic text', () {
    final List<String> codes = <String>[
      ..._schemaCodes('booking/v1/booking_error.schema.json', <String>[
        'properties',
        'code',
        'enum',
      ]),
      'waitlist_offer_expired',
    ];
    expect(unregistered(UserMessageFamily.booking, codes), <String>[
      'waitlist_offer_expired',
    ]);
    for (final AppLocalizations l10n in languages) {
      final String shown = UserMessageCatalog.booking(
        l10n,
        'waitlist_offer_expired',
      );
      expect(shown, l10n.bookingErrorGeneric);
      expect(shown.contains('waitlist_offer_expired'), isFalse);
      expect(
        UserMessageCatalog.message(
          l10n,
          UserMessageFamily.content,
          'brand_new_code',
        ),
        l10n.errorGeneric,
      );
    }
  });

  test('every refusal code the client raises itself is registered', () {
    final RegExp raised = RegExp(
      r"(?:_LocalRefusal|EventPublicationUnavailable)\(\s*'([a-z_]+)'",
    );
    final Set<String> codes = <String>{};
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final RegExpMatch match in raised.allMatches(
        entity.readAsStringSync(),
      )) {
        codes.add(match.group(1)!);
      }
    }
    expect(codes, isNotEmpty);
    final List<String> missing = codes
        .where(
          (String code) =>
              !UserMessageCatalog.isRegistered(
                UserMessageFamily.clientLocal,
                code,
              ) &&
              !UserMessageCatalog.isRegistered(UserMessageFamily.content, code),
        )
        .toList();
    expect(missing, isEmpty);
  });

  test('L4.8: every code a module sync client raises itself has a message', () {
    const Map<String, UserMessageFamily> clients = <String, UserMessageFamily>{
      'LibraryFailure': UserMessageFamily.library,
      'QuickPlanFailure': UserMessageFamily.quickPlan,
      'ScenarioSyncFailure': UserMessageFamily.scenario,
      'RouteSyncFailure': UserMessageFamily.route,
    };
    final RegExp raised = RegExp(
      "(${clients.keys.join('|')})\\(\\s*'([a-z_]+)'",
    );
    const String fallback = 'fallback';
    final List<String> silent = <String>[];
    int seen = 0;
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final RegExpMatch match in raised.allMatches(
        entity.readAsStringSync(),
      )) {
        seen += 1;
        final String shown = UserMessageCatalog.refusal(
          languages.first,
          clients[match.group(1)]!,
          match.group(2)!,
          fallback: fallback,
        );
        if (shown == fallback) silent.add(match.group(0)!);
      }
    }
    expect(seen, isNonZero);
    expect(silent, isEmpty);
  });

  test('L4.8: a refusal resolves through its family, a Session code, the '
      'client and the transport; both spellings are one code', () {
    const String fallback = 'fallback';
    for (final AppLocalizations l10n in languages) {
      String say(UserMessageFamily family, String code) =>
          UserMessageCatalog.refusal(l10n, family, code, fallback: fallback);
      expect(
        say(UserMessageFamily.library, 'visit_date_future'),
        l10n.libraryErrorVisitFuture,
      );
      expect(
        say(UserMessageFamily.library, 'session-expired'),
        say(UserMessageFamily.library, 'session_expired'),
      );
      expect(
        say(UserMessageFamily.library, 'session_expired'),
        l10n.errorSessionExpired,
      );
      expect(
        say(UserMessageFamily.route, 'journal_capacity_exceeded'),
        l10n.localErrorStorageFull,
      );
      expect(
        say(UserMessageFamily.quickPlan, 'unavailable'),
        l10n.errorOffline,
      );
      // Positive control: an unknown code gives the screen's own text.
      expect(say(UserMessageFamily.scenario, 'brand_new_code'), fallback);
      expect(
        UserMessageCatalog.forError(l10n, StateError('x'), fallback: fallback),
        fallback,
      );
      // Route publication reaches the new family and the recorded-GPS texts.
      expect(
        UserMessageCatalog.publication(l10n, 'privacy_trim_required'),
        l10n.routeTrimRequired,
      );
      expect(
        UserMessageCatalog.publication(l10n, 'license_blocked'),
        l10n.routeErrorLicense,
      );
    }
  });

  test('L4.8: "gone" and "not yours" read the same, so a message never '
      'reveals that somebody else\'s object exists', () {
    for (final AppLocalizations l10n in languages) {
      final Set<String?> texts = <String?>{
        UserMessageCatalog.message(
          l10n,
          UserMessageFamily.scenario,
          'not_found',
        ),
        UserMessageCatalog.message(
          l10n,
          UserMessageFamily.scenario,
          'not_found_or_forbidden',
        ),
        UserMessageCatalog.message(
          l10n,
          UserMessageFamily.scenario,
          'recipient_unavailable',
        ),
        UserMessageCatalog.message(
          l10n,
          UserMessageFamily.quickPlan,
          'access_denied',
        ),
        UserMessageCatalog.message(
          l10n,
          UserMessageFamily.quickPlan,
          'target_unavailable',
        ),
        UserMessageCatalog.message(
          l10n,
          UserMessageFamily.identitySession,
          'not_found_or_not_accessible',
        ),
      };
      expect(texts, <String?>{l10n.errorNotFound});
    }
  });

  test('every disposition is real text in lv, en and ru, never the code', () {
    for (final UserMessageFamily family in UserMessageFamily.values) {
      for (final String code in UserMessageCatalog.codes(family)) {
        for (final AppLocalizations l10n in languages) {
          final String? text = UserMessageCatalog.message(l10n, family, code);
          if (text == null) continue; // a non-error code (eligible, rendered)
          expect(text.trim(), isNotEmpty, reason: '${family.name}:$code');
          // The code itself is never the text (single words such as
          // `unavailable` may still occur in ordinary English prose).
          expect(text, isNot(code), reason: '${family.name}:$code');
          expect(
            text.contains(RegExp(r'[a-z]+_[a-z_]+')),
            isFalse,
            reason: 'snake_case leaked for ${family.name}:$code',
          );
        }
      }
    }
  });

  test('publication messages resolve through every family and prefixes', () {
    final AppLocalizations lv = lookupAppLocalizations(const Locale('lv'));
    expect(
      UserMessageCatalog.publication(lv, 'media_not_ready'),
      lv.contentErrorMediaNotReady,
    );
    expect(
      UserMessageCatalog.publication(lv, 'save_required'),
      lv.localErrorSaveRequired,
    );
    expect(UserMessageCatalog.publication(lv, 'unavailable'), lv.errorOffline);
    expect(
      UserMessageCatalog.publication(lv, 'cleanup_recoveryPeriod'),
      lv.importErrorChanged,
    );
    expect(
      UserMessageCatalog.publication(lv, 'unsupported_capability:x'),
      lv.errorFeatureDisabled,
    );
    expect(UserMessageCatalog.publication(lv, 'zzz'), lv.errorGeneric);
  });

  test('every local Place check code and section has its own text in '
      'lv, en and ru (L4)', () {
    final String source = File(
      'lib/features/create/domain/usecases/validate_place_draft_usecase.dart',
    ).readAsStringSync();
    final Iterable<RegExpMatch> raised = RegExp(
      r"(?:error|warning)\(\s*'([a-z_]+)',\s*'([a-z_]+)'",
    ).allMatches(source);
    final Set<String> codes = {for (final m in raised) m.group(1)!};
    final Set<String> sections = {for (final m in raised) m.group(2)!};
    expect(codes.length, greaterThan(40));
    for (final AppLocalizations l10n in languages) {
      final String otherCode = l10n.placeValidationIssue('not_a_code');
      final String otherSection = l10n.placeValidationSection('not_a_section');
      expect(
        codes.where((String c) => l10n.placeValidationIssue(c) == otherCode),
        isEmpty,
        reason: l10n.localeName,
      );
      expect(
        sections.where(
          (String c) => l10n.placeValidationSection(c) == otherSection,
        ),
        isEmpty,
        reason: l10n.localeName,
      );
      // Positive control: an unknown code reads as the safe fallback.
      expect(otherCode.contains('not_a_code'), isFalse);
    }
  });

  test('every Session and Route check code and Route section a validator '
      'raises reads as a real message in lv, en and ru (L4)', () {
    final Set<String> session = <String>{
      for (final RegExpMatch m
          in RegExp(
            r"static const String \w+ =\s*'(session_[a-z_]+)'",
          ).allMatches(
            File(
              'lib/features/create/domain/entities/session_validation_issue.dart',
            ).readAsStringSync(),
          ))
        m.group(1)!,
    };
    final Iterable<RegExpMatch>
    route = RegExp(r"(?:block|warn)\(\s*'([a-z_0-9]+)',\s*'([a-z_]+)'").allMatches(
      File(
        'lib/features/create/domain/usecases/validate_route_draft_usecase.dart',
      ).readAsStringSync(),
    );
    expect(session.length, greaterThan(20));
    expect(route.length, greaterThan(80));
    for (final AppLocalizations l10n in languages) {
      final String sessionOther = l10n.sessionValidationIssue('x');
      final String routeOther = l10n.routeValidationIssue('x');
      final String sectionOther = l10n.routeValidationSection('x');
      expect(
        session.where(
          (String c) => l10n.sessionValidationIssue(c) == sessionOther,
        ),
        isEmpty,
      );
      for (final RegExpMatch m in route) {
        final String text = routeIssueLine(l10n, m.group(1)!, m.group(2)!);
        expect(text.contains(m.group(1)!), isFalse);
        expect(
          l10n.routeValidationIssue(routeIssueMessageKey(m.group(1)!)),
          isNot(routeOther),
          reason: m.group(1),
        );
        expect(
          l10n.routeValidationSection(m.group(2)!),
          isNot(
            sectionOther == l10n.routeValidationSection('route')
                ? ''
                : sectionOther,
          ),
        );
      }
    }
  });

  test('every Create validator, controller and form code reads as its own '
      'message in lv, en and ru, never as the code (L4.2)', () {
    String src(String path) =>
        File('lib/features/create/$path').readAsStringSync();
    Set<String> scan(String pattern, String source) => <String>{
      for (final RegExpMatch m in RegExp(pattern).allMatches(source))
        m.group(1)!,
    };
    const String usecases = 'domain/usecases';
    final String controller = src(
      'application/controllers/create_controller.dart',
    );
    final String findPeople = src(
      '$usecases/validate_find_people_draft_usecase.dart',
    );
    final String activity = src(
      '$usecases/validate_activity_draft_usecase.dart',
    );
    // Field id → codes: every family the field-error resolver knows.
    final Map<String, Set<String>> families = <String, Set<String>>{
      'scenario.validation.': <String>{
        ...scan(
          r"code:\s*'([a-z_]+)'",
          src('$usecases/validate_scenario_draft_usecase.dart'),
        ),
        ...scan(
          r"duplicateCode:\s*'([a-z_]+)'",
          src('$usecases/validate_scenario_draft_usecase.dart'),
        ),
        ...scan(r"'scenario\.validation\.([a-z_]+)'", controller),
      },
      'find_people.validation.': <String>{
        ...scan(r"error\(\s*'([a-z_]+)'", findPeople),
        for (final String field in scan(r"field: '(\w+)'", findPeople))
          '${field}_length',
        for (final String field in scan(
          r"_max\(\s*[\w.?]+,\s*\d+,\s*'\w+',\s*'(\w+)'",
          findPeople,
        ))
          '${field}_length',
      },
      'event.validation.': <String>{
        ...scan(
          r"blocking\(\s*\d+,\s*'([a-z_0-9]+)'",
          src('$usecases/validate_event_draft_usecase.dart'),
        ),
        ...scan(
          r"code:\s*'([a-z_]+)'",
          src('$usecases/validate_event_draft_usecase.dart'),
        ),
        ...scan(
          r"add\(\s*'([a-z_]+)'",
          src('$usecases/validate_event_access_configuration_usecase.dart'),
        ),
        ...scan(
          r"code:\s*'([a-z_]+)'",
          src('$usecases/validate_event_classification_usecase.dart'),
        ),
      },
      'event.admission_preset.': scan(
        r"required\('(\w+)'\)",
        src('$usecases/normalize_event_admission_preset_usecase.dart'),
      ),
      'collection.validation.': scan(
        r"(?:error|warning)\(\s*'([a-z_]+)'",
        src('$usecases/validate_collection_draft_usecase.dart'),
      ),
      'class_workshop.validation.': scan(
        r"need\(\s*[^,]+,\s*'([a-z_]+)'",
        src('$usecases/validate_class_workshop_draft_usecase.dart'),
      ),
      'availability.validation.': scan(
        r"'availability\.validation\.([a-z_]+)'",
        src('$usecases/validate_create_availability_usecase.dart'),
      ),
      'activity.validation.': <String>{
        ...scan(r"(?:error|warning)\(\s*'([a-z_]+)'", activity),
        ...scan(r"'activity\.validation\.([a-z_]+)'", activity),
        ...scan(r"'activity\.validation\.([a-z_]+)'", controller),
      },
      'rental.validation.': <String>{
        ...scan(
          r"'rental\.validation\.([a-z_]+)'",
          src('$usecases/validate_rental_draft_usecase.dart'),
        ),
        ...scan(r"'rental\.validation\.([a-z_]+)'", controller),
      },
      'create.validation.': scan(
        r"'create\.validation\.([a-z_]+)'",
        controller,
      ),
    };
    final Map<String, int> minimum = <String, int>{
      'scenario.validation.': 70,
      'find_people.validation.': 55,
      'event.validation.': 85,
      'event.admission_preset.': 3,
      'collection.validation.': 10,
      'class_workshop.validation.': 18,
      'availability.validation.': 10,
      'activity.validation.': 20,
      'rental.validation.': 35,
      'create.validation.': 4,
    };
    for (final MapEntry<String, int> m in minimum.entries) {
      expect(
        families[m.key]!.length,
        greaterThanOrEqualTo(m.value),
        reason: m.key,
      );
    }
    for (final AppLocalizations l10n in languages) {
      for (final MapEntry<String, Set<String>> family in families.entries) {
        final String other = CreateTexts.fieldError(
          l10n,
          '${family.key}not_a_code',
        );
        for (final String code in family.value) {
          final String text = CreateTexts.fieldError(
            l10n,
            '${family.key}$code',
          );
          expect(
            text,
            isNot(other),
            reason: '${l10n.localeName} ${family.key}$code',
          );
          // A snake_case code never leaks; plain words (title) may.
          if (code.contains('_')) {
            expect(text.contains(code), isFalse, reason: code);
          }
        }
      }
      final String noticeOther = l10n.createNotice('not_a_code');
      for (final String code in CreateNotice.all) {
        final String text = CreateTexts.notice(l10n, code);
        expect(text, isNot(noticeOther), reason: '${l10n.localeName} $code');
        expect(text.contains(code), isFalse);
      }
      final String quickOther = l10n.quickPlanConversionIssue('not_a_code');
      for (final QuickPlanConversionIssueCode code
          in QuickPlanConversionIssueCode.values) {
        expect(l10n.quickPlanConversionIssue(code.name), isNot(quickOther));
      }
      for (final String warning in const <String>[
        'plannedNotLive',
        'limitations',
      ]) {
        expect(l10n.scenarioTransitWarning(warning).contains(warning), isFalse);
      }
      // Positive control: an unknown id or code is a safe general text.
      for (final String unknown in const <String>[
        'event.validation.future_code',
        'totally.unknown.id',
        'session_future_code',
        'place.validation.future_code',
      ]) {
        final String text = CreateTexts.fieldError(l10n, unknown);
        expect(text.contains('future_code'), isFalse);
        expect(text.contains('totally'), isFalse);
      }
      expect(CreateTexts.notice(l10n, 'future_notice'), noticeOther);
    }
  });

  test('Create domain validators and the controller keep no sentence in an '
      'issue or notice (L4.2)', () {
    final Directory usecases = Directory('lib/features/create/domain/usecases');
    final List<String> offenders = <String>[
      for (final File file in usecases.listSync().whereType<File>())
        if (RegExp(r"\bmessage:\s*'").hasMatch(file.readAsStringSync()))
          file.path,
      if (RegExp(r"message:\s*'").hasMatch(
        File(
          'lib/features/create/application/controllers/create_controller.dart',
        ).readAsStringSync(),
      ))
        'create_controller.dart',
    ];
    expect(offenders, isEmpty);
    // Positive control: the scan sees a sentence when there is one.
    expect(
      RegExp(r"\bmessage:\s*'").hasMatch("x(message: 'Add a title')"),
      isTrue,
    );
  });
}
