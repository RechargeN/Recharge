import '../entities/managed_page_entity.dart';
import '../entities/public_professional_page.dart';

abstract class PublicProfessionalPageRepository {
  Future<ManagedPageEntity?> findById(String pageId);

  Future<ManagedPageEntity?> findBySlug(String slug);
}

abstract class PublicPageContentProjectionRepository {
  Future<PublicPageContentSummary> loadSummaryForPage(String pageId);
}
