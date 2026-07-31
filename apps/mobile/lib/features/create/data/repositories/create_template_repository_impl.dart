import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/create_template_entity.dart';
import '../../domain/repositories/create_template_repository.dart';
import '../datasources/create_template_local_datasource.dart';
import '../models/create_template_model.dart';

class CreateTemplateRepositoryImpl implements CreateTemplateRepository {
  const CreateTemplateRepositoryImpl(this._localDataSource);

  final CreateTemplateLocalDataSource _localDataSource;

  @override
  Future<List<CreateTemplateEntity>> listTemplates({
    required String userId,
    required CreateObjectType objectType,
  }) async {
    final List<CreateTemplateModel> models = List<CreateTemplateModel>.from(
      await _localDataSource.loadTemplates(userId),
    );
    final List<CreateTemplateEntity> templates = <CreateTemplateEntity>[];
    for (final CreateTemplateModel model in models) {
      try {
        final CreateTemplateEntity item = model.toEntity();
        if (item.ownerUserId == userId && item.objectType == objectType) {
          templates.add(item);
        }
      } on Object {
        // One malformed record must not hide valid sibling templates.
      }
    }
    templates.sort(_compareTemplates);
    return templates;
  }

  @override
  Future<void> upsertTemplate({
    required String userId,
    required CreateTemplateEntity template,
  }) async {
    if (template.ownerUserId != userId) {
      throw StateError('Template belongs to another user.');
    }
    final List<CreateTemplateModel> models = List<CreateTemplateModel>.from(
      await _localDataSource.loadTemplates(userId),
    );
    final int index = models.indexWhere(
      (CreateTemplateModel item) => item.id == template.id,
    );
    final CreateTemplateModel replacement = CreateTemplateModel.fromEntity(
      template,
    );
    if (index < 0) {
      models.add(replacement);
    } else {
      models[index] = replacement;
    }
    await _localDataSource.saveTemplates(userId, models);
  }

  @override
  Future<void> deleteTemplate({
    required String userId,
    required String templateId,
  }) async {
    final List<CreateTemplateModel> models = await _localDataSource
        .loadTemplates(userId);
    models.removeWhere(
      (CreateTemplateModel item) =>
          item.ownerUserId == userId && item.id == templateId,
    );
    await _localDataSource.saveTemplates(userId, models);
  }
}

int _compareTemplates(CreateTemplateEntity left, CreateTemplateEntity right) {
  final DateTime leftSort = left.lastUsedAtUtc ?? left.updatedAtUtc;
  final DateTime rightSort = right.lastUsedAtUtc ?? right.updatedAtUtc;
  final int recent = rightSort.compareTo(leftSort);
  return recent != 0 ? recent : left.name.compareTo(right.name);
}
