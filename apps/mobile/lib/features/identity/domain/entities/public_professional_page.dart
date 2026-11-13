class PublicPageMediaRef {
  const PublicPageMediaRef({required this.mediaId, this.altText});

  final String mediaId;
  final String? altText;
}

class PublicPageCategoryRef {
  const PublicPageCategoryRef({required this.categoryId, required this.label});

  final String categoryId;
  final String label;
}

class PublicPageContentSummary {
  const PublicPageContentSummary({
    required this.upcomingCount,
    required this.ongoingCount,
    required this.pastCount,
    required this.timelessCount,
    required this.relatedCount,
  });

  const PublicPageContentSummary.empty()
    : upcomingCount = 0,
      ongoingCount = 0,
      pastCount = 0,
      timelessCount = 0,
      relatedCount = 0;

  final int upcomingCount;
  final int ongoingCount;
  final int pastCount;
  final int timelessCount;
  final int relatedCount;

  int get publishedCount =>
      upcomingCount + ongoingCount + pastCount + timelessCount;
}

class PublicManagedPageProjection {
  const PublicManagedPageProjection({
    required this.pageId,
    required this.slug,
    required this.displayName,
    required this.countryCode,
    required this.verificationBadge,
    required this.contentSummary,
    required this.publicRevision,
    required this.schemaVersion,
    this.avatarMediaRef,
    this.shortDescription,
    this.description,
    this.serviceCategories = const <PublicPageCategoryRef>[],
  });

  final String pageId;
  final String slug;
  final String displayName;
  final PublicPageMediaRef? avatarMediaRef;
  final String? shortDescription;
  final String? description;
  final List<PublicPageCategoryRef> serviceCategories;
  final String countryCode;
  final bool verificationBadge;
  final PublicPageContentSummary contentSummary;
  final String publicRevision;
  final int schemaVersion;
}

class PublicPageViewerContext {
  const PublicPageViewerContext({
    required this.requestedLocale,
    required this.canOpenPageWorkspace,
    required this.canEditPage,
    required this.isPreview,
  });

  final String requestedLocale;
  final bool canOpenPageWorkspace;
  final bool canEditPage;
  final bool isPreview;
}

enum PublicProfessionalPageResolutionType { publicPage, notFound }

class PublicProfessionalPageResolution {
  const PublicProfessionalPageResolution._({
    required this.type,
    this.projection,
  });

  const PublicProfessionalPageResolution.notFound()
    : this._(type: PublicProfessionalPageResolutionType.notFound);

  const PublicProfessionalPageResolution.publicPage(
    PublicManagedPageProjection projection,
  ) : this._(
        type: PublicProfessionalPageResolutionType.publicPage,
        projection: projection,
      );

  final PublicProfessionalPageResolutionType type;
  final PublicManagedPageProjection? projection;

  bool get isPublicPage =>
      type == PublicProfessionalPageResolutionType.publicPage &&
      projection != null;
}
