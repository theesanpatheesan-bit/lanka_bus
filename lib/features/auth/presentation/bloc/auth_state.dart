part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading, failure }

final class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.authenticated(UserEntity user)
      : this(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated()
      : this(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}
