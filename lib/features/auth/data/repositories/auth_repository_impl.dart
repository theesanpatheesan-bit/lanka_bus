import 'package:lanka_bus/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';
import 'package:lanka_bus/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Stream<UserEntity?> get authStateChanges async* {
    await for (final state in _remote.authStateChanges) {
      final user = state.session?.user;
      if (user == null) {
        yield null;
        continue;
      }
      yield await _mapUser(user.id, user.email);
    }
  }

  @override
  UserEntity? get currentUser {
    final session = _remote.currentSession;
    if (session == null) return null;
    final meta = session.user.userMetadata ?? {};
    return UserEntity(
      id: session.user.id,
      fullName: (meta['full_name'] as String?) ?? '',
      email: session.user.email,
      phone: meta['phone'] as String?,
      role: mapRole(meta['role'] as String?),
    );
  }

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _remote.signIn(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw StateError('Sign-in succeeded but no user was returned.');
    }
    return _mapUser(user.id, user.email);
  }

  @override
  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await _remote.signUp(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
    final user = response.user;
    if (user == null) {
      throw StateError('Sign-up succeeded but no user was returned.');
    }
    return UserEntity(
      id: user.id,
      fullName: fullName,
      email: email,
      phone: phone,
      role: UserRole.passenger,
    );
  }

  @override
  Future<void> signOut() => _remote.signOut();

  Future<UserEntity> _mapUser(String id, String? email) async {
    final profile = await _remote.fetchProfile(id);
    if (profile == null) {
      return UserEntity(
        id: id,
        fullName: email?.split('@').first ?? 'Passenger',
        email: email,
        role: UserRole.passenger,
      );
    }
    return UserEntity(
      id: id,
      fullName: profile['full_name'] as String? ?? '',
      email: profile['email'] as String? ?? email,
      phone: profile['phone'] as String?,
      nic: profile['nic'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      role: mapRole(profile['role'] as String?),
    );
  }
}
