abstract interface class AuthSessionEvents {
  /// The SDK user no longer matches the sign-in. Nothing is confirmed by it:
  /// the phone signs out.
  Stream<void> get invalidated;

  /// The server said that access ended: the Session is revoked or the account
  /// is blocked. The phone signs out and forgets the offline profile; owner
  /// 2026-11-23 removed every wipe, so nothing else is deleted.
  Stream<void> get accessEnded;
}
