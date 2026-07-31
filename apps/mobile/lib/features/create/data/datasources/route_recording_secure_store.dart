import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class RouteRecordingSecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class EncryptedFileRouteRecordingStore implements RouteRecordingSecureStore {
  EncryptedFileRouteRecordingStore({
    required FlutterSecureStorage secureStorage,
    required Future<Directory> Function() supportDirectory,
    AesGcm? cipher,
  }) : _secureStorage = secureStorage,
       _supportDirectory = supportDirectory,
       _cipher = cipher ?? AesGcm.with256bits();

  static const String _masterKeyName = 'route_gps_journal_master_key_v1';
  static const int _envelopeVersion = 1;

  final FlutterSecureStorage _secureStorage;
  final Future<Directory> Function() _supportDirectory;
  final AesGcm _cipher;
  Future<SecretKey>? _masterKeyFuture;
  Future<Directory>? _directoryFuture;

  @override
  Future<String?> read(String key) async {
    final file = await _file(key);
    final backup = File('${file.path}.bak');
    if (!await file.exists() && !await backup.exists()) return null;
    Object? primaryError;
    if (await file.exists()) {
      try {
        return await _decrypt(key, await file.readAsString());
      } catch (error) {
        primaryError = error;
      }
    }
    if (await backup.exists()) {
      try {
        return await _decrypt(key, await backup.readAsString());
      } catch (_) {
        // The primary error is more useful when both authenticated copies fail.
      }
    }
    throw StateError(
      'Encrypted GPS journal authentication failed: $primaryError',
    );
  }

  @override
  Future<void> write(String key, String value) async {
    final file = await _file(key);
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    final encoded = await _encrypt(key, value);
    await temporary.writeAsString(encoded, flush: true);
    if (await backup.exists()) await backup.delete();
    if (await file.exists()) await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String key) async {
    final file = await _file(key);
    for (final candidate in <File>[
      file,
      File('${file.path}.bak'),
      File('${file.path}.tmp'),
    ]) {
      if (await candidate.exists()) await candidate.delete();
    }
  }

  Future<String> _encrypt(String logicalKey, String clearText) async {
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      utf8.encode(clearText),
      secretKey: await _masterKey(),
      nonce: nonce,
      aad: utf8.encode(logicalKey),
    );
    return jsonEncode(<String, Object?>{
      'version': _envelopeVersion,
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<String> _decrypt(String logicalKey, String encoded) async {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Invalid encrypted GPS journal envelope.');
    }
    final envelope = decoded.cast<String, Object?>();
    if (envelope['version'] != _envelopeVersion) {
      throw const FormatException(
        'Unsupported encrypted GPS journal envelope.',
      );
    }
    final box = SecretBox(
      base64Decode(_string(envelope, 'cipherText')),
      nonce: base64Decode(_string(envelope, 'nonce')),
      mac: Mac(base64Decode(_string(envelope, 'mac'))),
    );
    final clearBytes = await _cipher.decrypt(
      box,
      secretKey: await _masterKey(),
      aad: utf8.encode(logicalKey),
    );
    return utf8.decode(clearBytes);
  }

  Future<SecretKey> _masterKey() =>
      _masterKeyFuture ??= _loadOrCreateMasterKey();

  Future<SecretKey> _loadOrCreateMasterKey() async {
    final stored = await _secureStorage.read(key: _masterKeyName);
    if (stored != null && stored.isNotEmpty) {
      final bytes = base64Decode(stored);
      if (bytes.length != 32) {
        throw const FormatException('Invalid GPS journal master key.');
      }
      return SecretKey(bytes);
    }
    final key = await _cipher.newSecretKey();
    final bytes = await key.extractBytes();
    await _secureStorage.write(key: _masterKeyName, value: base64Encode(bytes));
    return SecretKey(bytes);
  }

  Future<File> _file(String logicalKey) async {
    final directory = await (_directoryFuture ??= _prepareDirectory());
    final name = sha256.convert(utf8.encode(logicalKey)).toString();
    return File('${directory.path}${Platform.pathSeparator}$name.gpsj');
  }

  Future<Directory> _prepareDirectory() async {
    final root = await _supportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}route_gps_journal_v1',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing encrypted GPS journal $key.');
    }
    return value;
  }
}
