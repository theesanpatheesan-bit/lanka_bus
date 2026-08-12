import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';
import 'package:lanka_bus/features/auth/domain/repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<UserEntity> call({
    required String email,
    required String password,
  }) {
    return _repository.signInWithEmail(email: email, password: password);
  }
}
