import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// L4.7: PNG screenshots for the native-speaker review (G06), not goldens.
///
/// Off unless the run passes `--dart-define=L10N_SHOTS_DIR=<dir>` (see
/// `tool/l10n_screenshots.dart`); then every [l10nCaptureScreen] call writes
/// `<dir>/<test description>[-<suffix>].png`. The directory must lie outside
/// the repository, and nothing is compared: a screenshot never fails a test.
const String l10nShotsDir = String.fromEnvironment('L10N_SHOTS_DIR');

bool _fontsLoaded = false;
final Set<String> _captured = <String>{};

/// The Flutter SDK root of the running `flutter_tester`.
Directory? _flutterRoot() {
  final String? env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return Directory(env);
  Directory dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (Directory(
      '${dir.path}/bin/cache/artifacts/material_fonts',
    ).existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  return null;
}

/// Real Roboto and Material Icons instead of the test font, so the review
/// sees readable lv/ru text and icons.
Future<void> _loadFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final Directory? root = _flutterRoot();
  if (root == null) return;
  final String fonts = '${root.path}/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(File('$fonts/$name').readAsBytesSync());
  final FontLoader roboto = FontLoader('Roboto');
  for (final String name in <String>[
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    if (File('$fonts/$name').existsSync()) roboto.addFont(read(name));
  }
  await roboto.load();
  if (File('$fonts/materialicons-regular.otf').existsSync()) {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(read('materialicons-regular.otf'))).load();
  }
}

String _fileName(String description, String? suffix) {
  final String base = description
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp('_+'), '_');
  return suffix == null ? '$base.png' : '${base}_$suffix.png';
}

/// Saves the screen unless this test already saved one.
Future<void> l10nCaptureIfNone(WidgetTester tester) async {
  if (_captured.contains(tester.testDescription)) return;
  await l10nCaptureScreen(tester);
}

/// Writes the current screen of [tester] when [l10nShotsDir] is set.
Future<void> l10nCaptureScreen(WidgetTester tester, {String? suffix}) async {
  if (l10nShotsDir.isEmpty) return;
  // A platform view (the map) cannot be created in a widget test; letting
  // real async work run would fail the test, so such screens are listed
  // instead of saved.
  if (find.byType(PlatformViewLink).evaluate().isNotEmpty ||
      find.byType(AndroidView).evaluate().isNotEmpty) {
    _captured.add(tester.testDescription);
    File('$l10nShotsDir/_skipped_platform_view.txt')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('${tester.testDescription}\n', mode: FileMode.append);
    return;
  }
  // Loading a font notifies the system-font listeners, so text lays out
  // again with the real glyphs on the next frame.
  await tester.runAsync(_loadFonts);
  await tester.pumpAndSettle();
  final Finder boundary = find.byType(RepaintBoundary);
  if (boundary.evaluate().isEmpty) return;
  final RenderRepaintBoundary render = tester
      .renderObject<RenderRepaintBoundary>(boundary.first);
  await tester.runAsync(() async {
    final ui.Image image = await render.toImage();
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (png == null) return;
    final File file = File(
      '$l10nShotsDir/${_fileName(tester.testDescription, suffix)}',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png.buffer.asUint8List());
    _captured.add(tester.testDescription);
  });
}
