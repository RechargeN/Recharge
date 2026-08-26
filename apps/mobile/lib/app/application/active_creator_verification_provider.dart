import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/identity/application/identity_workspace_providers.dart';
import '../di/service_locator.dart';
import '../../features/identity/domain/usecases/load_identity_workspace_usecase.dart';

/// App-level composition bridge between Identity verification state and
/// Create (RNT-PUB-01 §1.4) — mirrors `active_create_publisher_provider.dart`.
/// `features/create` never imports `features/identity` directly; it reads
/// only this primitive `bool` through `create_page.dart`.
final activeCreatorVerificationProvider = Provider<bool>((ref) {
  if (!sl.isRegistered<LoadIdentityWorkspaceUseCase>()) return false;
  return ref
          .watch(identityWorkspaceControllerProvider)
          .state
          .accessSnapshot
          ?.isVerifiedCreator ??
      false;
});
