import 'package:flutter/foundation.dart';

import '../../domain/entities/identity_access_snapshot.dart';
import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/managed_page_membership_entity.dart';
import '../../domain/entities/public_professional_page.dart';
import '../../domain/usecases/load_identity_workspace_usecase.dart';
import '../../domain/usecases/resolve_public_professional_page_usecase.dart';
import '../state/public_professional_page_state.dart';

class PublicProfessionalPageController extends ChangeNotifier {
  PublicProfessionalPageController({
    required ResolvePublicProfessionalPageUseCase resolvePage,
    required LoadIdentityWorkspaceUseCase loadIdentityWorkspace,
  }) : _resolvePage = resolvePage,
       _loadIdentityWorkspace = loadIdentityWorkspace;

  final ResolvePublicProfessionalPageUseCase _resolvePage;
  final LoadIdentityWorkspaceUseCase _loadIdentityWorkspace;

  PublicProfessionalPageState _state =
      const PublicProfessionalPageState.initial();
  PublicProfessionalPageState get state => _state;

  int _operationRevision = 0;

  Future<void> loadPublic({
    required String userId,
    required PublicProfessionalPageLookup lookup,
    required String reference,
    required String requestedLocale,
  }) async {
    final int operation = ++_operationRevision;
    _setState(
      const PublicProfessionalPageState(
        status: PublicProfessionalPageStatus.loading,
      ),
    );
    try {
      final PublicProfessionalPageResolution resolution = await _resolvePage(
        lookup: lookup,
        reference: reference,
        requestedLocale: requestedLocale,
      );
      if (operation != _operationRevision) return;
      if (!resolution.isPublicPage) {
        _setState(
          const PublicProfessionalPageState(
            status: PublicProfessionalPageStatus.notFound,
          ),
        );
        return;
      }
      final PublicManagedPageProjection projection = resolution.projection!;
      final IdentityAccessSnapshot? access = await _loadAccess(userId);
      if (operation != _operationRevision) return;
      _setState(
        PublicProfessionalPageState(
          status: PublicProfessionalPageStatus.ready,
          projection: projection,
          viewerContext: _viewerContext(
            access: access,
            pageId: projection.pageId,
            requestedLocale: requestedLocale,
            isPreview: false,
          ),
        ),
      );
    } on Exception {
      if (operation != _operationRevision) return;
      _setState(
        const PublicProfessionalPageState(
          status: PublicProfessionalPageStatus.error,
          message: 'Unable to load this page.',
        ),
      );
    }
  }

  Future<void> loadPreview({
    required String userId,
    required String pageId,
    required String requestedLocale,
  }) async {
    final int operation = ++_operationRevision;
    _setState(
      const PublicProfessionalPageState(
        status: PublicProfessionalPageStatus.loading,
      ),
    );
    try {
      final IdentityAccessSnapshot? access = await _loadAccess(userId);
      if (operation != _operationRevision) return;
      final ManagedPageEntity? page = access?.pageById(pageId);
      final ManagedPageMembershipEntity? membership = access?.membershipFor(
        pageId,
      );
      if (page == null || membership == null || !membership.isActive) {
        _setState(
          const PublicProfessionalPageState(
            status: PublicProfessionalPageStatus.notFound,
          ),
        );
        return;
      }
      final PublicManagedPageProjection projection = await _resolvePage
          .buildPreview(page: page, requestedLocale: requestedLocale);
      if (operation != _operationRevision) return;
      _setState(
        PublicProfessionalPageState(
          status: PublicProfessionalPageStatus.ready,
          projection: projection,
          viewerContext: _viewerContext(
            access: access,
            pageId: pageId,
            requestedLocale: requestedLocale,
            isPreview: true,
          ),
        ),
      );
    } on Exception {
      if (operation != _operationRevision) return;
      _setState(
        const PublicProfessionalPageState(
          status: PublicProfessionalPageStatus.error,
          message: 'Unable to load page preview.',
        ),
      );
    }
  }

  Future<IdentityAccessSnapshot?> _loadAccess(String userId) async {
    final String normalized = userId.trim();
    if (normalized.isEmpty) return null;
    final IdentityWorkspaceLoadResult result = await _loadIdentityWorkspace(
      normalized,
    );
    return result.accessSnapshot;
  }

  static PublicPageViewerContext _viewerContext({
    required IdentityAccessSnapshot? access,
    required String pageId,
    required String requestedLocale,
    required bool isPreview,
  }) {
    final ManagedPageMembershipEntity? membership = access?.membershipFor(
      pageId,
    );
    final bool canOpen = membership?.isActive ?? false;
    return PublicPageViewerContext(
      requestedLocale: requestedLocale,
      canOpenPageWorkspace: canOpen,
      canEditPage:
          canOpen && (membership?.hasCapability('page.manage') ?? false),
      isPreview: isPreview,
    );
  }

  void _setState(PublicProfessionalPageState value) {
    _state = value;
    notifyListeners();
  }
}
