import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../app/config/market_config.dart';
import '../../../../core/notifications/app_notification_sink.dart';
import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/admin_experience_preview.dart';
import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/page_limit_increase_request_entity.dart';
import '../../domain/entities/professional_page_creation_input.dart';
import '../../domain/entities/workspace_ref.dart';
import '../../domain/repositories/identity_workspace_repository.dart';
import '../../domain/usecases/create_professional_page_usecase.dart';
import '../../domain/usecases/load_identity_workspace_usecase.dart';
import '../../domain/usecases/request_page_limit_increase_usecase.dart';
import '../../domain/usecases/select_workspace_usecase.dart';
import '../state/identity_workspace_state.dart';

class IdentityWorkspaceController extends ChangeNotifier {
  IdentityWorkspaceController({
    required LoadIdentityWorkspaceUseCase loadIdentityWorkspaceUseCase,
    required SelectWorkspaceUseCase selectWorkspaceUseCase,
    required CreateProfessionalPageUseCase createProfessionalPageUseCase,
    required RequestPageLimitIncreaseUseCase requestPageLimitIncreaseUseCase,
    required AppNotificationSink notificationSink,
    required MarketConfig marketConfig,
    required AnalyticsService analyticsService,
  }) : _loadIdentityWorkspaceUseCase = loadIdentityWorkspaceUseCase,
       _selectWorkspaceUseCase = selectWorkspaceUseCase,
       _createProfessionalPageUseCase = createProfessionalPageUseCase,
       _requestPageLimitIncreaseUseCase = requestPageLimitIncreaseUseCase,
       _notificationSink = notificationSink,
       _marketConfig = marketConfig,
       _analyticsService = analyticsService {
    _accessChanges = IdentityWorkspaceRepository.accessChanges.listen((actor) {
      if (actor == _state.userId) {
        // A write may invalidate access while an earlier read or command is
        // still in flight. Remove usable authority now and drain one fresh
        // read after that operation settles; never publish its stale snapshot.
        _pendingAccessRefresh = true;
        _setState(_state);
      }
    });
  }

  final LoadIdentityWorkspaceUseCase _loadIdentityWorkspaceUseCase;
  final SelectWorkspaceUseCase _selectWorkspaceUseCase;
  final CreateProfessionalPageUseCase _createProfessionalPageUseCase;
  final RequestPageLimitIncreaseUseCase _requestPageLimitIncreaseUseCase;
  final AppNotificationSink _notificationSink;
  final MarketConfig _marketConfig;
  final AnalyticsService _analyticsService;

  IdentityWorkspaceState _state = IdentityWorkspaceState.initial();
  IdentityWorkspaceState get state => _state;

  int _operationRevision = 0;
  late final StreamSubscription<String> _accessChanges;
  bool _disposed = false;
  String? _createRequestId;
  String? _createRequestInput;
  Future<bool>? _refresh;
  bool _pendingAccessRefresh = false;

  @override
  void dispose() {
    _disposed = true;
    _operationRevision++;
    unawaited(_accessChanges.cancel());
    super.dispose();
  }

  void clearSession() {
    _operationRevision++;
    _refresh = null;
    _pendingAccessRefresh = false;
    _createRequestId = null;
    _createRequestInput = null;
    _setState(IdentityWorkspaceState.initial());
  }

  bool _current(int revision, String actor) =>
      !_disposed && revision == _operationRevision && _state.userId == actor;

