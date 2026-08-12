import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:lanka_bus/features/auth/domain/entities/user_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': ?phone,
        'role': 'passenger',
      },
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    return _client.from('users').select().eq('id', userId).maybeSingle();
  }
}

UserRole mapRole(String? value) {
  return UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.passenger,
  );
}
