import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';
import 'package:lanka_bus/features/auth/domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignOutRequested>(_onSignOut);
  }

  final AuthRepository _authRepository;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    await emit.forEach<UserEntity?>(
      _authRepository.authStateChanges,
      onData: (user) =>
          user == null ? const AuthState.unauthenticated() : AuthState.authenticated(user),
    );
  }

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _authRepository.signInWithEmail(
        email: event.email,
        password: event.password,
      );
      emit(AuthState.authenticated(user));
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    emit(const AuthState.unauthenticated());
  }
}
