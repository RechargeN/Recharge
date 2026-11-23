import '../entities/auth_user_entity.dart';

/// Round 1 (owner decision 2026-11-21, item 4): what the phone keeps about the
/// signed-in account between launches, and how it forgets it. Owner 2026-11-23:
/// no end of sign-in wipes anything else on the phone.
///
/// The offline profile holds the account id and e-mail only (no role, no
/// capabilities), so it never grants a server operation by itself.
abstract interface class OfflineAccountStore {
  Future<void> saveOfflineProfile(AuthUserEntity user);

  /// The kept profile, without role or capabilities; `null` when none.
  Future<AuthUserEntity?> readOfflineProfile();

  /// Any end of sign-in, a confirmed end of access included: forget the
  /// profile only.
  Future<void> clearOfflineProfile();
}
