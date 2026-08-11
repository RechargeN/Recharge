import '../../../../core/identity/account_experience.dart';
import '../../domain/entities/admin_experience_preview.dart';
import '../../domain/entities/identity_access_snapshot.dart';
import '../../domain/entities/page_limit_increase_request_entity.dart';
import '../../domain/entities/workspace_ref.dart';

enum IdentityWorkspaceStatus {
  initial,
  loading,
  ready,
  switching,
  creatingPage,
  requestingLimit,
  error,
}

class IdentityWorkspaceState {
  const IdentityWorkspaceState({
    required this.status,
    required this.userId,
    required this.accessSnapshot,
    required this.activeWorkspace,
    required this.adminPreview,
    required this.pendingLimitRequest,
    required this.message,
  });

  factory IdentityWorkspaceState.initial() {
    return const IdentityWorkspaceState(
      status: IdentityWorkspaceStatus.initial,
      userId: '',
      accessSnapshot: null,
      activeWorkspace: null,
      adminPreview: null,
      pendingLimitRequest: null,
      message: null,
    );
  }

  final IdentityWorkspaceStatus status;
  final String userId;
  final IdentityAccessSnapshot? accessSnapshot;
  final WorkspaceRef? activeWorkspace;
  final AdminExperiencePreview? adminPreview;
  final PageLimitIncreaseRequestEntity? pendingLimitRequest;
  final String? message;

  bool get isLoaded =>
      status == IdentityWorkspaceStatus.ready ||
      status == IdentityWorkspaceStatus.switching ||
      status == IdentityWorkspaceStatus.creatingPage ||
      status == IdentityWorkspaceStatus.requestingLimit;

  bool get isSwitching => status == IdentityWorkspaceStatus.switching;
  bool get isBusy =>
      status == IdentityWorkspaceStatus.switching ||
      status == IdentityWorkspaceStatus.creatingPage ||
      status == IdentityWorkspaceStatus.requestingLimit;

  AccountExperience get effectiveExperience {
    if (activeWorkspace?.isPage ?? false) {
      return AccountExperience.professionalPage;
    }
    if (adminPreview != null) return adminPreview!.experience;
    return accessSnapshot?.isVerifiedCreator ?? false
        ? AccountExperience.creator
        : AccountExperience.viewer;
  }

  IdentityWorkspaceState copyWith({
    IdentityWorkspaceStatus? status,
    String? userId,
    IdentityAccessSnapshot? accessSnapshot,
    WorkspaceRef? activeWorkspace,
    AdminExperiencePreview? adminPreview,
    bool clearAdminPreview = false,
    PageLimitIncreaseRequestEntity? pendingLimitRequest,
    bool clearPendingLimitRequest = false,
    String? message,
    bool clearMessage = false,
  }) {
    return IdentityWorkspaceState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      accessSnapshot: accessSnapshot ?? this.accessSnapshot,
      activeWorkspace: activeWorkspace ?? this.activeWorkspace,
      adminPreview: clearAdminPreview
          ? null
          : (adminPreview ?? this.adminPreview),
      pendingLimitRequest: clearPendingLimitRequest
          ? null
          : (pendingLimitRequest ?? this.pendingLimitRequest),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

extension on AdminExperiencePreview {
  AccountExperience get experience => switch (this) {
    AdminExperiencePreview.viewer => AccountExperience.viewer,
    AdminExperiencePreview.creator => AccountExperience.creator,
    AdminExperiencePreview.professionalPage =>
      AccountExperience.professionalPage,
  };
}
