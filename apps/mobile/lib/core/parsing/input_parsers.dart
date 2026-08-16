double? parseLocaleDecimalInput(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  return normalized.isEmpty ? null : double.tryParse(normalized);
}

int? parseClockMinute(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}
