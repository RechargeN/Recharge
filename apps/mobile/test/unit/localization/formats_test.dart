import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:recharge/core/localization/recharge_formats.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';
import 'package:recharge/shared/primitives/money/money.dart';

/// L4 check 5: money, decimals, dates, midnight, DST and plural forms.
/// Separators are matched loosely (intl uses NBSP / narrow NBSP), the values
/// strictly.
void main() {
  setUpAll(() => initializeDateFormatting());

  String plain(String value) => value.replaceAll(' ', ' ').replaceAll(' ', ' ');

  group('money keeps its own currency in every language', () {
    const Money price = Money(minorUnits: 125050, currencyCode: 'EUR');

    test('EUR', () {
      expect(plain(RechargeFormats.money(price, 'en')), '€1,250.50');
      expect(plain(RechargeFormats.money(price, 'lv')), '1 250,50 €');
      expect(plain(RechargeFormats.money(price, 'ru')), '1 250,50 €');
      expect(
        plain(
          RechargeFormats.money(
            const Money(minorUnits: 5, currencyCode: 'EUR'),
            'lv',
          ),
        ),
        '0,05 €',
      );
    });

    test('the language never changes the currency', () {
      const Money usd = Money(minorUnits: 999, currencyCode: 'USD');
      for (final String code in <String>['en', 'lv', 'ru']) {
        expect(RechargeFormats.money(usd, code), contains(r'$'));
        expect(RechargeFormats.money(usd, code), isNot(contains('€')));
      }
    });
  });

  test('fractional numbers use the language separators', () {
    expect(plain(RechargeFormats.decimal(1234.5, 'en')), '1,234.5');
    expect(plain(RechargeFormats.decimal(1234.5, 'lv')), '1 234,5');
    expect(plain(RechargeFormats.decimal(1234.5, 'ru')), '1 234,5');
    expect(RechargeFormats.decimal(0.125, 'en', maxFractionDigits: 2), '0.13');
    expect(RechargeFormats.decimal(200, 'ru'), '200');
  });

  group(
    'instants are shown in the owning object zone, whatever the language',
    () {
      // 21:00Z on 30 Aug is 00:00 on 31 Aug in Riga (EEST, UTC+3).
      final DateTime midnight = DateTime.utc(2026, 8, 30, 21);

      test('midnight moves to the next local day in Riga, not in UTC', () {
        expect(
          RechargeFormats.date(midnight, 'Europe/Riga', 'en'),
          'Aug 31, 2026',
        );
        expect(
          plain(RechargeFormats.time(midnight, 'Europe/Riga', 'en')),
          '12:00 AM',
        );
        expect(RechargeFormats.time(midnight, 'Europe/Riga', 'lv'), '00:00');
        expect(RechargeFormats.time(midnight, 'Europe/Riga', 'ru'), '00:00');
        expect(
          RechargeFormats.date(midnight, 'Europe/Riga', 'ru'),
          contains('31'),
        );
        expect(
          RechargeFormats.date(midnight, 'Europe/Riga', 'lv'),
          contains('31'),
        );
        // The same instant in UTC would still be 30 August.
        expect(RechargeFormats.date(midnight, 'UTC', 'en'), 'Aug 30, 2026');
      });

      test(
        'DST fall-back: both 03:30 wall clocks on 25 Oct stay distinct instants',
        () {
          final DateTime summer = DateTime.utc(2026, 10, 25, 0, 30);
          final DateTime winter = DateTime.utc(2026, 10, 25, 1, 30);
          for (final String code in <String>['lv', 'ru']) {
            expect(RechargeFormats.time(summer, 'Europe/Riga', code), '03:30');
            expect(RechargeFormats.time(winter, 'Europe/Riga', code), '03:30');
          }
          expect(
            RechargeFormats.inZone(summer, 'Europe/Riga').timeZoneOffset,
            const Duration(hours: 3),
          );
          expect(
            RechargeFormats.inZone(winter, 'Europe/Riga').timeZoneOffset,
            const Duration(hours: 2),
          );
        },
      );

      test('DST spring-forward: 03:00 local does not exist on 29 Mar', () {
        // 00:59Z is 02:59 EET; one minute later it is 04:00 EEST.
        expect(
          RechargeFormats.time(
            DateTime.utc(2026, 3, 29, 0, 59),
            'Europe/Riga',
            'ru',
          ),
          '02:59',
        );
        expect(
          RechargeFormats.time(
            DateTime.utc(2026, 3, 29, 1),
            'Europe/Riga',
            'ru',
          ),
          '04:00',
        );
      });

      test(
        'an unknown zone id stays UTC and says so, never the device zone',
        () {
          final DateTime instant = DateTime.utc(2026, 8, 30, 15, 30);
          expect(
            RechargeFormats.time(instant, 'Mars/Olympus', 'ru'),
            '15:30 UTC',
          );
          expect(RechargeFormats.inZone(instant, 'Mars/Olympus'), instant);
        },
      );

      test('a language switch changes only the text of one instant', () {
        final DateTime deadline = DateTime.utc(2026, 8, 30, 15, 30);
        final List<String> shown = <String>[
          for (final String code in <String>['en', 'lv', 'ru'])
            plain(RechargeFormats.dateTime(deadline, 'Europe/Riga', code)),
        ];
        expect(shown[0], contains('6:30 PM'));
        expect(shown[1], contains('18:30'));
        expect(shown[2], contains('18:30'));
        expect(deadline, DateTime.utc(2026, 8, 30, 15, 30));
      });
    },
  );

  group('plural forms follow CLDR for each language', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations lv = lookupAppLocalizations(const Locale('lv'));
    final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));

    test('en', () {
      expect(en.bookingSeatsCount(1), '1 seat');
      expect(en.bookingSeatsCount(2), '2 seats');
      expect(en.bookingSeatsCount(0), '0 seats');
    });

    test('lv: zero (0, 10–20, 30…), one (1, 21, 31… not 11), other', () {
      expect(lv.bookingSeatsCount(1), '1 vieta');
      expect(lv.bookingSeatsCount(21), '21 vieta');
      expect(lv.bookingSeatsCount(11), '11 vietas');
      expect(lv.bookingSeatsCount(0), '0 vietas');
      expect(lv.bookingSeatsCount(2), '2 vietas');
      expect(lv.bookingBookSeats(1), 'Rezervēt 1 vietu');
      expect(lv.bookingBookSeats(3), 'Rezervēt 3 vietas');
      expect(lv.errorRateLimitedSeconds(1), contains('1 sekundes'));
      expect(lv.errorRateLimitedSeconds(30), contains('30 sekundēm'));
    });

    test('ru: one (1, 21), few (2–4, 22), many (5–20, 25, 11), other', () {
      expect(ru.bookingSeatsCount(1), '1 место');
      expect(ru.bookingSeatsCount(21), '21 место');
      expect(ru.bookingSeatsCount(2), '2 места');
      expect(ru.bookingSeatsCount(22), '22 места');
      expect(ru.bookingSeatsCount(5), '5 мест');
      expect(ru.bookingSeatsCount(11), '11 мест');
      expect(ru.bookingSeatsCount(25), '25 мест');
      expect(ru.errorRateLimitedSeconds(1), contains('1 секунду'));
      expect(ru.errorRateLimitedSeconds(3), contains('3 секунды'));
      expect(ru.errorRateLimitedSeconds(30), contains('30 секунд'));
    });
  });
}
