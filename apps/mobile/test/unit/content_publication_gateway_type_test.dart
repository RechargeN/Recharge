import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/domain/entities/event_publication.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/event_publication_gateway.dart';

/// D3.1 §1: the shared Content gateway only gained a type parameter (Event by
/// default, unchanged for C3) and reads the author the server recorded.
void main() {
  test('Event stays the default type of createDraft', () async {
    final _RecordingPort port = _RecordingPort();
    await FunctionsEventPublicationGateway(
      port: port,
      gate: const _Open(),
    ).createDraft(
      publisherRef: const PublisherRef(type: PublisherType.page, id: 'page-1'),
      marketId: 'LV',
      body: const <String, Object?>{},
      idempotencyKey: 'key-event-1',
    );
    expect(
      (port.calls.single.data['payload']! as Map<String, Object?>)['typeId'],
      'event',
    );
  });

  test(
    'a Place gateway creates Place drafts and returns the server author',
    () async {
      final _RecordingPort port = _RecordingPort();
      final FunctionsEventPublicationGateway gateway =
          FunctionsEventPublicationGateway(
            port: port,
            gate: const _Open(),
            typeId: 'place',
          );
      final EventServerDraftRef created = await gateway.createDraft(
        publisherRef: const PublisherRef(
          type: PublisherType.page,
          id: 'page-1',
        ),
        marketId: 'LV',
        body: const <String, Object?>{},
        idempotencyKey: 'key-place-1',
      );
      final Map<String, Object?> sent = port.calls.single.data;
      expect(port.calls.single.callable, 'contentCommandV1');
      expect(sent['commandType'], 'createDraft');
      expect((sent['payload']! as Map<String, Object?>)['typeId'], 'place');
      expect(created.createdByUserId, 'server-user-1');
      expect(created.revision, 1);
    },
  );

  test(
    'draft() is the owner read getDraft with the same draft fields',
    () async {
      final _RecordingPort port = _RecordingPort();
      final EventServerDraftRef draft = await FunctionsEventPublicationGateway(
        port: port,
        gate: const _Open(),
        typeId: 'place',
      ).draft('draft-1');
      expect(port.calls.single.callable, 'contentQueryV1');
      expect(port.calls.single.data['queryType'], 'getDraft');
      expect(port.calls.single.data['payload'], <String, Object?>{
        'draftId': 'draft-1',
      });
      expect(draft.draftId, 'draft-1');
      expect(draft.createdByUserId, 'server-user-1');
    },
  );

  test('a draft without an author reads as null, never as a guess', () async {
    final _RecordingPort port = _RecordingPort(author: null);
    final EventServerDraftRef draft = await FunctionsEventPublicationGateway(
      port: port,
      gate: const _Open(),
    ).draft('draft-1');
    expect(draft.createdByUserId, isNull);
  });
}

final class _Open implements EventPublicationCommandGate {
  const _Open();

  @override
  bool get allowed => true;

  @override
  void assertAllowed() {}
}

final class _RecordingPort implements ContentCallablePort {
  _RecordingPort({this.author = 'server-user-1'});

  final String? author;
  final List<({String callable, Map<String, Object?> data})> calls =
      <({String callable, Map<String, Object?> data})>[];

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    calls.add((callable: callableName, data: data));
    final Object? payload = data['payload'];
    final String draftId = payload is Map && payload['draftId'] is String
        ? payload['draftId']! as String
        : 'draft-1';
    return <String, Object?>{
      'kind': 'succeeded',
      'data': <String, Object?>{
        'contentId': 'content-1',
        'draftId': draftId,
        'revision': 1,
        if (author != null) 'createdByUserId': author,
      },
    };
  }
}
