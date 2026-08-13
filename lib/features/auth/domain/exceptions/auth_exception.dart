/// Domain-level auth failures with safe, user-facing messages.
class AppAuthException implements Exception {
  const AppAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthExceptions {
  AuthExceptions._();

  static const invalidCredentials = AppAuthException(
    'Invalid email or password.',
    code: 'invalid_credentials',
  );

  static const accountInactive = AppAuthException(
    'This account has been deactivated. Contact support.',
    code: 'account_inactive',
  );

  static const partnerRoleRequired = AppAuthException(
    'This account is not registered as an operator, conductor, or admin.',
    code: 'partner_role_required',
  );

  static const passengerRoleRequired = AppAuthException(
    'Staff accounts must use Operator / Partner Login.',
    code: 'passenger_role_required',
  );

  static const profileMissing = AppAuthException(
    'Your profile is not set up. Contact an administrator.',
    code: 'profile_missing',
  );

  static const otpSendFailed = AppAuthException(
    'Could not send OTP. Check the phone number and try again.',
    code: 'otp_send_failed',
  );

  static const otpInvalid = AppAuthException(
    'Invalid or expired OTP. Please try again.',
    code: 'otp_invalid',
  );

  static const sessionExpired = AppAuthException(
    'Your session has expired. Please sign in again.',
    code: 'session_expired',
  );

  static AppAuthException from(Object error) {
    if (error is AppAuthException) return error;

    final text = error.toString();
    final lower = text.toLowerCase();

    if (lower.contains('email not confirmed')) {
      return const AppAuthException(
        'Email not confirmed yet. Confirm your email in the inbox, '
        'or disable "Confirm email" in Supabase Auth settings.',
      );
    }
    if (lower.contains('user already registered') ||
        lower.contains('already been registered')) {
      return const AppAuthException(
        'This email is already registered. Please sign in instead.',
      );
    }
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return AuthExceptions.invalidCredentials;
    }
    if (lower.contains('otp') || lower.contains('token')) {
      return AuthExceptions.otpInvalid;
    }

    // Surface a short useful message instead of a generic failure.
    final cleaned = text
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^AuthApiException:\s*'), '')
        .replaceFirst(RegExp(r'^PostgrestException:\s*'), '');
    if (cleaned.isNotEmpty && cleaned.length < 180) {
      return AppAuthException(cleaned);
    }
    return const AppAuthException('Authentication failed. Please try again.');
  }
}
