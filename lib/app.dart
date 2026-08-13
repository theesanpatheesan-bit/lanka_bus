import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lanka_bus/core/constants/app_constants.dart';
import 'package:lanka_bus/core/router/app_router.dart';
import 'package:lanka_bus/core/theme/app_theme.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';

class LankaBusApp extends StatefulWidget {
  const LankaBusApp({super.key});

  @override
  State<LankaBusApp> createState() => _LankaBusAppState();
}

class _LankaBusAppState extends State<LankaBusApp> {
  late final GoRouterAuthRefresh _authRefresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthBloc>();
    _authRefresh = GoRouterAuthRefresh(authBloc);
    _router = AppRouter.create(authBloc, refresh: _authRefresh);
  }

  @override
  void dispose() {
    _authRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
