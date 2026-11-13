import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/publication_journal_file.dart';

void main() {
  late Directory directory;
  late File file;
  late PublicationJournalFile<Map<String, Object?>> storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'publication-journal-test-',
    );
    file = File('${directory.path}/nested/journal.json');
    storage = PublicationJournalFile(
      file,
      decode: (value) => value is Map && value['id'] is String
          ? Map<String, Object?>.from(value)
          : null,
      encode: (value) => value,
      maxRecords: 2,
    );
  });
  tearDown(() async => directory.delete(recursive: true));
  test(
    'missing, malformed, non-list and unrecognized records preserve fallback semantics',
    () async {
      expect(await storage.read(), isEmpty);
      await file.parent.create(recursive: true);
      for (final content in ['{broken', '{}', 'null']) {
        await file.writeAsString(content);
        expect(await storage.read(), isEmpty);
      }
      await file.writeAsString(
        '[null,42,{"id":"legacy","type":"place","revision":1},{"unexpected":true},{"id":"activity","pendingActivationRevisionId":"old"}]',
      );
      final records = await storage.read();
      expect(records.map((record) => record['id']), ['legacy', 'activity']);
      expect(records.last['pendingActivationRevisionId'], 'old');
    },
  );
  test(
    'bounded disk roundtrip retains order and data and leaves no half-written temp file',
    () async {
      await storage.write([
        {'id': 'new', 'publisher': 'page-a'},
        {'id': 'old', 'publisher': 'page-b'},
        {'id': 'evicted'},
      ]);
      expect(await storage.read(), [
        {'id': 'new', 'publisher': 'page-a'},
        {'id': 'old', 'publisher': 'page-b'},
      ]);
      expect(await File('${file.path}.tmp').exists(), isFalse);
      await storage.write([
        {'id': 'replacement'},
      ]);
      expect(await storage.read(), [
        {'id': 'replacement'},
      ]);
    },
  );
  test(
    'disk access failures remain errors rather than masquerading as empty ownership',
    () async {
      await directory.delete(recursive: true);
      await File(directory.path).writeAsString('not a directory');
      try {
        await expectLater(
          storage.write([
            {'id': 'new'},
          ]),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        await File(directory.path).delete();
        await directory.create();
      }
    },
  );
}
