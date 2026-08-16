import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/ai_assist/domain/entities/ai_assist_contract.dart';
import 'package:recharge/features/ai_assist/domain/usecases/sanitize_ai_input_usecase.dart';

void main() {
  const SanitizeAiInputUseCase sanitize = SanitizeAiInputUseCase();

  test('redacts email and international phone before gateway use', () {
    final AiAssistSanitizedInput result = sanitize(
      'Write to alice@example.com or call +371 20 000 000.',
    );

    expect(result.value, 'Write to [email] or call [phone].');
    expect(result.redactions, <AiAssistRedactionKind>{
      AiAssistRedactionKind.email,
      AiAssistRedactionKind.phone,
    });
  });

  test('preserves ISO dates and ordinary text', () {
    final AiAssistSanitizedInput result = sanitize(
      'Plan Riga for 2026-08-03 after lunch.',
    );

    expect(result.value, 'Plan Riga for 2026-08-03 after lunch.');
    expect(result.redactions, isEmpty);
  });
}
