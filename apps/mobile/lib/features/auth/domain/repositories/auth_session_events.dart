abstract interface class AuthSessionEvents {
  /// The SDK user no longer matches the sign-in. Nothing is confirmed by it:
  /// the phone signs out and no cache is wiped.
  Stream<void> get invalidated;

  /// The server said that access ended: the Session is revoked or the account
  /// is blocked (owner decision 2026-11-21 #5). Only this wipes the cache.
  Stream<void> get accessEnded;
}
