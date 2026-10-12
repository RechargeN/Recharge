final class ContentValidationViolation {
  const ContentValidationViolation({
    required this.code,
    required this.fieldPath,
  });
  final String code;
  final String fieldPath;

  static List<ContentValidationViolation> fromWire(Object? value) {
    if (value is! List || value.length > 50) return const [];
    final result = <ContentValidationViolation>[];
    for (final item in value) {
      if (item is! Map || item.length != 2) return const [];
      final code = item['code'];
      final path = item['fieldPath'];
      if (code is! String ||
          path is! String ||
          code.length > 128 ||
          path.length > 256 ||
          !RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$').hasMatch(code) ||
          !RegExp(r'^/body(/[A-Za-z0-9_~-]+)*$').hasMatch(path)) {
        return const [];
      }
      result.add(ContentValidationViolation(code: code, fieldPath: path));
    }
    return List.unmodifiable(result);
  }
}
