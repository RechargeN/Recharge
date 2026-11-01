import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/datasources/content_translation_client.dart';
import 'package:recharge/features/discover/domain/repositories/content_translation_port.dart';

void main() {
  const String contentId = '01JZTRANSLATE0000000000001';
  const String revisionId = '01JZTRANSLATE0000000000002';

  ContentTranslationClient client(
    Map<String, Object?> answer, {
    List<(String, Map<String, Object?>)>? calls,
  }) => ContentTranslationClient(
    invoke: (surface, request) async {
      calls?.add((surface, request));
      return answer;
    },
    newId: () => 'request-1',
  );

  test(
    'the request carries identifiers and language only, never text',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      await client(<String, Object?>{'kind': 'offered'}, calls: calls).offer(
        contentId: contentId,
        publishedRevisionId: revisionId,
        targetLocale: 'ru',
      );
      expect(calls.single.$1, 'offerContentTranslationV1');
      expect(calls.single.$2, <String, Object?>{
        'schemaVersion': 1,
        'requestId': 'request-1',
        'contentId': contentId,
        'publishedRevisionId': revisionId,
        'targetLocale': 'ru',
      });
    },
  );

  test('offer: a refusal or transport failure means no button', () async {
    expect(
      await client(<String, Object?>{
        'kind': 'rejected',
        'code': 'same_language',
      }).offer(
        contentId: contentId,
        publishedRevisionId: revisionId,
        targetLocale: 'lv',
      ),
      isFalse,
    );
    final ContentTranslationClient failing = ContentTranslationClient(
      invoke: (_, _) async =>
          throw const ContentTranslationFailure('test_entry_disabled'),
    );
    expect(
      await failing.offer(
        contentId: contentId,
        publishedRevisionId: revisionId,
        targetLocale: 'ru',
      ),
      isFalse,
    );
  });

  test(
    'translate: maps fields and typed refusals; an unlabeled answer fails',
    () async {
      final ContentTranslation translation =
          await client(<String, Object?>{
            'kind': 'translated',
            'machineTranslated': true,
            'sourceLocale': 'lv',
            'fields': <String, Object?>{
              'title': 'Заголовок',
              'fullDescription': 'Текст',
            },
          }).translate(
            contentId: contentId,
            publishedRevisionId: revisionId,
            targetLocale: 'ru',
          );
      expect(translation.title, 'Заголовок');
      expect(translation.shortDescription, isNull);
      expect(translation.fullDescription, 'Текст');

      Future<ContentTranslation> ask(Map<String, Object?> answer) =>
          client(answer).translate(
            contentId: contentId,
            publishedRevisionId: revisionId,
            targetLocale: 'ru',
          );
      await expectLater(
        ask(<String, Object?>{'kind': 'rejected', 'code': 'quota_exceeded'}),
        throwsA(
          isA<ContentTranslationFailure>().having(
            (f) => f.code,
            'code',
            'quota_exceeded',
          ),
        ),
      );
      await expectLater(
        ask(<String, Object?>{
          'kind': 'translated',
          'fields': <String, Object?>{'title': 'Без пометки'},
        }),
        throwsA(isA<ContentTranslationFailure>()),
      );
    },
  );
}
