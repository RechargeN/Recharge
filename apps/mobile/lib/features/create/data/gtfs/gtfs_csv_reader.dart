import 'dart:convert';

class GtfsCsvTable {
  const GtfsCsvTable(this.fileName, this.headers, this.rows);

  final String fileName;
  final List<String> headers;
  final List<Map<String, String>> rows;
}

class GtfsCsvReader {
  const GtfsCsvReader({this.maxRowsPerFile = 3000000});

  final int maxRowsPerFile;

  GtfsCsvTable read(String fileName, List<int> bytes) {
    final rows = <Map<String, String>>[];
    final headers = visitRows(fileName, bytes, (row, _) => rows.add(row));
    return GtfsCsvTable(
      fileName,
      headers,
      List<Map<String, String>>.unmodifiable(rows),
    );
  }

  List<String> visitRows(
    String fileName,
    List<int> bytes,
    void Function(Map<String, String> row, int zeroBasedIndex) visitor,
  ) {
    String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      throw FormatException('$fileName must be valid UTF-8.');
    }
    if (source.startsWith('\uFEFF')) {
      source = source.substring(1);
    }

    List<String>? headers;
    var rowCount = 0;
    _visitRecords(source, fileName, (values) {
      if (headers == null) {
        final normalized = values.map((value) => value.trim()).toList();
        if (normalized.isEmpty || normalized.any((value) => value.isEmpty)) {
          throw FormatException('$fileName contains an empty header.');
        }
        if (normalized.toSet().length != normalized.length) {
          throw FormatException('$fileName contains duplicate headers.');
        }
        headers = List<String>.unmodifiable(normalized);
        return;
      }
      if (values.length == 1 && values.single.isEmpty) return;
      if (values.length != headers!.length) {
        throw FormatException(
          '$fileName row ${rowCount + 2} has ${values.length} fields; '
          'expected ${headers!.length}.',
        );
      }
      if (rowCount >= maxRowsPerFile) {
        throw FormatException('$fileName exceeds the row limit.');
      }
      visitor(<String, String>{
        for (var index = 0; index < headers!.length; index++)
          headers![index]: values[index].trim(),
      }, rowCount);
      rowCount++;
    });
    if (headers == null) {
      throw FormatException('$fileName is empty.');
    }
    return headers!;
  }

  void _visitRecords(
    String source,
    String fileName,
    void Function(List<String> values) visitor,
  ) {
    var record = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var quoteClosed = false;

    void finishField() {
      record.add(field.toString());
      field.clear();
      quoteClosed = false;
    }

    void finishRecord() {
      finishField();
      visitor(List<String>.unmodifiable(record));
      record = <String>[];
    }

    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (inQuotes) {
        if (char == '"') {
          if (index + 1 < source.length && source[index + 1] == '"') {
            field.write('"');
            index++;
          } else {
            inQuotes = false;
            quoteClosed = true;
          }
        } else {
          field.write(char);
        }
        continue;
      }

      if (quoteClosed && char != ',' && char != '\r' && char != '\n') {
        throw FormatException(
          '$fileName has unexpected text after a closing quote.',
        );
      }
      if (char == '"' && field.isEmpty && !quoteClosed) {
        inQuotes = true;
      } else if (char == ',') {
        finishField();
      } else if (char == '\r' || char == '\n') {
        if (char == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') {
          index++;
        }
        finishRecord();
      } else {
        field.write(char);
      }
    }
    if (inQuotes) {
      throw FormatException('$fileName contains an unclosed quoted field.');
    }
    if (field.isNotEmpty || record.isNotEmpty || quoteClosed) {
      finishRecord();
    }
  }
}
