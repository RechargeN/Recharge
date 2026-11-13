import 'dart:convert';
import 'dart:io';

/// JSON-list disk IO shared by the existing typed Place/Activity journals.
/// Codecs, ownership matching and record shape remain in their typed wrappers.
final class PublicationJournalFile<T> {
  const PublicationJournalFile(
    this.file, {
    required this.decode,
    required this.encode,
    required this.maxRecords,
  });
  final File file;
  final T? Function(Object?) decode;
  final Map<String, Object?> Function(T) encode;
  final int maxRecords;

  Future<List<T>> read() async {
    if (!await file.exists()) return <T>[];
    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return <T>[];
      return decoded.map(decode).whereType<T>().toList();
    } on FormatException {
      return <T>[];
    }
  }

  Future<void> write(List<T> records) async {
    await file.parent.create(recursive: true);
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(records.take(maxRecords).map(encode).toList()),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}
