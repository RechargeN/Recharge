class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory LocalDate.parse(String value) {
    final List<String> parts = value.split('-');
    if (parts.length != 3) throw const FormatException('Invalid local date');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  DateTime get asUtcMidnight => DateTime.utc(year, month, day);

  LocalDate addDays(int days) {
    final DateTime next = asUtcMidnight.add(Duration(days: days));
    return LocalDate(next.year, next.month, next.day);
  }

  @override
  int compareTo(LocalDate other) =>
      asUtcMidnight.compareTo(other.asUtcMidnight);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
