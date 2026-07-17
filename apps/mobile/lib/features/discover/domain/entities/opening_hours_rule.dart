import 'local_date.dart';

enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

class OpeningHoursRule {
  OpeningHoursRule({
    this.dayOfWeek,
    this.exceptionDate,
    required this.isClosedAllDay,
    this.openMinutesSinceLocalMidnight,
    this.closeMinutesSinceLocalMidnight,
  }) {
    if ((dayOfWeek == null) == (exceptionDate == null)) {
      throw ArgumentError('Exactly one schedule selector is required');
    }
    if (!isClosedAllDay &&
        (openMinutesSinceLocalMidnight == null ||
            closeMinutesSinceLocalMidnight == null)) {
      throw ArgumentError('Open and close minutes are required');
    }
    for (final int? minutes in <int?>[
      openMinutesSinceLocalMidnight,
      closeMinutesSinceLocalMidnight,
    ]) {
      if (minutes != null && (minutes < 0 || minutes > 1439)) {
        throw ArgumentError.value(minutes, 'minutesSinceLocalMidnight');
      }
    }
  }

  final DayOfWeek? dayOfWeek;
  final LocalDate? exceptionDate;
  final bool isClosedAllDay;
  final int? openMinutesSinceLocalMidnight;
  final int? closeMinutesSinceLocalMidnight;

  Map<String, Object?> toMap() => <String, Object?>{
    'day_of_week': dayOfWeek?.name,
    'exception_date': exceptionDate?.toString(),
    'is_closed_all_day': isClosedAllDay,
    'open_minutes': openMinutesSinceLocalMidnight,
    'close_minutes': closeMinutesSinceLocalMidnight,
  };

  factory OpeningHoursRule.fromMap(Map<String, Object?> map) =>
      OpeningHoursRule(
        dayOfWeek: map['day_of_week'] == null
            ? null
            : DayOfWeek.values.firstWhere(
                (DayOfWeek value) => value.name == map['day_of_week'],
              ),
        exceptionDate: map['exception_date'] == null
            ? null
            : LocalDate.parse(map['exception_date']! as String),
        isClosedAllDay: (map['is_closed_all_day'] as bool?) ?? false,
        openMinutesSinceLocalMidnight: (map['open_minutes'] as num?)?.toInt(),
        closeMinutesSinceLocalMidnight: (map['close_minutes'] as num?)?.toInt(),
      );
}
