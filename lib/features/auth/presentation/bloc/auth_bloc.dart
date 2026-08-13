import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';
import 'package:lanka_bus/features/auth/domain/exceptions/auth_exception.dart';
import 'package:lanka_bus/features/auth/domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthUserChanged>(_onUserChanged);
    on<AuthPassengerEmailSignInRequested>(_onPassengerEmailSignIn);
    on<AuthPassengerSignUpRequested>(_onPassengerSignUp);
    on<AuthPartnerEmailSignInRequested>(_onPartnerEmailSignIn);
    on<AuthPhoneOtpRequested>(_onPhoneOtpRequested);
    on<AuthPhoneOtpVerified>(_onPhoneOtpVerified);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthErrorCleared>(_onErrorCleared);
    on<AuthOtpCancelled>(_onOtpCancelled);
  }

  final AuthRepository _authRepository;
  StreamSubscription<UserEntity?>? _authSub;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(const AuthState.loading());

    _authSub?.cancel();
    _authSub = _authRepository.authStateChanges.listen(
      (user) => add(AuthUserChanged(user)),
    );

    try {
      final user = await _authRepository.restoreSession();
      if (user == null) {
        emit(const AuthState.unauthenticated());
      } else {
        emit(AuthState.authenticated(user));
      }
    } catch (error) {
      emit(
        AuthState.error(
          AuthExceptions.from(error).message,
        ),
      );
      emit(const AuthState.unauthenticated());
    }
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    final user = event.user;
    if (user == null) {
      // Keep OTP screen while waiting for verification.
      if (state.status == AuthStatus.otpSent) return;
      // Ignore transient nulls while a sign-in/sign-up is in progress
      // or after we already authenticated (avoids Login bounce).
      if (state.status == AuthStatus.loading ||
          state.status == AuthStatus.authenticated) {
        return;
      }
      emit(const AuthState.unauthenticated());
      return;
    }
    emit(AuthState.authenticated(user));
  }

  Future<void> _onPassengerEmailSignIn(
    AuthPassengerEmailSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final user = await _authRepository.signInWithEmail(
        email: event.email,
        password: event.password,
        allowedRoles: {UserRole.passenger},
      );
      emit(AuthState.authenticated(user));
    } catch (error) {
      emit(AuthState.error(AuthExceptions.from(error).message));
    }
  }

  Future<void> _onPassengerSignUp(
    AuthPassengerSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final user = await _authRepository.signUpPassenger(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        phone: event.phone,
      );
      emit(AuthState.authenticated(user));
    } catch (error) {
      emit(AuthState.error(AuthExceptions.from(error).message));
    }
  }

  Future<void> _onPartnerEmailSignIn(
    AuthPartnerEmailSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final user = await _authRepository.signInWithEmail(
        email: event.email,
        password: event.password,
        allowedRoles: {
          UserRole.operator,
          UserRole.conductor,
          UserRole.admin,
        },
      );
      emit(AuthState.authenticated(user));
    } catch (error) {
      emit(AuthState.error(AuthExceptions.from(error).message));
    }
  }

  Future<void> _onPhoneOtpRequested(
    AuthPhoneOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      await _authRepository.sendPhoneOtp(phoneE164: event.phoneE164);
      emit(
        AuthState.otpSent(
          phoneE164: event.phoneE164,
          fullName: event.fullName,
        ),
      );
    } catch (error) {
      emit(AuthState.error(AuthExceptions.from(error).message));
    }
  }

  Future<void> _onPhoneOtpVerified(
    AuthPhoneOtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final user = await _authRepository.verifyPhoneOtp(
        phoneE164: event.phoneE164,
        token: event.token,
        fullName: event.fullName,
      );
      emit(AuthState.authenticated(user));
    } catch (error) {
      emit(
        AuthState.otpSent(
          phoneE164: event.phoneE164,
          fullName: event.fullName,
          errorMessage: AuthExceptions.from(error).message,
        ),
      );
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.unauthenticated());
    await _authRepository.signOut();
  }

  void _onErrorCleared(AuthErrorCleared event, Emitter<AuthState> emit) {
    if (state.status == AuthStatus.error) {
      emit(const AuthState.unauthenticated());
    } else {
      emit(state.copyWith(clearError: true));
    }
  }

  void _onOtpCancelled(AuthOtpCancelled event, Emitter<AuthState> emit) {
    emit(const AuthState.unauthenticated());
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
