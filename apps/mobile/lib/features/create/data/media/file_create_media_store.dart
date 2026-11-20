import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../../core/id/id_generator.dart';
import '../../domain/repositories/create_image_picker_port.dart';
import '../../domain/repositories/create_media_store.dart';

/// MEDIA-PICK-01 §6: copies live in `<support>/create_media/<draft>/<id>.jpg`,
/// written to a temporary name and renamed, so a draft never points at half
/// a file (also when the OS ends the app mid-write). Only files under that
/// folder are ever deleted.
class FileCreateMediaStore implements CreateMediaStore {
  FileCreateMediaStore({
    required Future<Directory> Function() supportDirectory,
    required IdGenerator idGenerator,
    this.maxFilesPerDraft = 13,
    this.maxTotalBytes = 64 * 1024 * 1024,
  }) : _supportDirectory = supportDirectory,
       _ids = idGenerator;

  static const String folder = 'create_media';

  final Future<Directory> Function() _supportDirectory;
  final IdGenerator _ids;
  final int maxFilesPerDraft;
  final int maxTotalBytes;
  Future<Directory>? _root;

  Future<Directory> _rootDirectory() => _root ??= () async {
    final support = await _supportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}$folder',
    ).create(recursive: true);
  }();

  /// Draft keys become folder names: plain keys stay readable, anything else
  /// is hashed, so a key can never climb out of the store. An account-scoped
  /// key from [draftKeyFor] becomes `<account folder>/<draft folder>`.
  static String folderFor(String draftKey) {
    final Match? scoped = _scopedKey.firstMatch(draftKey);
    if (scoped != null) {
      return '${accountFolder(scoped.group(1)!)}/${_plainFolder(scoped.group(2)!)}';
    }
    return _plainFolder(draftKey);
  }

  static String _plainFolder(String key) =>
      RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(key)
      ? key
      : 'k${sha256.convert(utf8.encode(key)).toString().substring(0, 32)}';

  static final RegExp _scopedKey = RegExp(r'^account/(.+)/([^/]+)$');

  /// MEDIA-PICK-02: the folder of one account. No account id appears in a
  /// path; copies of different accounts never share a folder.
  static String accountFolder(String ownerId) =>
      'o_${sha256.convert(utf8.encode('account:$ownerId')).toString().substring(0, 32)}';

  /// The store key of [draftId] of [ownerId] (`<account folder>/<draft>`).
  static String draftKeyFor(String ownerId, String draftId) =>
      createMediaDraftKey(ownerId, draftId);

  static const String _releaseJournal = 'released.jsonl';

  @override
  bool owns(String path) {
    final String normalized = path.replaceAll('\\', '/');
    return normalized.contains('/$folder/') &&
        normalized.toLowerCase().endsWith('.jpg') &&
        !normalized.contains('/../');
  }

  Future<Directory> _draftDirectory(String draftKey) async {
    final root = await _rootDirectory();
    final String relative = folderFor(
      draftKey,
    ).replaceAll('/', Platform.pathSeparator);
    return Directory(
      '${root.path}${Platform.pathSeparator}$relative',
    ).create(recursive: true);
  }

  Future<List<File>> _files(Directory directory) async {
    if (!await directory.exists()) return const <File>[];
    return directory
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.jpg'))
        .cast<File>()
        .toList();
  }

  @override
  Future<String> save(String draftKey, Uint8List jpeg) async {
    final directory = await _draftDirectory(draftKey);
    final existing = await _files(directory);
    if (existing.length >= maxFilesPerDraft) {
      throw const CreateMediaException('media_storage_full');
    }
    int total = jpeg.length;
    for (final file in await _files(await _rootDirectory())) {
      total += await file.length();
    }
    if (total > maxTotalBytes) {
      throw const CreateMediaException('media_storage_full');
    }
    final String target =
        '${directory.path}${Platform.pathSeparator}${_ids.generate()}.jpg';
    final File temporary = File('$target.tmp');
    await temporary.writeAsBytes(jpeg, flush: true);
    await temporary.rename(target);
    return target;
  }

  Future<bool> _inside(String path) async {
    if (!owns(path)) return false;
    final root = (await _rootDirectory()).absolute.path;
    final candidate = File(path).absolute.path;
    return candidate.startsWith('$root${Platform.pathSeparator}');
  }

  @override
  Future<void> remove(String path) async {
    if (!await _inside(path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<File> _journalFile() async {
    final root = await _rootDirectory();
    return File('${root.path}${Platform.pathSeparator}$_releaseJournal');
  }

  Future<List<Map<String, String>>> _readJournal() async {
    final File file = await _journalFile();
    if (!await file.exists()) return <Map<String, String>>[];
    final List<Map<String, String>> entries = <Map<String, String>>[];
    for (final String line in await file.readAsLines()) {
      try {
        final Object? decoded = jsonDecode(line);
        if (decoded is Map &&
            decoded['account'] is String &&
            decoded['path'] is String) {
          entries.add(<String, String>{
            'account': decoded['account'] as String,
            'path': decoded['path'] as String,
          });
        }
      } on FormatException {
        // A line cut short by a crash; the copy stays, nothing is deleted.
      }
    }
    return entries;
  }

  Future<void> _writeJournal(List<Map<String, String>> entries) async {
    final File file = await _journalFile();
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      entries.map(jsonEncode).map((String line) => '$line\n').join(),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  @override
  Future<void> release({required String ownerId, required String path}) async {
    if (!await _inside(path)) return;
    final String account = accountFolder(ownerId);
    final List<Map<String, String>> entries = await _readJournal();
    entries.add(<String, String>{'account': account, 'path': path});
    await _writeJournal(entries);
    final File file = File(path);
    if (await file.exists()) await file.delete();
    entries.removeWhere(
      (Map<String, String> e) => e['account'] == account && e['path'] == path,
    );
    await _writeJournal(entries);
  }

  @override
  Future<int> sweepReleased({
    required String ownerId,
    required bool Function(String path) referenced,
  }) async {
    final String account = accountFolder(ownerId);
    final List<Map<String, String>> entries = await _readJournal();
    if (entries.isEmpty) return 0;
    int removed = 0;
    final List<Map<String, String>> kept = <Map<String, String>>[];
    for (final Map<String, String> entry in entries) {
      final String path = entry['path']!;
      // Another account's journal entries are never looked at here.
      if (entry['account'] != account) {
        kept.add(entry);
        continue;
      }
      if (referenced(path) || !await _inside(path)) continue;
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
        removed += 1;
      }
    }
    await _writeJournal(kept);
    return removed;
  }

  @override
  Future<int> removePartialWrites() async {
    final root = await _rootDirectory();
    int removed = 0;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.jpg.tmp')) {
        await entity.delete();
        removed += 1;
      }
    }
    return removed;
  }
}
