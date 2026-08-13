import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';

/// Contract for authentication & profile sync.
abstract class AuthRepository {
  /// Emits profile (or null) whenever the Supabase session changes.
  Stream<UserEntity?> get authStateChanges;

  /// Restores session and loads `public.users` profile if logged in.
  Future<UserEntity?> restoreSession();

  /// Passenger / partner email+password sign-in.
  ///
  /// [allowedRoles] enforces RBAC at login (e.g. partner portal).
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
    required Set<UserRole> allowedRoles,
  });

  /// Passenger email registration (always creates `passenger` role).
  Future<UserEntity> signUpPassenger({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  /// Sends SMS OTP via Supabase Auth (E.164 phone, e.g. +94771234567).
  Future<void> sendPhoneOtp({required String phoneE164});

  /// Verifies SMS OTP and syncs passenger profile.
  Future<UserEntity> verifyPhoneOtp({
    required String phoneE164,
    required String token,
    String? fullName,
  });

  /// Creates or updates `public.users` without escalating role on update.
  Future<UserEntity> syncProfile({
    required String id,
    required String fullName,
    String? email,
    String? phone,
    required UserRole roleIfCreating,
  });

  Future<void> signOut();
}
