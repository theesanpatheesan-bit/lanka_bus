part of 'auth_bloc.dart';

enum AuthStatus {
  unknown,
  loading,
  unauthenticated,
  authenticated,
  otpSent,
  error,
}

final class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.pendingPhoneE164,
    this.pendingFullName,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(UserEntity user)
      : this(status: AuthStatus.authenticated, user: user);

  const AuthState.otpSent({
    required String phoneE164,
    String? fullName,
    String? errorMessage,
  }) : this(
          status: AuthStatus.otpSent,
          pendingPhoneE164: phoneE164,
          pendingFullName: fullName,
          errorMessage: errorMessage,
        );

  const AuthState.error(String message)
      : this(status: AuthStatus.error, errorMessage: message);

  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;
  final String? pendingPhoneE164;
  final String? pendingFullName;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? errorMessage,
    String? pendingPhoneE164,
    String? pendingFullName,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingPhoneE164: pendingPhoneE164 ?? this.pendingPhoneE164,
      pendingFullName: pendingFullName ?? this.pendingFullName,
    );
  }

  @override
  List<Object?> get props => [
        status,
        user,
        errorMessage,
        pendingPhoneE164,
        pendingFullName,
      ];
}
