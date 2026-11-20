/// Reads an identity field from a stored record. Only an ABSENT key may
/// inherit its recorded parent context. Present unknown stays unknown.
String recordedIdentityText(
  Map<dynamic, dynamic> record,
  String key, {
  required String recordedContext,
}) {
  if (!record.containsKey(key)) return recordedContext;
  final raw = record[key];
  if (raw == null) return '';
  if (raw is! String) throw FormatException('identity_field_must_be_text', key);
  return raw;
}
