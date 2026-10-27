import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/user_message_catalog.dart';
import '../../domain/entities/event_publication.dart';

/// L4: localized texts shared by the default-off publication test sections.
/// Server values (review state, visibility, failure codes) stay stable ids
/// in the state; only their display is localized here.
abstract final class PublicationTexts {
  /// A controller message code (server, transport or client refusal).
  static String message(AppLocalizations l10n, String code) =>
      UserMessageCatalog.publication(l10n, code);

  /// "Review: …; visibility: …" for one server status.
  static String objectLine(
    AppLocalizations l10n,
    EventPublicationStatus status,
  ) => statusLine(l10n, status.latestSubmissionState, status.visibility);

  static String statusLine(
    AppLocalizations l10n,
    String? reviewState,
    String? visibility,
  ) => l10n.publicationStatusLine(
    l10n.publicationReviewState(reviewState ?? 'draft'),
    l10n.publicationVisibilityState(visibility ?? 'unpublished'),
  );

  /// A server object that could not be read, with its localized reason.
  static String unavailable(AppLocalizations l10n, String? failureCode) =>
      l10n.publicationObjectUnavailable(
        UserMessageCatalog.publication(l10n, failureCode ?? 'unknown'),
      );
}
