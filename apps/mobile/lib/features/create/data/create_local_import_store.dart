import 'datasources/create_local_datasource.dart';
import 'models/create_draft_model.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/repositories/create_repository.dart';
import '../domain/repositories/local_import_gateway.dart';

/// The local inventory of the import (D4 §5.1): the account's current Create
/// draft, plus the drafts of the local library (Scenario, Route), which are
/// only listed — their owning backends do not exist yet.
final class CreateLocalImportSource implements LocalImportSource {
  const CreateLocalImportSource({
    required CreateRepository repository,
    required CreateLocalDataSource library,
  }) : _repository = repository,
       _library = library;

  static const List<String> listedLibraryTypes = <String>['scenario', 'route'];

  final CreateRepository _repository;
  final CreateLocalDataSource _library;

  @override
  Future<List<LocalImportSourceItem>> inventory(String accountId) async {
    final List<LocalImportSourceItem> items = <LocalImportSourceItem>[];
    final CreateDraftEntity? current = await _repository.loadDraft(accountId);
    if (current != null) {
      items.add(
        LocalImportSourceItem(
          localDraftId: current.id,
          localType: current.objectType.name,
          title: current.title,
          draft: current,
        ),
      );
    }
    for (final String type in listedLibraryTypes) {
      for (final CreateDraftModel model in await _library.listCollectionDrafts(
        ownerId: accountId,
        objectType: type,
      )) {
        if (model.id == current?.id) continue;
        items.add(
          LocalImportSourceItem(
            localDraftId: model.id,
            localType: model.objectType,
            title: model.title,
          ),
        );
      }
    }
    return items;
  }
}

/// Removes the account's current Create draft, and only the exact one the
/// import verified (D4 §6). The check and the removal are one serialized
/// mutation of the draft slot.
final class CreateLocalImportOriginalStore implements LocalImportOriginalStore {
  const CreateLocalImportOriginalStore(this._datasource);

  final CreateLocalDataSource _datasource;

  @override
  Future<bool> deleteIfUnchanged({
    required String accountId,
    required String localDraftId,
    required bool Function(CreateDraftEntity draft) unchanged,
  }) =>
      _datasource.deleteDraftIfUnchanged(accountId, (CreateDraftModel stored) {
        final CreateDraftEntity entity = stored.toEntity();
        return entity.id == localDraftId && unchanged(entity);
      });
}
