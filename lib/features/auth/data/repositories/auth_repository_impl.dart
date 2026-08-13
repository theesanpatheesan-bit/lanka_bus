import 'package:lanka_bus/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lanka_bus/features/auth/data/models/user_model.dart';
import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';
import 'package:lanka_bus/features/auth/domain/exceptions/auth_exception.dart';
import 'package:lanka_bus/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Stream<UserEntity?> get authStateChanges async* {
    await for (final state in _remote.onAuthStateChange) {
      final authUser = state.session?.user;
      if (authUser == null) {
        yield null;
        continue;
      }
      try {
        yield await _loadOrCreateFromAuthUser(authUser);
      } catch (_) {
        // Profile trigger can lag a moment after signup — retry once.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        try {
          yield await _loadOrCreateFromAuthUser(authUser);
        } catch (_) {
          // Keep session alive; don't bounce the UI back to Login.
          yield _fallbackEntity(authUser);
        }
      }
    }
  }

  @override
  Future<UserEntity?> restoreSession() async {
    final authUser = _remote.currentAuthUser;
    if (authUser == null) return null;
    try {
      return await _loadOrCreateFromAuthUser(authUser);
    } catch (_) {
      return _fallbackEntity(authUser);
    }
  }

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
    required Set<UserRole> allowedRoles,
  }) async {
    try {
      final response = await _remote.signInWithEmail(
        email: email,
        password: password,
      );
      final authUser = response.user;
      if (authUser == null || response.session == null) {
        throw AuthExceptions.invalidCredentials;
      }

      final profile = await _requireActiveProfile(
        authUser,
        roleIfCreating: UserRole.passenger,
      );

      if (!allowedRoles.contains(profile.role)) {
        await _remote.signOut();
        if (allowedRoles.every((r) => r.isStaff)) {
          throw AuthExceptions.partnerRoleRequired;
        }
        throw AuthExceptions.passengerRoleRequired;
      }

      return profile;
    } on AppAuthException {
      rethrow;
    } catch (error) {
      throw AuthExceptions.from(error);
    }
  }

  @override
  Future<UserEntity> signUpPassenger({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _remote.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      final authUser = response.user;

      if (authUser == null) {
        throw const AppAuthException(
          'Sign-up failed. Please try again with a different email.',
        );
      }

      // Supabase returns an empty identities list when the email already exists.
      final identities = authUser.identities;
      if (identities != null && identities.isEmpty) {
        throw const AppAuthException(
          'This email is already registered. Please sign in instead.',
        );
      }

      if (response.session == null) {
        throw const AppAuthException(
          'Account created, but you are not signed in yet. '
          'Turn off "Confirm email" in Supabase Auth settings, '
          'or confirm your email, then tap Sign in.',
        );
      }

      // Give the DB trigger a brief moment to create public.users.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      return syncProfile(
        id: authUser.id,
        fullName: fullName,
        email: email,
        phone: phone,
        roleIfCreating: UserRole.passenger,
      );
    } on AppAuthException {
      rethrow;
    } catch (error) {
      throw AuthExceptions.from(error);
    }
  }

  @override
  Future<void> sendPhoneOtp({required String phoneE164}) async {
    try {
      await _remote.sendPhoneOtp(phoneE164: phoneE164);
    } catch (_) {
      throw AuthExceptions.otpSendFailed;
    }
  }

  @override
  Future<UserEntity> verifyPhoneOtp({
    required String phoneE164,
    required String token,
    String? fullName,
  }) async {
    try {
      final response = await _remote.verifyPhoneOtp(
        phoneE164: phoneE164,
        token: token,
      );
      final authUser = response.user;
      if (authUser == null) {
        throw AuthExceptions.otpInvalid;
      }

      final name = (fullName?.trim().isNotEmpty == true)
          ? fullName!.trim()
          : (authUser.userMetadata?['full_name'] as String?) ?? 'Passenger';

      return syncProfile(
        id: authUser.id,
        fullName: name,
        email: authUser.email,
        phone: phoneE164,
        roleIfCreating: UserRole.passenger,
      );
    } on AppAuthException {
      rethrow;
    } catch (error) {
      throw AuthExceptions.from(error);
    }
  }

  @override
  Future<UserEntity> syncProfile({
    required String id,
    required String fullName,
    String? email,
    String? phone,
    required UserRole roleIfCreating,
  }) async {
    final model = await _remote.upsertProfile(
      id: id,
      fullName: fullName,
      email: email,
      phone: phone,
      roleIfCreating: roleIfCreating.name,
    );
    if (!model.isActive) {
      await _remote.signOut();
      throw AuthExceptions.accountInactive;
    }
    return model.toEntity();
  }

  @override
  Future<void> signOut() => _remote.signOut();

  Future<UserEntity> _loadOrCreateFromAuthUser(User authUser) async {
    return _requireActiveProfile(
      authUser,
      roleIfCreating: UserRole.passenger,
    );
  }

  Future<UserEntity> _requireActiveProfile(
    User authUser, {
    required UserRole roleIfCreating,
  }) async {
    UserModel? profile = await _remote.fetchProfile(authUser.id);

    if (profile == null) {
      final meta = authUser.userMetadata ?? {};
      profile = await _remote.upsertProfile(
        id: authUser.id,
        fullName: (meta['full_name'] as String?) ??
            authUser.email?.split('@').first ??
            'User',
        email: authUser.email,
        phone: (meta['phone'] as String?) ?? authUser.phone,
        roleIfCreating: roleIfCreating.name,
      );
    }

    if (!profile.isActive) {
      await _remote.signOut();
      throw AuthExceptions.accountInactive;
    }

    return profile.toEntity();
  }

  UserEntity _fallbackEntity(User authUser) {
    final meta = authUser.userMetadata ?? {};
    return UserEntity(
      id: authUser.id,
      fullName: (meta['full_name'] as String?) ??
          authUser.email?.split('@').first ??
          'Passenger',
      email: authUser.email,
      phone: (meta['phone'] as String?) ?? authUser.phone,
      role: UserRole.passenger,
    );
  }
}
