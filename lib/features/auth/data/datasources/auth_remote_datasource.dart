import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:lanka_bus/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentAuthUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) {
    final trimmedPhone = phone?.trim();
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        if (trimmedPhone != null && trimmedPhone.isNotEmpty)
          'phone': trimmedPhone,
        'role': 'passenger',
      },
    );
  }

  Future<void> sendPhoneOtp({required String phoneE164}) {
    return _client.auth.signInWithOtp(phone: phoneE164);
  }

  Future<AuthResponse> verifyPhoneOtp({
    required String phoneE164,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      phone: phoneE164,
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<UserModel?> fetchProfile(String userId) async {
    final row = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserModel.fromJson(row);
  }

  /// Inserts profile if missing; updates contact fields only (never escalates role).
  Future<UserModel> upsertProfile({
    required String id,
    required String fullName,
    String? email,
    String? phone,
    required String roleIfCreating,
  }) async {
    final existing = await fetchProfile(id);
    final trimmedPhone = phone?.trim();
    final safePhone =
        (trimmedPhone == null || trimmedPhone.isEmpty) ? null : trimmedPhone;

    if (existing == null) {
      try {
        final inserted = await _client
            .from('users')
            .insert({
              'id': id,
              'full_name': fullName.trim().isEmpty ? 'Passenger' : fullName.trim(),
              'email': email,
              'phone': safePhone,
              'role': roleIfCreating,
              'is_active': true,
            })
            .select()
            .single();
        return UserModel.fromJson(inserted);
      } catch (_) {
        // Trigger may have created the row first — fall through to update/fetch.
        final created = await fetchProfile(id);
        if (created != null) return created;
        rethrow;
      }
    }

    final updated = await _client
        .from('users')
        .update({
          'full_name':
              fullName.trim().isEmpty ? existing.fullName : fullName.trim(),
          if (email != null && email.isNotEmpty) 'email': email,
          'phone': ?safePhone,
        })
        .eq('id', id)
        .select()
        .single();

    return UserModel.fromJson(updated);
  }
}
