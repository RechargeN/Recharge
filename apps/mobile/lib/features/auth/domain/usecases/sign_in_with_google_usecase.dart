import '../entities/auth_result_entity.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogleUseCase {
  const SignInWithGoogleUseCase(this.repository);
  final FederatedAuthRepository repository;
  Future<AuthResultEntity> call() => repository.signInWithGoogle();
}
