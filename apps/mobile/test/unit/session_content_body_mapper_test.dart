import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/build_session_content_body.dart';
import '../fixtures/create/user_session_draft.dart';

void main() {
  const user = '11111111-1111-4111-8111-111111111111';
  final scope = SessionPublicationScope(
    accountId: user,
    publisherRef: const PublisherRef(type: PublisherType.user, id: user),
    localDraftId: 'local-session-1',
  );
  test(
    'real Session draft maps byte-for-byte to shared backend valid fixture',
    () {
      final fixture =
          jsonDecode(
                File(
                  '../../packages/api_contracts/schema/content/v1/fixtures/session_create_compat.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final draft = userSessionDraft(userId: user, coverPath: 'cover.png');
      final mapped = const SessionContentBodyMapper().map(
        draft,
        scope: scope,
        serverOwnerUserId: user,
        defaultContentLocale: 'en',
        assetIds: <String, String>{
          scope.coverAttachmentId: '33333333-3333-4333-8333-333333333333',
        },
      );
      expect(mapped.unsupported, isEmpty);
      expect(mapped.body, (fixture['cases'] as List).first['body']);
    },
  );
  test(
    'unknown payload refuses and changing confirmed location invalidates pin',
    () {
      final draft = userSessionDraft(userId: user, coverPath: 'cover.png');
      final changed = draft.copyWith(
        sessionData: draft.sessionData!.copyWith(
          unknownFields: <String, Object?>{'future': true},
        ),
      );
      expect(
        const SessionContentBodyMapper()
            .map(
              changed,
              scope: scope,
              serverOwnerUserId: user,
              defaultContentLocale: 'en',
            )
            .unsupported,
        contains('unknown_fields'),
      );
      expect(SessionContentBodyMapper.pinConfirmed(draft), isTrue);
      expect(
        SessionContentBodyMapper.pinConfirmed(
          draft.copyWith(addressLine1: 'Different address'),
        ),
        isFalse,
      );
    },
  );
  test(
    'invalid typed input remains lossless against shared rejection fixtures',
    () {
      final fixture =
          jsonDecode(
                File(
                  '../../packages/api_contracts/schema/content/v1/fixtures/session_create_compat.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final base = userSessionDraft(userId: user, coverPath: 'cover.png');
      final data = base.sessionData!;
      final invalid = {
        'window_mismatch': data.copyWith(
          schedule: data.schedule.copyWith(projectionWindowDays: 29),
        ),
        'duration': data.copyWith(
          schedule: data.schedule.copyWith(slotDurationMinutes: 29),
        ),
        'timezone': data.copyWith(timezoneId: 'Mars/Base'),
        'credential_url': data.copyWith(
          externalBookingUrl: 'https://user:secret@example.org',
        ),
      };
      for (final entry in invalid.entries) {
        final expected = (fixture['cases'] as List).firstWhere(
          (dynamic c) => c['name'] == entry.key,
        )['body'];
        final mapped = const SessionContentBodyMapper().map(
          base.copyWith(sessionData: entry.value),
          scope: scope,
          serverOwnerUserId: user,
          defaultContentLocale: 'en',
          assetIds: <String, String>{
            scope.coverAttachmentId: '33333333-3333-4333-8333-333333333333',
          },
        );
        expect(mapped.body, expected, reason: entry.key);
      }
    },
  );
}
