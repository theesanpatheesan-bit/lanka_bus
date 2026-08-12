/// Lightweight failure types for domain / presentation layers.
sealed class Failure {
  const Failure(this.message);

  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error. Please try again.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on the server.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
