// L4.7: PNG screenshots of the localized screens for the native-speaker
// review (G06). Not goldens: nothing is compared or committed.
//
// Usage (from apps/mobile):
//   dart run tool/l10n_screenshots.dart <output-dir>
//
// Runs the lv/en/ru 360 dp widget tests with
// `--dart-define=L10N_SHOTS_DIR=<output-dir>`; each of them saves the screen
// (and every scrolled screenful) at text scale 1x and 2x. The output must lie
// outside the repository.
import 'dart:io';

/// The tests that render screens in every UI language at 360 dp.
const List<String> screenTests = <String>[
  'test/widget/settings_page_test.dart',
  'test/widget/event_booking_section_test.dart',
  'test/widget/local_import_section_test.dart',
  'test/widget/notifications_page_test.dart',
  'test/widget/create_blocks_small_screen_test.dart',
  'test/widget/collection_create_block_test.dart',
  'test/widget/search_page_test.dart',
  'test/widget/discover_details_page_test.dart',
  'test/widget/profile_page_test.dart',
  'test/widget/workspace_section_test.dart',
  'test/widget/team_invitations_card_test.dart',
  'test/widget/scenario_builder_page_test.dart',
  'test/widget/favorites_page_test.dart',
  'test/widget/visited_places_page_test.dart',
];

Directory? _repoRoot(Directory start) {
  Directory dir = start.absolute;
  while (true) {
    if (FileSystemEntity.typeSync('${dir.path}/.git') !=
        FileSystemEntityType.notFound) {
      return dir;
    }
    if (dir.parent.path == dir.path) return null;
    dir = dir.parent;
  }
}

bool _isInside(String path, Directory root) {
  String norm(String p) => p.replaceAll(r'\', '/').toLowerCase();
  final String target = norm(Directory(path).absolute.path);
  final String base = norm(root.absolute.path);
  return target == base || target.startsWith('$base/');
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/l10n_screenshots.dart <output-dir>');
    exitCode = 64;
    return;
  }
  final String output = Directory(args.single).absolute.path;
  final Directory? root = _repoRoot(Directory.current);
  if (root != null && _isInside(output, root)) {
    stderr.writeln(
      'refusing to write inside the repository (${root.path}); '
      'review screenshots are never committed',
    );
    exitCode = 65;
    return;
  }
  Directory(output).createSync(recursive: true);
  final Process process = await Process.start(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    <String>[
      'test',
      '--plain-name',
      ' dp',
      '--dart-define=L10N_SHOTS_DIR=$output',
      ...screenTests,
    ],
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  exitCode = await process.exitCode;
  final int count = Directory(output)
      .listSync()
      .whereType<File>()
      .where((File file) => file.path.endsWith('.png'))
      .length;
  stdout.writeln('$count screenshots in $output');
}