  Future<void> ensureLoaded(String userId) async {
    if (userId.trim().isEmpty) {
      clearSession();
      return;
    }
    if (_state.userId == userId && _state.isLoaded) return;

    if (_state.userId != userId) {
      _refresh = null;
      _pendingAccessRefresh = false;
    }

    _createRequestId = null;
    _createRequestInput = null;
    final int operationRevision = ++_operationRevision;
    _setState(
      IdentityWorkspaceState.initial().copyWith(
        status: IdentityWorkspaceStatus.loading,
        userId: userId,
        clearMessage: true,
      ),
    );

    try {
      final IdentityWorkspaceLoadResult result =
          await _loadIdentityWorkspaceUseCase(userId);
      if (operationRevision != _operationRevision) return;

      _setState(
        IdentityWorkspaceState(
          status: IdentityWorkspaceStatus.ready,
          userId: userId,
          accessSnapshot: result.accessSnapshot,
          activeWorkspace: result.activeWorkspace,
          adminPreview: null,
          pendingLimitRequest: result.pendingLimitRequest,
          message: result.recoveryReasonCode == null
              ? null
              : 'Недоступная страница сброшена на личный профиль',
        ),
      );
      _analyticsService.track(
        'identity_workspace_loaded',
        params: <String, Object?>{
          'user_id': userId,
          'workspace_type': result.activeWorkspace.type.name,
          'recovered': result.recoveryReasonCode != null,
        },
      );
    } on Object {
      if (operationRevision != _operationRevision) return;
      _setState(
        _state.copyWith(
          status: IdentityWorkspaceStatus.error,
          message: 'Не удалось загрузить рабочие профили',
        ),
      );
    }
  }

  /// IDP-05A: re-reads access and repairs a stale active workspace. A page
  /// whose membership was revoked or whose lifecycle left `active` drops the
  /// user back to the personal profile (fail-closed, preference repaired by
  /// the load use case). Returns `true` when the active workspace changed.
  Future<bool> revalidateAccess() {
    final pending = _refresh;
    if (pending != null) return pending;
    final result = _revalidateAccess();
    _refresh = result;
    return result.whenComplete(() {
      if (identical(_refresh, result)) {
        _refresh = null;
        _drainAccessRefresh();
      }
    });
  }

  Future<bool> _revalidateAccess() async {
    if (_state.userId.isEmpty || _state.isBusy) return false;
    final actor = _state.userId;
    final previous = _state;
    final int operationRevision = ++_operationRevision;
    _setState(
      IdentityWorkspaceState.initial().copyWith(
        userId: actor,
        status: IdentityWorkspaceStatus.loading,
      ),
    );
    try {
      final IdentityWorkspaceLoadResult result =
          await _loadIdentityWorkspaceUseCase(actor);
      if (operationRevision != _operationRevision) return false;
      final bool changed = result.activeWorkspace != previous.activeWorkspace;
      _setState(
        previous.copyWith(
          status: IdentityWorkspaceStatus.ready,
          accessSnapshot: result.accessSnapshot,
          activeWorkspace: result.activeWorkspace,
          pendingLimitRequest: result.pendingLimitRequest,
          clearPendingLimitRequest: result.pendingLimitRequest == null,
          clearAdminPreview:
              changed || !result.accessSnapshot.canPreviewExperience,
          message: result.recoveryReasonCode == null
              ? null
              : 'Недоступная страница сброшена на личный профиль',
          clearMessage: result.recoveryReasonCode == null,
        ),
      );
      return changed;
    } on Object {
      if (_current(operationRevision, actor)) {
        _setState(
          IdentityWorkspaceState.initial().copyWith(
            userId: actor,
            status: IdentityWorkspaceStatus.error,
            activeWorkspace: WorkspaceRef.personal(actor),
            message: 'Доступ недоступен. Повторите проверку.',
          ),
        );
      }
      return false;
    }
  }

