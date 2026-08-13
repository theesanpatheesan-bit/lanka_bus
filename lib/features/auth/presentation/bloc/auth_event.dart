part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthUserChanged extends AuthEvent {
  const AuthUserChanged(this.user);

  final UserEntity? user;

  @override
  List<Object?> get props => [user];
}

final class AuthPassengerEmailSignInRequested extends AuthEvent {
  const AuthPassengerEmailSignInRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthPassengerSignUpRequested extends AuthEvent {
  const AuthPassengerSignUpRequested({
    required this.email,
    required this.password,
    required this.fullName,
    this.phone,
  });

  final String email;
  final String password;
  final String fullName;
  final String? phone;

  @override
  List<Object?> get props => [email, password, fullName, phone];
}

final class AuthPartnerEmailSignInRequested extends AuthEvent {
  const AuthPartnerEmailSignInRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthPhoneOtpRequested extends AuthEvent {
  const AuthPhoneOtpRequested({
    required this.phoneE164,
    this.fullName,
  });

  final String phoneE164;
  final String? fullName;

  @override
  List<Object?> get props => [phoneE164, fullName];
}

final class AuthPhoneOtpVerified extends AuthEvent {
  const AuthPhoneOtpVerified({
    required this.phoneE164,
    required this.token,
    this.fullName,
  });

  final String phoneE164;
  final String token;
  final String? fullName;

  @override
  List<Object?> get props => [phoneE164, token, fullName];
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

final class AuthErrorCleared extends AuthEvent {
  const AuthErrorCleared();
}

final class AuthOtpCancelled extends AuthEvent {
  const AuthOtpCancelled();
}
