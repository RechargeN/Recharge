import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/offline_account_store.dart';

/// Whose saved list to read from this phone.
///
/// With a server Session `getCurrentUser()` is a server read and fails offline
/// (A34 2026-11-22), so the kept profile names the owner. It is only a key of
/// local data, never an authority for a server operation.
Future<String?> savedOwnerId({
  required bool serverAuth,
  required AuthRepository auth,
  required OfflineAccountStore account,
}) async => serverAuth
    ? (await account.readOfflineProfile())?.id
    : (await auth.getCurrentUser())?.id;
