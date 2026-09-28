import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/market_config.dart';
import '../../../app/di/service_locator.dart';
import '../../../core/notifications/app_notification_sink.dart';
import '../../../core/telemetry/analytics_service.dart';
import '../domain/repositories/managed_page_field_moderation_repository.dart';
import '../domain/repositories/team_invitation_repository.dart';
import '../domain/usecases/create_professional_page_usecase.dart';
import '../domain/usecases/load_identity_workspace_usecase.dart';
import '../domain/usecases/request_page_limit_increase_usecase.dart';
import '../domain/usecases/revoke_team_invitation_usecase.dart';
import '../domain/usecases/select_workspace_usecase.dart';
import '../domain/usecases/send_team_invitation_usecase.dart';
import '../domain/usecases/submit_managed_page_field_edit_usecase.dart';
import 'controllers/identity_workspace_controller.dart';
import 'controllers/managed_page_profile_editor_controller.dart';
import 'controllers/public_professional_page_controller.dart';
import 'controllers/team_invitation_controller.dart';

final identityWorkspaceControllerProvider =
    ChangeNotifierProvider<IdentityWorkspaceController>((ref) {
      return IdentityWorkspaceController(
        loadIdentityWorkspaceUseCase: sl<LoadIdentityWorkspaceUseCase>(),
        selectWorkspaceUseCase: sl<SelectWorkspaceUseCase>(),
        createProfessionalPageUseCase: sl<CreateProfessionalPageUseCase>(),
        requestPageLimitIncreaseUseCase: sl<RequestPageLimitIncreaseUseCase>(),
        notificationSink: sl<AppNotificationSink>(),
        marketConfig: sl<MarketConfig>(),
        analyticsService: sl<AnalyticsService>(),
      );
    });

final publicProfessionalPageControllerProvider =
    ChangeNotifierProvider.autoDispose<PublicProfessionalPageController>((ref) {
      return PublicProfessionalPageController(
        resolvePage: sl(),
        loadIdentityWorkspace: sl(),
      );
    });

final teamInvitationControllerProvider =
    ChangeNotifierProvider.autoDispose<TeamInvitationController>((ref) {
      return TeamInvitationController(
        invitationRepository: sl<TeamInvitationRepository>(),
        sendUseCase: sl<SendTeamInvitationUseCase>(),
        revokeUseCase: sl<RevokeTeamInvitationUseCase>(),
      );
    });

final managedPageProfileEditorControllerProvider =
    ChangeNotifierProvider.autoDispose<ManagedPageProfileEditorController>((
      ref,
    ) {
      return ManagedPageProfileEditorController(
        moderationRepository: sl<ManagedPageFieldModerationRepository>(),
        submitUseCase: sl<SubmitManagedPageFieldEditUseCase>(),
      );
    });
