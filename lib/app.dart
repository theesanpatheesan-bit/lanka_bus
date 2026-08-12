import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/core/constants/app_constants.dart';
import 'package:lanka_bus/core/theme/app_theme.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:lanka_bus/features/auth/presentation/pages/login_page.dart';
import 'package:lanka_bus/features/bus_search/presentation/pages/home_page.dart';

class LankaBusApp extends StatelessWidget {
  const LankaBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          switch (state.status) {
            case AuthStatus.authenticated:
              return const HomePage();
            case AuthStatus.unauthenticated:
            case AuthStatus.failure:
              return const LoginPage();
            case AuthStatus.unknown:
            case AuthStatus.loading:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
          }
        },
      ),
    );
  }
}