  Future<bool> selectWorkspace(WorkspaceRef workspace) async {
    if (!_state.isLoaded || _state.userId.isEmpty || _state.isBusy) {
      return false;
    }

    final int operationRevision = ++_operationRevision;
    _setState(
      _state.copyWith(
        status: IdentityWorkspaceStatus.switching,
        clearMessage: true,
      ),
    );

    try {
      final WorkspaceRef selected = await _selectWorkspaceUseCase(
        userId: _state.userId,
        workspace: workspace,
      );
      if (operationRevision != _operationRevision) return false;

      _setState(
        _state.copyWith(
          status: IdentityWorkspaceStatus.ready,
          activeWorkspace: selected,
          clearAdminPreview: true,
          message: 'Рабочий профиль переключён',
        ),
      );
      _analyticsService.track(
        'identity_workspace_switched',
        params: <String, Object?>{
          'user_id': _state.userId,
          'workspace_type': selected.type.name,
          'workspace_id': selected.id,
        },
      );
      return true;
    } on WorkspaceSelectionException {
      if (operationRevision != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: IdentityWorkspaceStatus.ready,
          message: 'Доступ к выбранной странице недоступен',
        ),
      );
      return false;
    } on Object {
      if (operationRevision != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: IdentityWorkspaceStatus.ready,
          message: 'Не удалось переключить рабочий профиль',
        ),
      );
      return false;
    }
  }

  Future<bool> selectAdminPreview(AdminExperiencePreview preview) async {
    final actor = _state.userId;
    if (actor.isEmpty || _state.isBusy) return false;
    await revalidateAccess();
    if (_state.userId != actor) return false;
    final access = _state.accessSnapshot;
    if (_state.status != IdentityWorkspaceStatus.ready ||
        access == null ||
        !access.belongsTo(_state.userId) ||
        !access.canPreviewExperience) {
      return false;
    }
    _setState(
      _state.copyWith(
        adminPreview: preview,
        message: 'Admin preview: ${preview.name}',
      ),
    );
    _analyticsService.track(
      'identity_admin_experience_preview_selected',
      params: <String, Object?>{'experience': preview.name},
    );
    return true;
  }

  Future<bool> createProfessionalPage({
    required String displayName,
    required ManagedPageKind kind,
  }) async {
    if (_state.status != IdentityWorkspaceStatus.ready ||
        _state.userId.isEmpty) {
      return false;
    }
    final actor = _state.userId;
    final inputKey = '$actor:${kind.name}:${displayName.trim()}';
    if (_createRequestInput != inputKey) {
      _createRequestInput = inputKey;
      _createRequestId = _createProfessionalPageUseCase.newRequestId();
    }
    final int operationRevision = ++_operationRevision;
    _setState(
      _state.copyWith(
        status: IdentityWorkspaceStatus.creatingPage,
        clearMessage: true,
      ),
    );

    try {
      final ManagedPageEntity page = await _createProfessionalPageUseCase(
        userId: actor,
        requestId: _createRequestId,
        input: ProfessionalPageCreationInput(
          kind: kind,
          displayName: displayName,
          marketId: _marketConfig.marketCityId,
          countryCode: _marketConfig.countryCode,
          defaultLocale: _marketConfig.defaultLocaleCode,
          timezone: _marketConfig.timezoneId,
          defaultCurrency: _marketConfig.currencyCode,
          supportedLocales: _marketConfig.supportedLocaleCodes,
        ),
      );
      await _notifyPageCreated(page);
      if (!_current(operationRevision, actor)) return false;
      await _selectWorkspaceUseCase(
        userId: actor,
        workspace: WorkspaceRef.page(page.id),
      );
      if (!_current(operationRevision, actor)) return false;
      final IdentityWorkspaceLoadResult result =
          await _loadIdentityWorkspaceUseCase(actor);
      if (operationRevision != _operationRevision) return false;

      _createRequestId = null;
      _createRequestInput = null;
      _setState(
        IdentityWorkspaceState(
          status: IdentityWorkspaceStatus.ready,
          userId: actor,
          accessSnapshot: result.accessSnapshot,
          activeWorkspace: result.activeWorkspace,
          adminPreview: null,
          pendingLimitRequest: result.pendingLimitRequest,
          message: 'Professional Page создана и отправлена на проверку',
        ),
      );
      _analyticsService.track(
        'identity_professional_page_created',
        params: <String, Object?>{
          'page_id': page.id,
          'owned_page_count': result.accessSnapshot.ownedPages.length,
        },
      );
      return true;
    } on CreateProfessionalPageException catch (error) {
      if (operationRevision != _operationRevision) return false;
      final String message = error.code == 'self_service_page_limit_reached'
          ? 'Достигнут лимит 3 страниц. Отправьте заявку модераторам.'
          : 'Не удалось создать Professional Page';
      _setState(
        _state.copyWith(
          status: IdentityWorkspaceStatus.ready,
          message: message,
        ),
      );
      return false;
    } on Object {
      if (operationRevision != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: IdentityWorkspaceStatus.ready,
          message: 'Не удалось создать Professional Page',
        ),
      );
      return false;
    }
  }

  Future<bool> requestAdditionalPage() async {
    if (_state.status != IdentityWorkspaceStatus.ready ||
        _state.userId.isEmpty) {
      return false;
    }
    final int operationRevision = ++_operationRevision;
    _setState(
      _state.copyWith(
        status: IdentityWorkspaceStatus.requestingLimit,
        clearMessage: true,
      ),
    );

    try {
      final PageLimitIncreaseRequestEntity request =
          await _requestPageLimitIncreaseUseCase(_state.userId);
      await _notifyLimitRequest(request);
      if (operationRevision != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: IdentityWorkspaceStatus.ready,
          pendingLimitRequest: request,
          message: 'Заявка на дополнительную страницу отправлена',
        ),
      );
      _analyticsService.track(
        'identity_page_limit_request_submitted',
        params: <String, Object?>{'request_id': request.id},
      );
      return true;
    } on RequestPageLimitIncreaseException {
      if (operationRevision != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: IdentityWorkspaceStatus.ready,
          message: 'Заявка доступна после создания трёх страниц',
        ),
      );
      return false;
    } on Object {
      if (operationRevision != _operationRevision) return false;
      _setState(
        _state.copyWith(
          status: IdentityWorkspaceStatus.ready,
          message: 'Не удалось отправить заявку модераторам',
        ),
      );
      return false;
    }
  }

  Future<void> _notifyPageCreated(ManagedPageEntity page) async {
    final String route = '/settings/workspace';
    await _appendNotificationSafely(
      AppNotificationEvent(
        id: 'professional-page-created-${page.id}-user',
        audience: AppNotificationAudience.user,
        recipientUserId: page.ownerUserId,
        title: 'Professional Page создана',
        body: '${page.displayName}: статус проверки — Pending review.',
        createdAtUtc: page.createdAtUtc,
        targetRoute: route,
      ),
    );
    await _appendNotificationSafely(
      AppNotificationEvent(
        id: 'professional-page-created-${page.id}-moderators',
        audience: AppNotificationAudience.moderators,
        title: 'Новая Professional Page',
        body: 'Создана новая страница. Требуется проверка.',
        createdAtUtc: page.createdAtUtc,
        targetRoute: route,
      ),
    );
  }

  Future<void> _notifyLimitRequest(
    PageLimitIncreaseRequestEntity request,
  ) async {
    final String route = '/settings/workspace';
    await _appendNotificationSafely(
      AppNotificationEvent(
        id: 'page-limit-request-${request.id}-user',
        audience: AppNotificationAudience.user,
        recipientUserId: request.userId,
        title: 'Заявка отправлена',
        body: 'Модераторы рассмотрят дополнительную Professional Page.',
        createdAtUtc: request.createdAtUtc,
        targetRoute: route,
      ),
    );
    await _appendNotificationSafely(
      AppNotificationEvent(
        id: 'page-limit-request-${request.id}-moderators',
        audience: AppNotificationAudience.moderators,
        title: 'Запрос дополнительной страницы',
        body: 'Пользователь запросил лимит ${request.requestedOwnedPageLimit}.',
        createdAtUtc: request.createdAtUtc,
        targetRoute: route,
      ),
    );
  }

  Future<void> _appendNotificationSafely(AppNotificationEvent event) async {
    try {
      await _notificationSink.appendNotification(event);
    } on Object {
      _analyticsService.track(
        'identity_notification_append_failed',
        params: <String, Object?>{'notification_id': event.id},
      );
      rethrow;
    }
  }

  void _setState(IdentityWorkspaceState state) {
    if (_disposed) return;
    _state = _pendingAccessRefresh
        ? state.copyWith(clearAccessSnapshot: true, clearAdminPreview: true)
        : state;
    notifyListeners();
    _drainAccessRefresh();
  }

  void _drainAccessRefresh() {
    if (_disposed ||
        !_pendingAccessRefresh ||
        _refresh != null ||
        _state.isBusy ||
        _state.status == IdentityWorkspaceStatus.loading) {
      return;
    }
    _pendingAccessRefresh = false;
    unawaited(revalidateAccess());
  }
}
