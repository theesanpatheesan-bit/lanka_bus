import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the Supabase client for dependency injection.
class SupabaseClientProvider {
  SupabaseClientProvider._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase has not been initialized yet.');
    }
    return Supabase.instance.client;
  }

  static GoTrueClient get auth => client.auth;

  static SupabaseStorageClient get storage => client.storage;

  static RealtimeClient get realtime => client.realtime;

  /// Returns `true` when credentials look valid and init succeeded.
  static Future<bool> initialize() async {
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

    final configured = url.isNotEmpty &&
        anonKey.isNotEmpty &&
        !url.contains('YOUR_PROJECT') &&
        !anonKey.contains('YOUR_SUPABASE');

    if (!configured) {
      _initialized = false;
      return false;
    }

    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
    return true;
  }
}
