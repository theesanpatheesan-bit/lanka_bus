import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lanka_bus/app.dart';
import 'package:lanka_bus/core/network/supabase_client.dart';
import 'package:lanka_bus/core/theme/app_theme.dart';
import 'package:lanka_bus/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lanka_bus/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  final ready = await SupabaseClientProvider.initialize();

  if (!ready) {
    runApp(const _ConfigRequiredApp());
    return;
  }

  final authRepository = AuthRepositoryImpl(AuthRemoteDataSource());

  runApp(
    RepositoryProvider.value(
      value: authRepository,
      child: BlocProvider(
        create: (_) => AuthBloc(authRepository)..add(const AuthStarted()),
        child: const LankaBusApp(),
      ),
    ),
  );
}

class _ConfigRequiredApp extends StatelessWidget {
  const _ConfigRequiredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Configure Supabase\n\n'
              '1. Copy .env.example to .env\n'
              '2. Set SUPABASE_URL and SUPABASE_ANON_KEY\n'
              '3. Run the SQL migrations in supabase/migrations/\n'
              '4. Restart the app',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
