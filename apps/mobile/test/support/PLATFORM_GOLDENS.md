# Platform golden references

The same widgets are checked with Flutter's default exact comparator on
Windows and Linux. platformGoldenPath selects the sibling linux/ directory
on Linux and the original path on Windows. Other hosts throw UnsupportedError;
there is no silent fallback, skip, comparison tolerance or automatic update.

Toolchain: Flutter 3.44.9 / Dart 3.12.2, as pinned in repository CI.
Fonts: SDK material_fonts archive
3012db47f3130e62f7cc0beabff968a33cbec8d8, using its case-correct filenames.

## Provenance and review

The user authorized the seventeen-file platform-reference scope on 2026-11-10.
All eight master/test pairs and isolated differences were inspected.
Windows reference files are retained byte-for-byte.

Seven Linux references are the reviewed test images from GitHub Actions
run 42675507454, head 76d462d, artifact 13700640503. Archive SHA-256:
ed8a2cba0ade772d8ed26a930a60633b80371275629eae988d601f02e498d860.
Content, prices, wrapping and card layout match their Windows counterparts;
differences are in glyph/icon rasterization. The repeated preceding Linux
run had identical differing-pixel counts; the Route output is byte-identical.

Activity is different: its legacy display helper uses host-local time, so the
old Linux output shows 07:00 while Windows shows 10:00. That Linux output was
rejected. The visual fixture now explicitly creates local 10:00 and supplies
its UTC instant, with a separate text assertion. This makes visual content
stable without changing product timezone behavior or claiming zoned-schedule
acceptance. The Linux Activity reference currently uses the original Windows
image as a content-correct provisional reference; its new Linux rasterization
must be inspected and recorded before this checkpoint can pass.

## Updating references

Review changes in content/layout separately from platform rasterization.
Keep a fixed viewport and deterministic fixtures. A failure is not permission
to replace expected output. Inspect master/test/diff, record provenance and
then rerun the entire suite, analyze, boundary and diff gates on both verified
hosts. A focused pass or an update-goldens run does not constitute acceptance.

This policy covers test rendering only: no Emulator/device/cloud evidence,
runtime authority, product timezone policy or automatic status promotion.
