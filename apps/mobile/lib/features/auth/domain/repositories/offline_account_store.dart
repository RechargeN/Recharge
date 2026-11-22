import '../entities/auth_user_entity.dart';

/// Round 1 (owner decisions 2026-11-21, items 4-5): what the phone keeps about
/// the signed-in account between launches, and how it forgets it.
///
/// The offline profile holds the account id and e-mail only (no role, no
/// capabilities), so it never grants a server operation by itself.
abstract interface class OfflineAccountStore {
  Future<void> saveOfflineProfile(AuthUserEntity user);

  /// The kept profile, without role or capabilities; `null` when none.
  Future<AuthUserEntity?> readOfflineProfile();

  /// Sign-out or a missing Session: forget the profile only.
  Future<void> clearOfflineProfile();

  /// A server-confirmed end of access: also wipe the copies of server data
  /// (inbox, workspace, page copies). Never the user's own work (drafts,
  /// templates, photos, recordings, favorites, visits, unsent operations).
  Future<void> wipeAccountData(String userId);
}
