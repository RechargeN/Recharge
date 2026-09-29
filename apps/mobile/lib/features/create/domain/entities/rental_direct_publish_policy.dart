/// RNT-PUB-01 §1.3. Bounded local/mock trusted-policy source, injected into
/// `CreateController` rather than read from a hardcoded singleton — the
/// safe default (`isTrusted: false`) means direct-publish is never
/// authorized unless a caller explicitly opts in. Local/mock DI composition
/// (`create_providers.dart`) passes `isTrusted: true` explicitly; this
/// class has no other logic today, but keeps the door open for a future
/// market/category-dependent policy without changing the resolver.
class RentalDirectPublishPolicy {
  const RentalDirectPublishPolicy({this.isTrusted = false});

  final bool isTrusted;
}
