# Changelog

## 0.2.1 — 2026-08-27

- Corrected the pre-runtime Booking v1 command schema to a closed nine-variant
  discriminated union without renaming commands, results or errors.
- Aligned JSON Schema and Dart validation for command-local payload fields,
  `expectedBookingRevision`, null-versus-absent handling and bounded values.
- Implemented Accepted ECL03-D12 request-ID validation: exact, case-sensitive,
  non-normalizing, 1–128 Unicode scalar values and the frozen v1 blank set.
- Added cross-consumer valid/invalid fixtures, recursive authority-injection
  rejection and an explicit Draft 2020-12 keyword gate.
- Compatibility audit found no deployed endpoint, stored command log or
  supported producer. The only non-package reader is the non-product R0
  TypeScript contract-read test, so this remains a corrective Booking wire v1
  patch rather than a deployed migration.
- Frozen LF-normalized SHA-256 evidence:
  `booking_command.schema.json`
  `7267d3931a6bb6536363c2324fe94cceccf827164c829aa32ff6d96ced1f8864`,
  `valid.json`
  `63fd0d4ec8fe4d9c2e2b6040e281b787045f7d3036c3c0d04bc0fa797e380a58`,
  `invalid.json`
  `1ed7f3d28ef7c388a40031c14ca6e34fbcf02ef6f2e6b2a8e94b783557f46cf4`
  and unchanged `forward.json`
  `73e9609881d8be71712a19230451138ca99bbdb941ce8eea27fe62bcf303cb07`.
- This release adds no backend, Firebase, mobile adapter or Booking runtime.
