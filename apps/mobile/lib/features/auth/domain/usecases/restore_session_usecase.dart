import '../entities/auth_result_entity.dart';
import '../repositories/auth_repository.dart';

class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResultEntity?> call() => _repository.restoreSession();
}
