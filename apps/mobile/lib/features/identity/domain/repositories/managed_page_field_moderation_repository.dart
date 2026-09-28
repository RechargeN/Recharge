import '../entities/managed_page_field_moderation_overlay.dart';

/// Port for the `ManagedPageFieldModerationOverlay` (`PP-D48`) read/write
/// model. One implementation exists today: a local/mock adapter scoped to
/// `MANAGED_PAGE_PROFILE_EDITOR_LOCAL_SLICE_SPEC.md` (`PP-01A`).
abstract class ManagedPageFieldModerationRepository {
  Future<List<ManagedPageFieldModerationOverlay>> loadForPage(String pageId);

  Future<void> saveOverlay(ManagedPageFieldModerationOverlay overlay);
}
