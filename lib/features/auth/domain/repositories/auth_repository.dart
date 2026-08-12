import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;

  UserEntity? get currentUser;

  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  Future<void> signOut();
}
