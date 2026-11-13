import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/find_people_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/build_find_people_content_body.dart';

import '../fixtures/create/user_find_people_draft.dart';

void main() {
  const String user = '11111111-1111-4111-8111-111111111111';
  final FindPeoplePublicationScope scope = FindPeoplePublicationScope(
    accountId: user,
    publisherRef: const PublisherRef(type: PublisherType.user, id: user),
    localDraftId: 'local-find-people-1',
  );
  const FindPeopleContentBodyMapper mapper = FindPeopleContentBodyMapper();

  Map<String, Object?> fixtureCase(String name) {
    final Map<String, dynamic> fixture =
        jsonDecode(
              File(
                '../../packages/api_contracts/schema/content/v1/fixtures/find_people_create_compat.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    return ((fixture['cases'] as List).cast<Map<String, dynamic>>()).firstWhere(
          (Map<String, dynamic> item) => item['name'] == name,
        )['body']
        as Map<String, Object?>;
  }

  test('real Create draft maps byte-for-byte to the shared valid fixture', () {
    final FindPeopleContentBody mapped = mapper.map(
      userFindPeopleDraft(userId: user),
      scope: scope,
      serverOwnerUserId: user,
      defaultContentLocale: 'en',
    );
    expect(mapped.unsupported, isEmpty);
    expect(mapped.body, fixtureCase('valid'));
  });

  test('the local public preview and device location are never sent', () {
    final String text = jsonEncode(
      mapper
          .map(
            userFindPeopleDraft(userId: user),
            scope: scope,
            serverOwnerUserId: user,
            defaultContentLocale: 'en',
          )
          .body,
    );
    for (final String forbidden in <String>[
      'publicGeo',
      '"location"',
      '56.951,',
      '24.086,',
      'publicLocation',
    ]) {
      expect(text.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('stable ids: the same draft repeats its slot id and keys', () {
    final FindPeoplePublicationScope again = FindPeoplePublicationScope(
      accountId: user,
      publisherRef: const PublisherRef(type: PublisherType.user, id: user),
      localDraftId: 'local-find-people-1',
    );
    expect(again.slotId('loc_slot_1'), scope.slotId('loc_slot_1'));
    expect(again.keyBase, scope.keyBase);
    final FindPeoplePublicationScope other = FindPeoplePublicationScope(
      accountId: user,
      publisherRef: const PublisherRef(type: PublisherType.page, id: user),
      localDraftId: 'local-find-people-1',
    );
    expect(other.slotId('loc_slot_1'), isNot(scope.slotId('loc_slot_1')));
  });

  test(
    'what the T3 server does not serve is refused locally, never dropped',
    () {
      final base = userFindPeopleDraft(userId: user);
      final FindPeopleDraftData data = base.findPeopleData!;
      final Map<String, FindPeopleDraftData>
      cases = <String, FindPeopleDraftData>{
        'schedule_mode': data.copyWith(
          scheduleMode: FindPeopleScheduleMode.timePoll,
        ),
        'meeting_mode': data.copyWith(
          meetingMode: FindPeopleMeetingMode.hybrid,
        ),
        'online_access': data.copyWith(onlineProvider: 'video'),
        'visibility': data.copyWith(visibility: FindPeopleVisibility.unlisted),
        'co_hosts': data.copyWith(
          coHosts: const <FindPeopleCoHostDraft>[
            FindPeopleCoHostDraft(
              id: 'co-1',
              userId: 'someone',
              capabilityIds: <String>{'review_applications'},
              accepted: false,
              occupiesSeat: false,
            ),
          ],
        ),
        'application_questions': data.copyWith(
          applicationQuestions: const <FindPeopleApplicationQuestionDraft>[
            FindPeopleApplicationQuestionDraft(
              id: 'q-1',
              prompt: 'Pace?',
              type: FindPeopleQuestionType.text,
            ),
          ],
        ),
        'expense_items': data.copyWith(
          expenseSplitMode: FindPeopleExpenseSplitMode.itemized,
        ),
        'participant_invites': data.copyWith(allowParticipantInvites: true),
        'scheduled_publish': data.copyWith(publishAtUtc: DateTime.utc(2027)),
        'responsible_hosts': data.copyWith(
          responsibleHostUserIds: <String>{user, 'someone-else'},
        ),
      };
      for (final MapEntry<String, FindPeopleDraftData> entry in cases.entries) {
        expect(
          mapper
              .map(
                base.copyWith(findPeopleData: entry.value),
                scope: scope,
                serverOwnerUserId: user,
                defaultContentLocale: 'en',
              )
              .unsupported,
          contains(entry.key),
          reason: entry.key,
        );
      }
      expect(
        mapper
            .map(
              base.copyWith(
                media: MediaEntity(
                  coverImage: 'cover.png',
                  gallery: const <String>[],
                ),
              ),
              scope: scope,
              serverOwnerUserId: user,
              defaultContentLocale: 'en',
            )
            .unsupported,
        contains('media'),
      );
    },
  );
}
