/// ADR 0022: what the reader sees of a machine translation. Plain text only;
/// it lives in the memory of the Details screen and is never persisted.
final class ContentTranslation {
  const ContentTranslation({
    required this.sourceLocale,
    required this.targetLocale,
    this.title,
    this.shortDescription,
    this.fullDescription,
  });

  final String sourceLocale;
  final String targetLocale;
  final String? title;
  final String? shortDescription;
  final String? fullDescription;
}

/// A typed refusal; [code] is `content_translation_result.schema.json`
/// `$defs/failureCode` or a transport code of the client.
final class ContentTranslationFailure implements Exception {
  const ContentTranslationFailure(this.code);

  final String code;

  @override
  String toString() => 'ContentTranslationFailure($code)';
}

/// Sends identifiers and the target language only: the client never sends text.
abstract interface class ContentTranslationPort {
  /// `true` when Details should offer the button. Spends nothing; any refusal
  /// or failure is `false`, so the screen stays as it is.
  Future<bool> offer({
    required String contentId,
    required String publishedRevisionId,
    required String targetLocale,
  });

  /// Throws [ContentTranslationFailure]; the original stays on screen.
  Future<ContentTranslation> translate({
    required String contentId,
    required String publishedRevisionId,
    required String targetLocale,
  });
}
