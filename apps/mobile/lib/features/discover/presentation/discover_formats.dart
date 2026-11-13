import 'package:intl/intl.dart';

import '../../../core/localization/l10n_context.dart';
import '../../../core/localization/recharge_formats.dart';
import '../../../shared/primitives/money/money.dart';
import '../application/state/discover_feed_state.dart';
import '../domain/entities/activity_catalog_facts.dart';
import '../domain/entities/discover_query.dart';
import '../domain/repositories/timezone_repository.dart';

/// L4.5: Discover display helpers. Numbers and money follow the reader's
/// language; a date or time stays in the object's own zone (it arrives as a
/// wall-clock value already resolved by [TimezoneRepository]).

/// A number with exactly one decimal, e.g. `2.5` (en), `2,5` (lv, ru).
String discoverOneDecimal(AppLocalizations l10n, num value) =>
    NumberFormat.decimalPatternDigits(
      locale: l10n.localeName,
      decimalDigits: 1,
    ).format(value);

String discoverKm(AppLocalizations l10n, num km) =>
    l10n.discoverDistanceKm(discoverOneDecimal(l10n, km));

String discoverMetersText(AppLocalizations l10n, num meters) =>
    l10n.discoverMeters(
      NumberFormat.decimalPattern(l10n.localeName).format(meters.round()),
    );

/// [amount] in major units with its own [currencyCode].
String discoverMoney(
  AppLocalizations l10n,
  double amount,
  String currencyCode,
) => RechargeFormats.money(
  Money(minorUnits: (amount * 100).round(), currencyCode: currencyCode),
  l10n.localeName,
);

/// `45 min`, `2 h`, `2 h 30 min`; no duration is "flexible".
String discoverDuration(AppLocalizations l10n, int? minutes) {
  if (minutes == null) return l10n.discoverFlexible;
  if (minutes < 60) return l10n.discoverMinutes(minutes);
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return rest == 0
      ? l10n.discoverHours('$hours')
      : l10n.discoverHoursMinutes(hours, rest);
}

DateTime _wall(LocalDateTimeValue value) => DateTime.utc(
  value.date.year,
  value.date.month,
  value.date.day,
  value.minutesSinceMidnight ~/ 60,
  value.minutesSinceMidnight % 60,
);

String discoverWallTime(AppLocalizations l10n, LocalDateTimeValue value) =>
    RechargeFormats.wallTime(_wall(value), l10n.localeName);

String discoverWallDate(AppLocalizations l10n, LocalDateTimeValue value) =>
    RechargeFormats.wallDate(_wall(value), l10n.localeName);

/// Date with weekday and year, e.g. `Sun, Jun 21, 2026`.
String discoverWallDateWithWeekday(
  AppLocalizations l10n,
  LocalDateTimeValue value,
) => RechargeFormats.wallDateWithWeekday(_wall(value), l10n.localeName);

/// Date with weekday, no year, e.g. `Sun, Jun 21`.
String discoverWallDayWithWeekday(
  AppLocalizations l10n,
  LocalDateTimeValue value,
) => RechargeFormats.wallDayWithWeekday(_wall(value), l10n.localeName);

/// The search conditions of [query] as short reader-facing chips.
List<String> discoverQueryConditionTexts(
  AppLocalizations l10n,
  DiscoverQuery query,
) => <String>[
  if (query.freeOnly) l10n.discoverFree,
  if (query.budgetMax case final Money budget)
    l10n.discoverUpToBudget(RechargeFormats.money(budget, l10n.localeName)),
  if (query.dateFrom != null || query.dateTo != null) l10n.discoverDateSet,
  query.unlimitedRadius
      ? l10n.discoverAnyArea
      : l10n.discoverDistanceKm('${(query.radiusMeters / 1000).round()}'),
];

/// The declared duration of a catalog Activity: one value or a range.
String activityDurationLabel(
  AppLocalizations l10n,
  ActivityCatalogFacts facts,
) => facts.durationMinMinutes == facts.durationMaxMinutes
    ? l10n.discoverMinutes(facts.durationMinMinutes)
    : l10n.discoverMinutesRange(
        facts.durationMinMinutes,
        facts.durationMaxMinutes,
      );

/// The feed's notice in the reader's language; null when there is none.
String? discoverFeedNoticeText(
  AppLocalizations l10n,
  DiscoverFeedNotice? notice,
) => notice == null ? null : l10n.discoverFeedNotice(notice.name);
