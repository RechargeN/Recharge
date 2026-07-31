import '../entities/create_draft_entity.dart';
import '../entities/create_template_entity.dart';

abstract class CreateTemplateRepository {
  Future<List<CreateTemplateEntity>> listTemplates({
    required String userId,
    required CreateObjectType objectType,
  });

  Future<void> upsertTemplate({
    required String userId,
    required CreateTemplateEntity template,
  });

  Future<void> deleteTemplate({
    required String userId,
    required String templateId,
  });
}
