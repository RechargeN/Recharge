import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/managed_page_entity.dart';
import '../entities/public_professional_page.dart';
import '../repositories/public_professional_page_repository.dart';

enum PublicProfessionalPageLookup { id, slug }

class ResolvePublicProfessionalPageUseCase {
  const ResolvePublicProfessionalPageUseCase({
    required PublicProfessionalPageRepository repository,
    required PublicPageContentProjectionRepository contentRepository,
  }) : _repository = repository,
       _contentRepository = contentRepository;

  final PublicProfessionalPageRepository _repository;
  final PublicPageContentProjectionRepository _contentRepository;

  Future<PublicProfessionalPageResolution> call({
    required PublicProfessionalPageLookup lookup,
    required String reference,
    required String requestedLocale,
  }) async {
    final String normalizedReference = reference.trim();
    final String locale = requestedLocale.trim();
    if (normalizedReference.isEmpty || locale.isEmpty) {
      return const PublicProfessionalPageResolution.notFound();
    }
    final ManagedPageEntity? page = await switch (lookup) {
      PublicProfessionalPageLookup.id => _repository.findById(
        normalizedReference,
      ),
      PublicProfessionalPageLookup.slug => _repository.findBySlug(
        normalizedReference,
      ),
    };
    if (page == null ||
        !page.isPubliclyVisible ||
        page.defaultLocale.trim().isEmpty) {
      return const PublicProfessionalPageResolution.notFound();
    }
    return PublicProfessionalPageResolution.publicPage(
      await buildProjection(page: page, requestedLocale: locale),
    );
  }

  Future<PublicManagedPageProjection> buildPreview({
    required ManagedPageEntity page,
    required String requestedLocale,
  }) {
    return buildProjection(
      page: page,
      requestedLocale: requestedLocale.trim().isEmpty
          ? page.defaultLocale
          : requestedLocale.trim(),
    );
  }

  Future<PublicManagedPageProjection> buildProjection({
    required ManagedPageEntity page,
    required String requestedLocale,
  }) async {
    final PublicPageContentSummary summary = await _contentRepository
        .loadSummaryForPage(page.id);
    final String slug = page.slug.trim().isEmpty
        ? ManagedPageEntity.localSlug(
            displayName: page.displayName,
            pageId: page.id,
          )
        : page.slug.trim();
    final String revisionSource = <Object>[
      page.id,
      slug,
      page.displayName,
      page.avatar,
      page.countryCode,
      requestedLocale,
      page.verificationStatus.name,
      page.lifecycle.name,
      page.revision,
      summary.upcomingCount,
      summary.ongoingCount,
      summary.pastCount,
      summary.timelessCount,
      summary.relatedCount,
    ].join('|');
    return PublicManagedPageProjection(
      pageId: page.id,
      slug: slug,
      displayName: page.displayName,
      avatarMediaRef: page.avatar.trim().isEmpty
          ? null
          : PublicPageMediaRef(
              mediaId: page.avatar.trim(),
              altText: page.displayName,
            ),
      countryCode: page.countryCode,
      verificationBadge:
          page.verificationStatus == ManagedPageVerificationStatus.verified,
      contentSummary: summary,
      publicRevision: sha256.convert(utf8.encode(revisionSource)).toString(),
      schemaVersion: 1,
    );
  }
}
