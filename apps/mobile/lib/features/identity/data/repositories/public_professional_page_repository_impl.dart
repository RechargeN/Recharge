import '../../domain/entities/managed_page_entity.dart';
import '../../domain/entities/public_professional_page.dart';
import '../../domain/repositories/public_professional_page_repository.dart';
import '../datasources/public_professional_page_local_datasource.dart';

class PublicProfessionalPageRepositoryImpl
    implements PublicProfessionalPageRepository {
  const PublicProfessionalPageRepositoryImpl(this._localDataSource);

  final PublicProfessionalPageLocalDataSource _localDataSource;

  @override
  Future<ManagedPageEntity?> findById(String pageId) async {
    final String target = pageId.trim();
    if (target.isEmpty) return null;
    final List<ManagedPageEntity> pages = await _localDataSource.loadPages();
    for (final ManagedPageEntity page in pages) {
      if (page.id == target) return page;
    }
    return null;
  }

  @override
  Future<ManagedPageEntity?> findBySlug(String slug) async {
    final String target = slug.trim().toLowerCase();
    if (target.isEmpty) return null;
    final List<ManagedPageEntity> pages = await _localDataSource.loadPages();
    for (final ManagedPageEntity page in pages) {
      if (page.slug.toLowerCase() == target) return page;
    }
    return null;
  }
}

class EmptyPublicPageContentProjectionRepository
    implements PublicPageContentProjectionRepository {
  const EmptyPublicPageContentProjectionRepository();

  @override
  Future<PublicPageContentSummary> loadSummaryForPage(String pageId) async {
    return const PublicPageContentSummary.empty();
  }
}
