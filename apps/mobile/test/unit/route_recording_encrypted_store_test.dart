import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/datasources/route_recording_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late EncryptedFileRouteRecordingStore store;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'recharge_gps_store_test_',
    );
    store = EncryptedFileRouteRecordingStore(
      secureStorage: const FlutterSecureStorage(),
      supportDirectory: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    final resolved = temporaryDirectory.absolute.path;
    if (!resolved.contains('recharge_gps_store_test_')) {
      throw StateError('Refusing to remove an unexpected test directory.');
    }
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('round-trips data without writing coordinates in clear text', () async {
    const key = 'route_gps_journal_v1.session.session-1.leg.leg-1.0';
    const value = '{"latitude":56.9700,"longitude":24.1300}';

    await store.write(key, value);

    expect(await store.read(key), value);
    final journalDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}route_gps_journal_v1',
    );
    final files = await journalDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.gpsj'))
        .cast<File>()
        .toList();
    expect(files, hasLength(1));
    final encrypted = await files.single.readAsString();
    expect(encrypted, isNot(contains('56.9700')));
    expect(encrypted, isNot(contains('24.1300')));
    expect(
      await const FlutterSecureStorage().read(
        key: 'route_gps_journal_master_key_v1',
      ),
      isNotEmpty,
    );
  });

  test('authenticated encryption rejects modified ciphertext', () async {
    const key = 'route_gps_journal_v1.draft.draft-1';
    await store.write(key, 'session-1');
    final journalDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}route_gps_journal_v1',
    );
    final file = await journalDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.gpsj'))
        .cast<File>()
        .single;
    final envelope =
        (jsonDecode(await file.readAsString()) as Map<Object?, Object?>)
            .cast<String, Object?>();
    final cipherText = base64Decode(envelope['cipherText']! as String);
    cipherText[0] ^= 1;
    envelope['cipherText'] = base64Encode(cipherText);
    await file.writeAsString(jsonEncode(envelope), flush: true);

    await expectLater(store.read(key), throwsStateError);
  });

  test('delete removes encrypted primary and recovery files', () async {
    const key = 'route_gps_journal_v1.draft.draft-1';
    await store.write(key, 'session-1');

    await store.delete(key);

    expect(await store.read(key), isNull);
  });
}
