import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:recharge/features/create/domain/entities/event_publication.dart';

/// Real HTTP to the local stand with one-shot faults on chosen Content
/// commands (M1 stage 2). Only the network between the app and the stand is
/// wrapped; the backend is the real one.
///
/// [severNext] fails the next request of a command before anything is sent;
/// [dropNextResponse] lets the next request of a command reach the server and
/// then loses the answer. [sent] counts the requests of each command that
/// reached the server, so a test can prove what the backend received.
final class ContentFaultClient extends http.BaseClient {
  ContentFaultClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Set<String> _sever = <String>{};
  final Set<String> _drop = <String>{};
  final Map<String, int> sent = <String, int>{};

  void severNext(String commandType) => _sever.add(commandType);

  void dropNextResponse(String commandType) => _drop.add(commandType);

  int sentCount(String commandType) => sent[commandType] ?? 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String? command = _contentCommand(request);
    if (command != null && _sever.remove(command)) {
      throw const SocketException('simulated: no connection');
    }
    // Every request on a fresh connection, so a socket the server closed while
    // the test waited never turns into an unplanned unknown outcome.
    request.persistentConnection = false;
    final http.StreamedResponse response = await _inner.send(request);
    if (command != null) sent[command] = sentCount(command) + 1;
    if (command != null && _drop.remove(command)) {
      await response.stream.drain<void>();
      throw const SocketException('simulated: response lost');
    }
    return response;
  }

  static String? _contentCommand(http.BaseRequest request) {
    if (request is! http.Request ||
        !request.url.path.endsWith('/contentCommandV1')) {
      return null;
    }
    final Object? body = jsonDecode(request.body);
    final Object? data = body is Map ? body['data'] : null;
    final Object? command = data is Map ? data['commandType'] : null;
    return command is String ? command : null;
  }
}

/// One publication controller of any of the five M1 types, seen through the
/// few operations the M1 stage 2 fault scenarios need. The five controllers
/// share no interface, so each test file adapts its own with closures.
final class PublicationProbe {
  PublicationProbe({
    required this.load,
    required this.save,
    required this.uploadMedia,
    required this.submit,
    required this.publish,
    required this.refresh,
    required this.dispose,
    required this.message,
    required this.offline,
    required this.journaledSubmissionId,
    required this.status,
  });

  final Future<void> Function() load;
  final Future<void> Function() save;
  final Future<void> Function() uploadMedia;
  final Future<void> Function() submit;
  final Future<void> Function() publish;
  final Future<void> Function() refresh;
  final void Function() dispose;
  final String? Function() message;
  final bool Function() offline;
  final String? Function() journaledSubmissionId;
  final EventPublicationStatus? Function() status;
}

const String _submit = 'submitForPublication';
const String _publish = 'publishApprovedRevision';

/// Saves and uploads the media of a fresh controller; the starting point of
/// both fault scenarios.
Future<PublicationProbe> preparedForSubmit(
  Future<PublicationProbe> Function() open,
) async {
  final PublicationProbe c = await open();
  await c.load();
  await c.save();
  expect(c.message(), isNull, reason: c.message());
  await c.uploadMedia();
  expect(c.message(), isNull, reason: c.message());
  return c;
}

/// S1-S3 for `submitForPublication`: a severed request sends nothing and the
/// client says offline; a lost answer leaves an unknown outcome the server did
/// process; a new controller over the same journal (an app restart) retries
/// with the same idempotency key and gets the one submission back.
/// [open] builds a new controller over the same journal and draft.
Future<String> expectSubmitSurvivesFaults(
  ContentFaultClient faults,
  Future<PublicationProbe> Function() open,
) async {
  final PublicationProbe c = await preparedForSubmit(open);

  final int before = faults.sentCount(_submit);
  faults.severNext(_submit);
  await c.submit();
  expect(c.offline(), isTrue, reason: 'severed submit must read as offline');
  expect(c.message(), 'unavailable');
  expect(
    faults.sentCount(_submit),
    before,
    reason: 'nothing reached the server',
  );
  await c.refresh();
  expect(c.status()?.latestSubmissionId, isNull);
  expect(c.journaledSubmissionId(), isNull);

  faults.dropNextResponse(_submit);
  await c.submit();
  expect(c.offline(), isTrue, reason: 'a lost answer is an unknown outcome');
  expect(faults.sentCount(_submit), before + 1);
  await c.refresh();
  final String? processed = c.status()?.latestSubmissionId;
  expect(processed, isNotNull, reason: 'the server processed the lost request');
  expect(c.status()?.latestSubmissionState, 'under_review');
  expect(c.journaledSubmissionId(), isNull, reason: 'the answer never arrived');
  c.dispose();

  final PublicationProbe again = await open();
  await again.load();
  await again.submit();
  expect(
    again.status()?.latestSubmissionId,
    processed,
    reason: 'one submission',
  );
  expect(again.journaledSubmissionId(), processed);
  expect(again.message(), isNull, reason: again.message());
  again.dispose();
  return processed!;
}

/// S1-S3 for `publishApprovedRevision`, from an approved submission: a severed
/// request publishes nothing; a lost answer leaves the revision published on
/// the server; a new controller over the same journal retries with the same
/// key, and the server holds exactly one publication.
Future<void> expectPublishSurvivesFaults(
  ContentFaultClient faults,
  Future<PublicationProbe> Function() open,
  Future<void> Function(String submissionId) approve,
) async {
  final PublicationProbe c = await preparedForSubmit(open);
  await c.submit();
  expect(c.message(), isNull, reason: c.message());
  await approve(c.status()!.latestSubmissionId!);
  await c.refresh();
  expect(c.status()?.latestSubmissionState, 'approved_for_publication');

  final int before = faults.sentCount(_publish);
  faults.severNext(_publish);
  await c.publish();
  expect(c.offline(), isTrue, reason: 'severed publish must read as offline');
  expect(c.message(), 'unavailable');
  expect(
    faults.sentCount(_publish),
    before,
    reason: 'nothing reached the server',
  );
  await c.refresh();
  expect(c.status()?.currentPublishedRevisionId, isNull);
  expect(c.status()?.latestSubmissionState, 'approved_for_publication');

  faults.dropNextResponse(_publish);
  await c.publish();
  expect(c.offline(), isTrue, reason: 'a lost answer is an unknown outcome');
  expect(faults.sentCount(_publish), before + 1);
  await c.refresh();
  final String? published = c.status()?.currentPublishedRevisionId;
  final int? pointer = c.status()?.pointerRevision;
  expect(published, isNotNull, reason: 'the server processed the lost request');
  expect(c.status()?.visibility, 'visible');
  c.dispose();

  final PublicationProbe again = await open();
  await again.load();
  await again.publish();
  final String? retryMessage = again.message();
  await again.refresh();
  expect(
    again.status()?.currentPublishedRevisionId,
    published,
    reason: 'exactly one publication',
  );
  expect(again.status()?.pointerRevision, pointer, reason: 'no second move');
  expect(
    retryMessage,
    isNull,
    reason: 'the retry with the same key must end as the success it was',
  );
  again.dispose();
}
