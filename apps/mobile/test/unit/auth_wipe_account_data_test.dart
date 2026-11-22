import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/auth/data/datasources/auth_local_datasource.dart';

// Owner 2026-11-22 (decision 2026-11-21 #5): only copies of server data are
// wiped. The user's own work is irreplaceable and stays on the phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const id = '018FQ2Z8Q9N4M7K2T6V3W1X5YA';
  final encoded = base64Url.encode(utf8.encode(id));
  final unpadded = encoded.replaceAll('=', '');

  final copies = <String>[
    'auth.staging.recharge-staging-y9y2y.offlineProfile',
    'notifications_items_$id',
    'identity_active_workspace_$id',
    'identity_managed_pages_$id',
  ];
  final kept = <String>[
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
    // Another account whose id starts with the same characters.
    'notifications_items_${id}B',
    'identity_active_workspace_${id}B',
  ];

  test('the wipe removes the server copies and nothing else', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      for (final key in <String>[...copies, ...kept]) key: 'value',
    });
    const storage = FlutterSecureStorage();

    await const AuthLocalDataSource(
      storage,
      environment: AuthCacheEnvironment.staging,
    ).wipeAccountData(id);

    final left = (await storage.readAll()).keys.toSet();
    expect(left, kept.toSet());
  });

  test('without an account id nothing is removed', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      for (final key in kept) key: 'value',
    });
    const storage = FlutterSecureStorage();

    await const AuthLocalDataSource(storage).wipeAccountData('');

    expect((await storage.readAll()).keys.toSet(), kept.toSet());
  });
}
