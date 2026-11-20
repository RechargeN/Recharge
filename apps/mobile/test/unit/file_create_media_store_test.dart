import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart' show UuidV4IdGenerator;
import 'package:recharge/features/create/data/media/file_create_media_store.dart';
import 'package:recharge/features/create/domain/repositories/create_image_picker_port.dart';
import 'package:recharge/features/create/domain/repositories/create_media_store.dart';

/// MEDIA-PICK-01 §6 / MP-AC-05: private copies, atomic writes, cleanup.
void main() {
  late Directory support;
  late FileCreateMediaStore store;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('create-media-');
    store = FileCreateMediaStore(
      supportDirectory: () async => support,
      idGenerator: UuidV4IdGenerator(),
      maxFilesPerDraft: 3,
      maxTotalBytes: 100,
    );
  });

  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });

  Uint8List bytes(int n) => Uint8List.fromList(List<int>.filled(n, 7));

  test('a copy is written under create_media/<draft> and owned', () async {
    final path = await store.save('loc_draft_1', bytes(10));
    expect(path, contains('${Platform.pathSeparator}create_media'));
    expect(path, contains('loc_draft_1'));
    expect(path, endsWith('.jpg'));
    expect(await File(path).readAsBytes(), bytes(10));
    expect(store.owns(path), isTrue);
    expect(store.owns('https://example.org/cover.jpg'), isFalse);
    expect(store.owns(r'C:\photos\cover.jpg'), isFalse);
    expect(
      File(path).parent.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.tmp'),
      ),
      isEmpty,
      reason: 'the temporary name is renamed away',
    );
  });

  test('draft keys cannot leave the store', () async {
    final path = await store.save('../../escape', bytes(5));
    expect(File(path).absolute.path, startsWith(support.absolute.path));
    expect(path, isNot(contains('escape')));
    expect(FileCreateMediaStore.folderFor('../../escape'), startsWith('k'));
  });

  test('remove deletes only its own copies', () async {
    final path = await store.save('d', bytes(5));
    final outside = File('${support.path}${Platform.pathSeparator}mine.jpg')
      ..writeAsBytesSync(bytes(5));
    await store.remove(outside.path);
    expect(outside.existsSync(), isTrue, reason: 'not a store copy');
    await store.remove('https://example.org/x.jpg');
    await store.remove(path);
    expect(File(path).existsSync(), isFalse);
    await store.remove(path);
  });

  test('quotas: files per draft and total bytes', () async {
    for (var i = 0; i < 3; i++) {
      await store.save('d', bytes(5));
    }
    await expectLater(
      store.save('d', bytes(5)),
      throwsA(
        isA<CreateMediaException>().having(
          (e) => e.code,
          'code',
          'media_storage_full',
        ),
      ),
    );
    await expectLater(
      store.save('other', bytes(90)),
      throwsA(isA<CreateMediaException>()),
    );
  });

  test('partial writes are removed, finished copies are kept', () async {
    final kept = await store.save('d', bytes(5));
    final partial = File('${File(kept).parent.path}/half.jpg.tmp')
      ..writeAsBytesSync(bytes(3));
    expect(await store.removePartialWrites(), 1);
    expect(partial.existsSync(), isFalse);
    expect(File(kept).existsSync(), isTrue);
  });

  group('MEDIA-PICK-02', () {
    test(
      'copies of different accounts live in separate folders, no ids in paths',
      () async {
        final a = await store.save(
          createMediaDraftKey('uid-a', 'loc_1'),
          bytes(5),
        );
        final b = await store.save(
          createMediaDraftKey('uid-b', 'loc_1'),
          bytes(5),
        );
        expect(File(a).parent.parent.path, isNot(File(b).parent.parent.path));
        expect(a, isNot(contains('uid-a')));
        expect(b, isNot(contains('uid-b')));
        expect(store.owns(a) && store.owns(b), isTrue);
      },
    );

    test(
      'release deletes only a copy of this store and leaves no journal entry',
      () async {
        final path = await store.save(
          createMediaDraftKey('uid-a', 'loc_1'),
          bytes(5),
        );
        final outside = File('${support.path}${Platform.pathSeparator}keep.jpg')
          ..writeAsBytesSync(bytes(1));
        await store.release(ownerId: 'uid-a', path: path);
        await store.release(ownerId: 'uid-a', path: outside.path);
        expect(File(path).existsSync(), isFalse);
        expect(outside.existsSync(), isTrue);
        expect(
          await store.sweepReleased(ownerId: 'uid-a', referenced: (_) => false),
          0,
        );
      },
    );

    test(
      'an interrupted release is finished for its own account only, and a copy the draft uses again is kept',
      () async {
        final mine = await store.save(
          createMediaDraftKey('uid-a', 'loc_1'),
          bytes(5),
        );
        final reused = await store.save(
          createMediaDraftKey('uid-a', 'loc_1'),
          bytes(5),
        );
        final theirs = await store.save(
          createMediaDraftKey('uid-b', 'loc_2'),
          bytes(5),
        );
        // A journal written before the app was ended between journal and delete.
        final journal = File(
          '${support.path}${Platform.pathSeparator}create_media${Platform.pathSeparator}released.jsonl',
        );
        journal.writeAsStringSync(
          [
            '{"account":"${FileCreateMediaStore.accountFolder('uid-a')}","path":${_json(mine)}}',
            '{"account":"${FileCreateMediaStore.accountFolder('uid-a')}","path":${_json(reused)}}',
            '{"account":"${FileCreateMediaStore.accountFolder('uid-b')}","path":${_json(theirs)}}',
            '{"account":', // a line cut short: ignored, nothing deleted for it
          ].join('\n'),
        );
        final removed = await store.sweepReleased(
          ownerId: 'uid-a',
          referenced: (String path) => path == reused,
        );
        expect(removed, 1);
        expect(File(mine).existsSync(), isFalse);
        expect(
          File(reused).existsSync(),
          isTrue,
          reason: 'the draft uses it again',
        );
        expect(
          File(theirs).existsSync(),
          isTrue,
          reason: 'another account is never swept',
        );
        // The other account finishes its own release later.
        expect(
          await store.sweepReleased(ownerId: 'uid-b', referenced: (_) => false),
          1,
        );
        expect(File(theirs).existsSync(), isFalse);
      },
    );

    test(
      'nothing that was never released is deleted by a sweep (mock mode keeps every copy)',
      () async {
        final path = await store.save(
          createMediaDraftKey('uid-a', 'loc_1'),
          bytes(5),
        );
        expect(
          await store.sweepReleased(ownerId: 'uid-a', referenced: (_) => false),
          0,
        );
        expect(File(path).existsSync(), isTrue);
      },
    );
  });
}

String _json(String value) => jsonEncode(value);
