/// Owner 2026-11-23: "Sign out on all devices". The server ends every Session
/// of the account; this phone signs out. Nothing on the phone is wiped.
abstract interface class SignOutEverywhere {
  Future<void> signOutEverywhere();
}
