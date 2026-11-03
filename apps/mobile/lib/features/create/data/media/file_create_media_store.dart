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
  /// is hashed, so a key can never climb out of the store.
  static String folderFor(String draftKey) =>
      RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(draftKey)
      ? draftKey
      : 'k${sha256.convert(utf8.encode(draftKey)).toString().substring(0, 32)}';

  @override
  bool owns(String path) {
    final String normalized = path.replaceAll('\\', '/');
    return normalized.contains('/$folder/') &&
        normalized.toLowerCase().endsWith('.jpg') &&
        !normalized.contains('/../');
  }

  Future<Directory> _draftDirectory(String draftKey) async {
    final root = await _rootDirectory();
    return Directory(
      '${root.path}${Platform.pathSeparator}${folderFor(draftKey)}',
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
