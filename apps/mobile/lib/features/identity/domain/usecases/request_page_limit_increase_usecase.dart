import '../../../../shared/primitives/id/id_generator.dart';
import '../entities/page_limit_increase_request_entity.dart';
import '../repositories/identity_workspace_repository.dart';
import 'create_professional_page_usecase.dart';

class RequestPageLimitIncreaseException implements Exception {
  const RequestPageLimitIncreaseException(this.code);

  final String code;

  @override
  String toString() => 'RequestPageLimitIncreaseException($code)';
}

class RequestPageLimitIncreaseUseCase {
  const RequestPageLimitIncreaseUseCase({
    required IdentityWorkspaceRepository repository,
    required IdGenerator idGenerator,
    DateTime Function()? utcNow,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _utcNow = utcNow ?? _systemUtcNow;

  final IdentityWorkspaceRepository _repository;
  final IdGenerator _idGenerator;
  final DateTime Function() _utcNow;

  Future<PageLimitIncreaseRequestEntity> call(String userId) async {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw const RequestPageLimitIncreaseException('user_id_required');
    }

    final existing = await _repository.loadPendingPageLimitRequest(
      normalizedUserId,
    );
    if (existing != null) return existing;

    final access = await _repository.loadAccessSnapshot(normalizedUserId);
    if (access.userId != normalizedUserId) {
      throw const RequestPageLimitIncreaseException(
        'access_snapshot_user_mismatch',
      );
    }
    final int ownedPageCount = access.ownedPages.length;
    if (ownedPageCount <
        CreateProfessionalPageUseCase.selfServiceOwnedPageLimit) {
      throw const RequestPageLimitIncreaseException(
        'self_service_limit_not_reached',
      );
    }

    final request = PageLimitIncreaseRequestEntity(
      id: _idGenerator.generate(),
      userId: normalizedUserId,
      currentOwnedPageCount: ownedPageCount,
      requestedOwnedPageLimit: ownedPageCount + 1,
      status: PageLimitIncreaseRequestStatus.pending,
      createdAtUtc: _utcNow().toUtc(),
      revision: 1,
    );
    await _repository.savePageLimitRequest(request);
    return request;
  }

  static DateTime _systemUtcNow() => DateTime.now().toUtc();
}
