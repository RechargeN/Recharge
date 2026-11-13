# Changelog

## 0.3.0 — 2026-08-27

- Added closed Booking v1 query, single-read, live-keyset page and
  non-reserving availability schemas. Requests remain actor-free; not-found is
  enumeration-safe; non-authoritative availability cannot expose reservable
  units.
- Bounded revisions and recursively hashed numbers to the cross-language safe
  integer range. Added independent test-only Dart and TypeScript
  `booking_semantic_hash_v1` implementations with duplicate-key and unpaired
  surrogate rejection before ordinary decoding.
- Replaced parse-only TypeScript evidence with Ajv 8.20.0 Draft 2020-12
  validation and pinned ajv-formats 3.0.1. Dart uses crypto 3.0.7 as an exact
  test-only dev dependency. Package gates pass 20 Dart tests and 10 Node
  contract tests.
- Frozen LF-normalized SHA-256 schema evidence:
  `booking_availability.schema.json`
  `17d9e21129d715e5458bebf3d6f274e302f8bf4fdae14e709a19e65494012951`,
  `booking_command.schema.json`
  `7267d3931a6bb6536363c2324fe94cceccf827164c829aa32ff6d96ced1f8864`,
  `booking_error.schema.json`
  `804dcb8fda9c26ae4e0a14db347b587d325bd5932027a3df9b3f54266f80c940`,
  `booking_hold.schema.json`
  `e9dd24519af4a4f597c9df13382a9b01307fb0755e4e70b9e0655ee1d45986b4`,
  `booking_page.schema.json`
  `0d57d259752d5fa4f0ef4e994137b9815f3f2ec944b831fad9ceb728be2269ad`,
  `booking_policy.schema.json`
  `f1d0e0972de15bb49f117b64092ea34920bc153bf758a6bed7948915d5f2bf5c`,
  `booking_query.schema.json`
  `a8bebdd3b016a872855b048dae90079607ea52efbd54183549f0640893236866`,
  `booking_read.schema.json`
  `1bd2ceeaf48bae830f4da2adddedbdf45ca0aedd060af6a2c1be89c800de2511`,
  `booking_result.schema.json`
  `ec6871df642e45e6761af5566bb14e3065e689502f105c409a3137aa3184b02e`,
  `booking.schema.json`
  `9280a0d9cdd7c2cc9094c0cc084da66c8f4af026c8fd02c2e405188c93bc0cfc`
  and `common.schema.json`
  `415b8b85f74c51f50e933f7fb947940f4b8132f21cbc72c58b98c965f17035f0`.
- Frozen LF-normalized SHA-256 fixture evidence:
  `forward.json`
  `73e9609881d8be71712a19230451138ca99bbdb941ce8eea27fe62bcf303cb07`,
  `invalid.json`
  `1ed7f3d28ef7c388a40031c14ca6e34fbcf02ef6f2e6b2a8e94b783557f46cf4`,
  `query_forward.json`
  `8b19e93074a8350d03e1b525e298c83373895799fdec85a828df4e70ac197d2e`,
  `query_invalid.json`
  `f6497afa6e14ed3ddce093aabf808df92c9538ec8c13f473214f37fcfeecfa14`,
  `query_valid.json`
  `9254f8593215d634e97ae6cb535ca93bfc1a9750726285116038d62cec6bc4bd`,
  `semantic_hash_invalid.json`
  `1e115f23dfbae97790d5f44268c71e6c8dd9b11e1a093c245ae952f3aaeb6d26`,
  `semantic_hash_vectors.json`
  `16173a3c0a214eb6d9e40daa7ae24c9b01e5fef74b0404fa3466ea4dc48787bd`
  and `valid.json`
  `63fd0d4ec8fe4d9c2e2b6040e281b787045f7d3036c3c0d04bc0fa797e380a58`.
- No backend source export, Firebase resource, callable, deployment, mobile
  adapter or Booking runtime is included.

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
