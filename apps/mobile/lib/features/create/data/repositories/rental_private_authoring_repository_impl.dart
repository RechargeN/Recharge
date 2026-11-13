import '../../domain/entities/rental_private_authoring_data.dart';
import '../../domain/repositories/rental_private_authoring_repository.dart';
import '../datasources/rental_private_authoring_local_datasource.dart';

class RentalPrivateAuthoringRepositoryImpl
    implements RentalPrivateAuthoringRepository {
  const RentalPrivateAuthoringRepositoryImpl(this._dataSource);

  final RentalPrivateAuthoringLocalDataSource _dataSource;

  @override
  Future<RentalPrivateAuthoringData> read(String draftId) =>
      _dataSource.read(draftId);

  @override
  Future<void> write(String draftId, RentalPrivateAuthoringData data) =>
      _dataSource.write(draftId, data);

  @override
  Future<void> delete(String draftId) => _dataSource.delete(draftId);
}
