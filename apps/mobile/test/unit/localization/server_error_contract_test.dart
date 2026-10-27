import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/localization/app_locale_policy.dart';
import 'package:recharge/core/localization/user_message_catalog.dart';
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
}
