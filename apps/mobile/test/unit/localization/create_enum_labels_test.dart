import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/localization/l10n_context.dart';
import 'package:recharge/features/create/domain/entities/event_availability_projection.dart';
import 'package:recharge/features/create/domain/entities/event_classification.dart';

/// L4.6: these values used to reach the screen as humanized wire names. Each
/// one must resolve to its own text, not to the select fallback.
void main() {
  for (final String language in const <String>['en', 'lv', 'ru']) {
    final AppLocalizations l10n = lookupAppLocalizations(Locale(language));

    test('$language: every Event archetype has its own label', () {
      final String fallback = l10n.createEventArchetype('other');
      for (final EventArchetype value in EventArchetype.values) {
        if (value == EventArchetype.other) continue;
        expect(
          l10n.createEventArchetype(value.wireName),
          isNot(fallback),
          reason: value.wireName,
        );
      }
    });

    test('$language: every participation mode has its own label', () {
      final String fallback = l10n.createEventParticipationMode('unknown');
      for (final ParticipationMode value in ParticipationMode.values) {
        expect(
          l10n.createEventParticipationMode('mode_${value.wireName}'),
          isNot(fallback),
          reason: value.wireName,
        );
      }
    });

    test('$language: every availability state has its own label', () {
      final String fallback = l10n.createEventAvailabilityState('unknown');
      for (final EventAvailabilityState value
          in EventAvailabilityState.values) {
        if (value == EventAvailabilityState.unknown) continue;
        expect(
          l10n.createEventAvailabilityState(value.name),
          isNot(fallback),
          reason: value.name,
        );
      }
    });
  }
}
