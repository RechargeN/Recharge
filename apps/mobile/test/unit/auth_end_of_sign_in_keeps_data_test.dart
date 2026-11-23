import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/auth/data/datasources/auth_local_datasource.dart';

// Owner 2026-11-23 ("Всё стирание из кода"): no end of sign-in wipes anything
// on the phone. Sign-out, a revoked Session and a blocked account all forget
// the offline profile only; every other key stays.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const id = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';
  final encoded = base64Url.encode(utf8.encode(id));
  final unpadded = encoded.replaceAll('=', '');
  const profile = 'auth.staging.recharge-staging-y9y2y.offlineProfile';

  final kept = <String>[
    // Copies of server data: no longer wiped.
    'notifications_items_$id',
    'identity_active_workspace_$id',
    'identity_managed_pages_$id',
    'favorites_saved_copy_v1_$encoded',
    // The user's own work.
    'create_draft_$id',
    'create_templates_v1_$id',
    'create_draft_collection_v1_${unpadded}_index',
    'create_draft_collection_v1_${unpadded}_draft_one',
    'scenario_intake_v1_$unpadded',
    'favorites_items_v2_$encoded',
    'visit_history_v3_$encoded',
    'explore_profile_$id',
    'explore_settings_$id',
    'library_pending_v1_$encoded',
    'route_gps_journal_master_key_v1',
    'rental_private_v1_draft-1',
  ];

  test(
    'an end of sign-in forgets the offline profile and nothing else',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        profile: 'value',
        for (final key in kept) key: 'value',
      });
      const storage = FlutterSecureStorage();

      await const AuthLocalDataSource(
        storage,
        environment: AuthCacheEnvironment.staging,
      ).clearOfflineProfile();

      expect((await storage.readAll()).keys.toSet(), kept.toSet());
    },
  );
}
