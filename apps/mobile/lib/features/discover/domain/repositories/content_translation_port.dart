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

/// What Details may show before any tap.
sealed class ContentTranslationOffer {
  const ContentTranslationOffer();
}

/// Nothing to offer: no button, no space.
final class ContentTranslationUnavailable extends ContentTranslationOffer {
  const ContentTranslationUnavailable();
}

/// A reader translation on request: the button.
final class ContentTranslationAvailable extends ContentTranslationOffer {
  const ContentTranslationAvailable();
}

/// Amendment 1: a translation kept at publication, shown at once.
final class ContentTranslationReady extends ContentTranslationOffer {
  const ContentTranslationReady(this.translation);

  final ContentTranslation translation;
}

/// Sends identifiers and the target language only: the client never sends text.
abstract interface class ContentTranslationPort {
  /// The button, a kept translation, or nothing. Spends nothing; any refusal or
  /// failure is [ContentTranslationUnavailable], so the screen stays as it is.
  Future<ContentTranslationOffer> offer({
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
