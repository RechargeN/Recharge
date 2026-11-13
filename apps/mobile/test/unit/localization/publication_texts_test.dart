import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/presentation/widgets/publication_texts.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

void main() {
  const List<String> languages = <String>['en', 'lv', 'ru'];

  group('PublicationTexts.unavailable', () {
    for (final String language in languages) {
      test('$language: a missing failure code reads as the generic error', () {
        final AppLocalizations l10n = lookupAppLocalizations(Locale(language));

        final String text = PublicationTexts.unavailable(l10n, null);

        expect(text, l10n.publicationObjectUnavailable(l10n.errorGeneric));
        // A failed read is not an unconfirmed write: the "could not confirm
        // the result" text must not appear for a missing code.
        expect(text, isNot(contains(l10n.errorUnknownOutcome)));
      });

      test('$language: a known failure code keeps its own message', () {
        final AppLocalizations l10n = lookupAppLocalizations(Locale(language));

        expect(
          PublicationTexts.unavailable(l10n, 'not_found'),
          l10n.publicationObjectUnavailable(l10n.errorNotFound),
        );
      });

      test('$language: an unknown failure code reads as the generic error '
          'and is never shown', () {
        final AppLocalizations l10n = lookupAppLocalizations(Locale(language));

        final String text = PublicationTexts.unavailable(
          l10n,
          'future_server_code',
        );

        expect(text, l10n.publicationObjectUnavailable(l10n.errorGeneric));
        expect(text, isNot(contains('future_server_code')));
      });
    }
  });
}
