import '../../../../core/id/id_generator.dart';
import '../entities/managed_page_entity.dart';
import '../entities/managed_page_membership_entity.dart';
import '../entities/professional_page_creation_input.dart';
import '../repositories/identity_workspace_repository.dart';

class CreateProfessionalPageException implements Exception {
  const CreateProfessionalPageException(this.code);

  final String code;

  @override
  String toString() => 'CreateProfessionalPageException($code)';
}

class CreateProfessionalPageUseCase {
  const CreateProfessionalPageUseCase({
    required IdentityWorkspaceRepository repository,
    required IdGenerator idGenerator,
    DateTime Function()? utcNow,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _utcNow = utcNow ?? _systemUtcNow;

  static const int selfServiceOwnedPageLimit = 3;

  final IdentityWorkspaceRepository _repository;
  final IdGenerator _idGenerator;
  final DateTime Function() _utcNow;

  Future<ManagedPageEntity> call({
    required String userId,
    required ProfessionalPageCreationInput input,
  }) async {
    final String normalizedUserId = userId.trim();
    final String displayName = input.displayName.trim();
    if (normalizedUserId.isEmpty) {
      throw const CreateProfessionalPageException('user_id_required');
    }
    if (displayName.length < 2 || displayName.length > 120) {
      throw const CreateProfessionalPageException('page_display_name_invalid');
    }
    if (!_hasInternationalMetadata(input)) {
      throw const CreateProfessionalPageException(
        'page_market_metadata_invalid',
      );
    }

    final access = await _repository.loadAccessSnapshot(normalizedUserId);
    if (access.userId != normalizedUserId) {
      throw const CreateProfessionalPageException(
        'access_snapshot_user_mismatch',
      );
    }
    if (!access.isVerifiedCreator ||
        !access.hasGlobalCapability('page.create')) {
      throw const CreateProfessionalPageException(
        'page_creation_not_authorized',
      );
    }
    if (access.ownedPages.length >= selfServiceOwnedPageLimit) {
      throw const CreateProfessionalPageException(
        'self_service_page_limit_reached',
      );
    }

    final String pageId = _idGenerator.generate();
    final DateTime createdAtUtc = _utcNow().toUtc();
    final page = ManagedPageEntity(
      id: pageId,
      ownerUserId: normalizedUserId,
      kind: input.kind,
      displayName: displayName,
      slug: ManagedPageEntity.localSlug(
        displayName: displayName,
        pageId: pageId,
      ),
      avatar: '',
      verificationStatus: ManagedPageVerificationStatus.pending,
      lifecycle: ManagedPageLifecycle.active,
      marketId: input.marketId.trim(),
      countryCode: input.countryCode.trim().toUpperCase(),
      defaultLocale: input.defaultLocale.trim(),
      timezone: input.timezone.trim(),
      defaultCurrency: input.defaultCurrency.trim().toUpperCase(),
      supportedLocales: input.supportedLocales
          .map((String locale) => locale.trim())
          .where((String locale) => locale.isNotEmpty)
          .toSet()
          .toList(growable: false),
      createdAtUtc: createdAtUtc,
      revision: 1,
    );
    final membership = ManagedPageMembershipEntity(
      pageId: pageId,
      userId: normalizedUserId,
      relationship: ManagedPageRelationship.owner,
      status: ManagedPageMembershipStatus.active,
      capabilities: const <String>{
        'page.manage',
        'page.content.create',
        'page.content.submit',
        'page.insights.view',
      },
      revision: 1,
    );
    await _repository.saveCreatedPage(
      userId: normalizedUserId,
      page: page,
      membership: membership,
    );
    return page;
  }

  static bool _hasInternationalMetadata(ProfessionalPageCreationInput input) {
    return input.marketId.trim().isNotEmpty &&
        input.countryCode.trim().length == 2 &&
        input.defaultLocale.trim().isNotEmpty &&
        input.timezone.trim().contains('/') &&
        input.defaultCurrency.trim().length == 3 &&
        input.supportedLocales.any(
          (String locale) => locale.trim() == input.defaultLocale.trim(),
        );
  }

  static DateTime _systemUtcNow() => DateTime.now().toUtc();
}
