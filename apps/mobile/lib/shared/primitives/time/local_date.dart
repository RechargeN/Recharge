/// A Gregorian calendar date, without a time, offset or instant.
class LocalDate implements Comparable<LocalDate> {
  factory LocalDate(int year, int month, int day) {
    if (year < 1 ||
        year > 9999 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      throw FormatException('Invalid Gregorian date', '$year-$month-$day');
    }
    final calendar = DateTime.utc(year, month, day);
    if (calendar.year != year ||
        calendar.month != month ||
        calendar.day != day) {
      throw FormatException('Invalid Gregorian date', '$year-$month-$day');
    }
    return LocalDate._(year, month, day);
  }

  const LocalDate._(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  factory LocalDate.parse(String value) {
    if (RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').stringMatch(value) != value) {
      throw FormatException('Expected YYYY-MM-DD', value);
    }
    return LocalDate(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }

  // DateTime is only an internal Gregorian calculator. This is not an instant
  // representing midnight in the calendar date's (unspecified) timezone.
  DateTime get _calendar => DateTime.utc(year, month, day);
  static final _epoch = DateTime.utc(1);
  static final _lastDay = DateTime.utc(9999, 12, 31).difference(_epoch).inDays;

  int get weekday => _calendar.weekday;

  LocalDate addDays(int days) {
    final dayNumber = _calendar.difference(_epoch).inDays;
    // Check before Duration arithmetic, including very large caller input.
    if (days < -dayNumber || days > _lastDay - dayNumber) {
      throw RangeError.range(days, -dayNumber, _lastDay - dayNumber, 'days');
    }
    final next = _calendar.add(Duration(days: days));
    return LocalDate(next.year, next.month, next.day);
  }

  @override
  int compareTo(LocalDate other) {
    final years = year.compareTo(other.year);
    if (years != 0) return years;
    final months = month.compareTo(other.month);
    return months != 0 ? months : day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
