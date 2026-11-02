import 'package:uuid/uuid.dart';

import '../../domain/repositories/content_translation_port.dart';

typedef ContentTranslationInvoke =
    Future<Map<String, Object?>> Function(String, Map<String, Object?>);

/// `offerContentTranslationV1` and `translateContentV1` (ADR 0022 stage 1).
final class ContentTranslationClient implements ContentTranslationPort {
  ContentTranslationClient({
    required ContentTranslationInvoke invoke,
    String Function()? newId,
  }) : _invoke = invoke,
       _newId = newId ?? const Uuid().v4;

  final ContentTranslationInvoke _invoke;
  final String Function() _newId;

  Map<String, Object?> _request(
    String contentId,
    String publishedRevisionId,
    String targetLocale,
  ) => <String, Object?>{
    'schemaVersion': 1,
    'requestId': _newId(),
    'contentId': contentId,
    'publishedRevisionId': publishedRevisionId,
    'targetLocale': targetLocale,
  };

  @override
  Future<ContentTranslationOffer> offer({
    required String contentId,
    required String publishedRevisionId,
    required String targetLocale,
  }) async {
    try {
      final Map<String, Object?> answer = await _invoke(
        'offerContentTranslationV1',
        _request(contentId, publishedRevisionId, targetLocale),
      );
      return switch (answer['kind']) {
        'offered' => const ContentTranslationAvailable(),
        'translated' => ContentTranslationReady(
          _translation(answer, targetLocale),
        ),
        _ => const ContentTranslationUnavailable(),
      };
    } on ContentTranslationFailure {
      return const ContentTranslationUnavailable();
    }
  }

  @override
  Future<ContentTranslation> translate({
    required String contentId,
    required String publishedRevisionId,
    required String targetLocale,
  }) async {
    final Map<String, Object?> answer = await _invoke(
      'translateContentV1',
      _request(contentId, publishedRevisionId, targetLocale),
    );
    final Object? kind = answer['kind'];
    if (kind == 'rejected') {
      final Object? code = answer['code'];
      throw ContentTranslationFailure(code is String ? code : 'unknown');
    }
    return _translation(answer, targetLocale);
  }

  /// Only a labeled machine translation with text fields is accepted.
  static ContentTranslation _translation(
    Map<String, Object?> answer,
    String targetLocale,
  ) {
    final Object? kind = answer['kind'];
    final Object? fields = answer['fields'];
    if (kind != 'translated' ||
        answer['machineTranslated'] != true ||
        fields is! Map) {
      throw const ContentTranslationFailure('provider_unavailable');
    }
    String? text(String key) {
      final Object? value = fields[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    return ContentTranslation(
      sourceLocale: answer['sourceLocale'] as String? ?? '',
      targetLocale: targetLocale,
      title: text('title'),
      shortDescription: text('shortDescription'),
      fullDescription: text('fullDescription'),
    );
  }
}
