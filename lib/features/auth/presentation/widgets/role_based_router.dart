import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';

/// Optional shell that rebuilds children when auth status changes.
/// Primary RBAC routing is handled by [AppRouter] redirects.
class RoleBasedRouter extends StatelessWidget {
  const RoleBasedRouter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) =>
          previous.status != current.status || previous.user != current.user,
      builder: (context, state) {
        if (state.status == AuthStatus.loading ||
            state.status == AuthStatus.unknown) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child;
      },
    );
  }
}
