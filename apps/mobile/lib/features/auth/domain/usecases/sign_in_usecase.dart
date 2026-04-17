import '../entities/auth_result_entity.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthResultEntity> call({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
    required String appVersion,
  }) {
    return _repository.signIn(
      email: email,
      password: password,
      deviceName: deviceName,
      platform: platform,
      appVersion: appVersion,
    );
  }
}
