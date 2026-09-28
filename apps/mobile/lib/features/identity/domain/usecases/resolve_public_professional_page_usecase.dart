import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/managed_page_entity.dart';
import '../entities/managed_page_field_moderation_overlay.dart';
import '../entities/public_professional_page.dart';
import '../repositories/managed_page_field_moderation_repository.dart';
import '../repositories/public_professional_page_repository.dart';

enum PublicProfessionalPageLookup { id, slug }

class ResolvePublicProfessionalPageUseCase {
  const ResolvePublicProfessionalPageUseCase({
    required PublicProfessionalPageRepository repository,
    required PublicPageContentProjectionRepository contentRepository,
    required ManagedPageFieldModerationRepository moderationRepository,
  }) : _repository = repository,
       _contentRepository = contentRepository,
       _moderationRepository = moderationRepository;

  final PublicProfessionalPageRepository _repository;
  final PublicPageContentProjectionRepository _contentRepository;
  final ManagedPageFieldModerationRepository _moderationRepository;

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
    final List<ManagedPageFieldModerationOverlay> overlays =
        await _moderationRepository.loadForPage(page.id);
    final String? shortDescription = _resolveLocalizedText(
      overlays,
      ManagedPageModeratedFieldKey.shortDescription,
      page: page,
      requestedLocale: requestedLocale,
    );
    final String? description = _resolveLocalizedText(
      overlays,
      ManagedPageModeratedFieldKey.description,
      page: page,
      requestedLocale: requestedLocale,
    );
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
      shortDescription ?? '',
      description ?? '',
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
      shortDescription: shortDescription,
      description: description,
      countryCode: page.countryCode,
      verificationBadge:
          page.verificationStatus == ManagedPageVerificationStatus.verified,
      contentSummary: summary,
      publicRevision: sha256.convert(utf8.encode(revisionSource)).toString(),
      schemaVersion: 1,
    );
  }

  static String? _resolveLocalizedText(
    List<ManagedPageFieldModerationOverlay> overlays,
    ManagedPageModeratedFieldKey fieldKey, {
    required ManagedPageEntity page,
    required String requestedLocale,
  }) {
    final ManagedPageFieldModerationOverlay? overlay = overlays
        .cast<ManagedPageFieldModerationOverlay?>()
        .firstWhere(
          (ManagedPageFieldModerationOverlay? item) =>
              item?.fieldKey == fieldKey,
          orElse: () => null,
        );
    final ManagedPageModeratedFieldValue? value = overlay?.effectiveValue(
      currentVerificationRevision: page.verificationRevision,
    );
    if (value is! ManagedPageLocalizedTextValue) return null;
    final String? forRequested = value.valuesByLocale[requestedLocale];
    if (forRequested != null && forRequested.trim().isNotEmpty) {
      return forRequested;
    }
    final String? forDefault = value.valuesByLocale[page.defaultLocale];
    return (forDefault != null && forDefault.trim().isNotEmpty)
        ? forDefault
        : null;
  }
}
