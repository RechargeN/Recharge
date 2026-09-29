import '../../domain/entities/managed_page_field_moderation_overlay.dart';
import '../../domain/repositories/managed_page_field_moderation_repository.dart';
import '../datasources/managed_page_field_moderation_local_datasource.dart';

class ManagedPageFieldModerationRepositoryImpl
    implements ManagedPageFieldModerationRepository {
  const ManagedPageFieldModerationRepositoryImpl(this._localDataSource);

  final ManagedPageFieldModerationLocalDataSource _localDataSource;

  @override
  Future<List<ManagedPageFieldModerationOverlay>> loadForPage(String pageId) {
    return _localDataSource.loadForPage(pageId);
  }

  @override
  Future<void> saveOverlay(ManagedPageFieldModerationOverlay overlay) async {
    final List<ManagedPageFieldModerationOverlay> existing =
        await _localDataSource.loadForPage(overlay.pageId);
    final int index = existing.indexWhere(
      (ManagedPageFieldModerationOverlay item) =>
          item.fieldKey == overlay.fieldKey,
    );
    final List<ManagedPageFieldModerationOverlay> updated =
        List<ManagedPageFieldModerationOverlay>.of(existing);
    if (index >= 0) {
      updated[index] = overlay;
    } else {
      updated.add(overlay);
    }
    await _localDataSource.saveForPage(overlay.pageId, updated);
  }
}
