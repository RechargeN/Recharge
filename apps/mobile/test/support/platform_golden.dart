import 'dart:io';

/// Selects reviewed host references without changing the golden comparator.
///
/// Unknown hosts fail explicitly; they must not silently use another host's
/// rasterization reference. Paths remain relative to the calling test.
String platformGoldenPath(String path) {
  if (Platform.isWindows) return path;
  if (Platform.isLinux) return path.replaceFirst('goldens/', 'goldens/linux/');
  throw UnsupportedError(
    'Golden references are reviewed only for Windows and Linux; '
    'host is ${Platform.operatingSystem}.',
  );
}
