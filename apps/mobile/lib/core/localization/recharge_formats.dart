import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../shared/primitives/money/money.dart';

/// L4 locale-aware formatting. The language only changes how a value looks:
/// the currency always comes from the [Money] value (never from the language
/// or the market), and a domain instant is always shown in the IANA zone of
/// the object that owns it (an Event occurrence, a Place), never in the
/// device zone.
abstract final class RechargeFormats {
  static bool _zonesLoaded = false;

  /// The owning object's zone, or null when the id is unknown here.
  static tz.Location? _zone(String ianaZone) {
    if (!_zonesLoaded) {
      tz_data.initializeTimeZones();
      _zonesLoaded = true;
    }
    try {
      return tz.getLocation(ianaZone);
    } on tz.LocationNotFoundException {
      return null;
    }
  }

  /// [value] with its own currency, e.g. `€12.50` (en), `12,50 €` (lv, ru).
  static String money(Money value, String languageCode) {
    final NumberFormat format = NumberFormat.simpleCurrency(
      locale: languageCode,
      name: value.currencyCode,
      decimalDigits: 2,
    );
    // Money keeps integer hundredths; the division happens only for display.
    return format.format(value.minorUnits / 100);
  }

  /// An amount kept in [amountMinor] units of [minorUnitDigits] decimals
  /// (JPY 0, EUR 2, KWD 3) with its own currency.
  static String minorUnits(
    int amountMinor,
    String currencyCode,
    int minorUnitDigits,
    String languageCode,
  ) {
    final NumberFormat format = NumberFormat.simpleCurrency(
      locale: languageCode,
      name: currencyCode,
      decimalDigits: minorUnitDigits,
    );
    return format.format(amountMinor / math.pow(10, minorUnitDigits));
  }

  /// A plain number with up to [maxFractionDigits] decimals.
  static String decimal(
    num value,
    String languageCode, {
    int maxFractionDigits = 2,
  }) {
    final NumberFormat format = NumberFormat.decimalPattern(languageCode)
      ..maximumFractionDigits = maxFractionDigits;
    return format.format(value);
  }

  /// Date data for [languageCode]; the app's Material localization delegate
  /// loads it for lv/en/ru. Without it (a widget outside the app shell) the
  /// built-in en_US data is used, matching the English text fallback.
  static String _dateLocale(String languageCode) {
    try {
      if (DateFormat.localeExists(languageCode)) return languageCode;
    } on Exception {
      // intl throws while no date data is loaded at all; en_US is built in.
    }
    return 'en_US';
  }

  /// The wall-clock time of [instantUtc] in [ianaZone]. An unknown zone id
  /// is never replaced by the device zone: the instant stays in UTC and the
  /// formatted text says so.
  static DateTime inZone(DateTime instantUtc, String ianaZone) {
    final tz.Location? zone = _zone(ianaZone);
    return zone == null
        ? instantUtc.toUtc()
        : tz.TZDateTime.from(instantUtc.toUtc(), zone);
  }

  static String _zoned(DateFormat format, DateTime instantUtc, String zone) {
    final String text = format.format(inZone(instantUtc, zone));
    return _zone(zone) == null ? '$text UTC' : text;
  }

  /// Date and time of [instantUtc] in the owning object's [ianaZone].
  static String dateTime(
    DateTime instantUtc,
    String ianaZone,
    String languageCode,
  ) => _zoned(
    DateFormat.yMMMd(_dateLocale(languageCode)).add_jm(),
    instantUtc,
    ianaZone,
  );

  /// Date only, in the owning object's [ianaZone].
  static String date(
    DateTime instantUtc,
    String ianaZone,
    String languageCode,
  ) =>
      _zoned(DateFormat.yMMMd(_dateLocale(languageCode)), instantUtc, ianaZone);

  /// Time only, in the owning object's [ianaZone].
  static String time(
    DateTime instantUtc,
    String ianaZone,
    String languageCode,
  ) => _zoned(DateFormat.jm(_dateLocale(languageCode)), instantUtc, ianaZone);

  /// A moment that belongs to the reader (when a notification arrived), shown
  /// in the device zone because it is no object's local time.
  static String deviceDateTime(DateTime instantUtc, String languageCode) =>
      DateFormat.yMMMd(
        _dateLocale(languageCode),
      ).add_jm().format(instantUtc.toLocal());

  /// The short weekday name of ISO [isoWeekday] (1 = Monday … 7 = Sunday).
  /// A weekday is a calendar label, not an instant, so no zone applies.
  static String weekdayShort(int isoWeekday, String languageCode) =>
      DateFormat.E(
        _dateLocale(languageCode),
      ).format(DateTime.utc(2024, 1, isoWeekday.clamp(1, 7)));

  /// The full weekday name of ISO [isoWeekday] (1 = Monday … 7 = Sunday).
  static String weekdayLong(int isoWeekday, String languageCode) =>
      DateFormat.EEEE(
        _dateLocale(languageCode),
      ).format(DateTime.utc(2024, 1, isoWeekday.clamp(1, 7)));

  // A wall-clock value already resolved in the owning object's zone (for
  // example by Discover's TimezoneRepository) is formatted as is: no zone is
  // applied a second time.

  static String wallDate(DateTime wall, String languageCode) =>
      DateFormat.yMMMd(_dateLocale(languageCode)).format(wall);

  static String wallDateWithWeekday(DateTime wall, String languageCode) =>
      DateFormat.yMMMEd(_dateLocale(languageCode)).format(wall);

  static String wallDayWithWeekday(DateTime wall, String languageCode) =>
      DateFormat.MMMEd(_dateLocale(languageCode)).format(wall);

  static String wallMonthDay(DateTime wall, String languageCode) =>
      DateFormat.MMMd(_dateLocale(languageCode)).format(wall);

  static String wallTime(DateTime wall, String languageCode) =>
      DateFormat.jm(_dateLocale(languageCode)).format(wall);

  /// Time only, in the device zone (see [deviceDateTime]).
  static String deviceTime(DateTime instantUtc, String languageCode) =>
      DateFormat.jm(_dateLocale(languageCode)).format(instantUtc.toLocal());
}
