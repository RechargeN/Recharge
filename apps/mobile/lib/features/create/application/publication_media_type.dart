/// A client filename claim only; Media detects the actual format from bytes.
String declaredPublicationMediaType(String reference) {
  final String lower = reference.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'application/octet-stream';
}
