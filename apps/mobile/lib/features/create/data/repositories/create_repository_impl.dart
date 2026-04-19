import '../../domain/entities/create_draft_entity.dart';
import '../../domain/repositories/create_repository.dart';
import '../datasources/create_local_datasource.dart';
import '../models/create_draft_model.dart';

class CreateRepositoryImpl implements CreateRepository {
  CreateRepositoryImpl({
    required CreateLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final CreateLocalDataSource _localDataSource;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async {
    final CreateDraftModel? model = await _localDataSource.loadDraft(userId);
    return model?.toEntity();
  }

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) {
    final CreateDraftEntity stored = draft.copyWith(
      draftStatus: DraftStatus.draft,
      publishStatus: PublishStatus.draft,
      updatedAtUtc: DateTime.now().toUtc(),
      clearPublishedAtUtc: true,
    );
    return _localDataSource.saveDraft(
      userId,
      CreateDraftModel.fromEntity(stored),
    );
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    final CreateDraftEntity published = draft.copyWith(
      draftStatus: DraftStatus.pendingReview,
      moderationStatus: ModerationStatus.pending,
      publishStatus: PublishStatus.pendingReview,
      updatedAtUtc: now,
      publishedAtUtc: now,
    );
    await _localDataSource.saveDraft(
      userId,
      CreateDraftModel.fromEntity(published),
    );
    return published;
  }
}
