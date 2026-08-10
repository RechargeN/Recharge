import '../entities/ai_assist_contract.dart';

class SanitizeAiInputUseCase {
  const SanitizeAiInputUseCase();

  static final RegExp _emailPattern = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  static final RegExp _phoneCandidatePattern = RegExp(r'\+?\d[\d\s().-]{6,}\d');
  static final RegExp _isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  AiAssistSanitizedInput call(String value) {
    final Set<AiAssistRedactionKind> redactions = <AiAssistRedactionKind>{};
    var sanitized = value.replaceAllMapped(_emailPattern, (_) {
      redactions.add(AiAssistRedactionKind.email);
      return '[email]';
    });
    sanitized = sanitized.replaceAllMapped(_phoneCandidatePattern, (match) {
      final String candidate = match.group(0) ?? '';
      final int digitCount = candidate.replaceAll(RegExp(r'\D'), '').length;
      if (_isoDatePattern.hasMatch(candidate) ||
          digitCount < 7 ||
          digitCount > 15) {
        return candidate;
      }
      redactions.add(AiAssistRedactionKind.phone);
      return '[phone]';
    });
    return AiAssistSanitizedInput(
      value: sanitized,
      redactions: redactions,
      originalLength: value.length,
    );
  }
}
