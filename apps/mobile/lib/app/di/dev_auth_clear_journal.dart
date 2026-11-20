import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Debug-only ring journal of local sign-in wipes (A34 staging 2026-11-16).
/// Kept in the app's private support directory, at most 40 lines, readable by
/// `adb shell run-as <package> cat files/auth-clear-journal.txt` on a debug
/// build. Holds code locations and booleans only.
final class DevAuthClearJournal {
  DevAuthClearJournal._(this._file);

  static Future<DevAuthClearJournal> open() async {
    final Directory support = await getApplicationSupportDirectory();
    return DevAuthClearJournal._(
      File('${support.path}${Platform.pathSeparator}auth-clear-journal.txt'),
    );
  }

  final File _file;
  static const int _maxLines = 40;

  void record(String entry) {
    try {
      final List<String> lines = _file.existsSync()
          ? _file.readAsLinesSync()
          : <String>[];
      lines.add('${DateTime.now().toUtc().toIso8601String()} $entry');
      final List<String> kept = lines.length > _maxLines
          ? lines.sublist(lines.length - _maxLines)
          : lines;
      _file.writeAsStringSync('${kept.join('\n')}\n', flush: true);
    } catch (_) {
      /* Diagnostics never block authentication. */
    }
  }
}
