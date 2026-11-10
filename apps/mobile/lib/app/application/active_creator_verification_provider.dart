import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/identity/application/identity_workspace_providers.dart';
import '../../features/identity/domain/entities/identity_access_snapshot.dart';
import '../../features/identity/domain/usecases/load_identity_workspace_usecase.dart';
import '../di/service_locator.dart';

final activeIdentityAccessProvider = Provider<IdentityAccessSnapshot?>((ref) {
  if (!sl.isRegistered<LoadIdentityWorkspaceUseCase>()) return null;
  final state = ref.watch(identityWorkspaceControllerProvider).state;
  final actor = sl.isRegistered<GetCurrentUserUseCase>()
      ? ref.watch(authControllerProvider).state.user?.id
      : state.userId;
  if (!state.isLoaded ||
      state.userId != actor ||
      !(state.accessSnapshot?.belongsTo(state.userId) ?? false)) {
    return null;
  }
  return state.accessSnapshot;
});
final activeCreatorVerificationProvider = Provider<bool>(
  (ref) => ref.watch(activeIdentityAccessProvider)?.isVerifiedCreator ?? false,
);
final activeCreateCapabilitiesProvider = Provider<List<String>>(
  (ref) =>
      ref.watch(activeIdentityAccessProvider)?.globalCapabilities.toList() ??
      const [],
);
