import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/core/constants/app_constants.dart';
import 'package:lanka_bus/core/utils/phone_utils.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';

/// Tabbed Passenger vs Operator/Partner login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (prev, next) =>
            next.status == AuthStatus.error && next.errorMessage != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: scheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
          context.read<AuthBloc>().add(const AuthErrorCleared());
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.directions_bus_filled_rounded,
                      size: 40,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Book and manage buses across Sri Lanka',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  controller: _tabController,
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.55),
                  indicatorColor: scheme.primary,
                  tabs: const [
                    Tab(text: 'Passenger'),
                    Tab(text: 'Operator / Partner'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _PassengerLoginPane(),
                    _PartnerLoginPane(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassengerLoginPane extends StatefulWidget {
  const _PassengerLoginPane();

  @override
  State<_PassengerLoginPane> createState() => _PassengerLoginPaneState();
}

class _PassengerLoginPaneState extends State<_PassengerLoginPane> {
  bool _usePhone = true;
  bool _isSignUp = false;

  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final loading = state.status == AuthStatus.loading;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Phone OTP'),
                      icon: Icon(Icons.sms_outlined),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Email'),
                      icon: Icon(Icons.email_outlined),
                    ),
                  ],
                  selected: {_usePhone},
                  onSelectionChanged: loading
                      ? null
                      : (value) => setState(() {
                            _usePhone = value.first;
                            _isSignUp = false;
                          }),
                ),
                const SizedBox(height: 24),
                if (_usePhone) ...[
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name (optional)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+\s]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      hintText: '07X XXX XXXX',
                      prefixIcon: Icon(Icons.phone_android),
                      helperText: 'Sri Lanka numbers — we add +94 automatically',
                    ),
                    validator: (value) {
                      if (!PhoneUtils.isValidLocalOrE164(value ?? '')) {
                        return 'Enter a valid Sri Lankan mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: loading ? null : _submitPhone,
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send OTP'),
                  ),
                ] else ...[
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: loading ? null : _submitEmail,
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? 'Create account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : 'New passenger? Create an account',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitPhone() {
    if (!_formKey.currentState!.validate()) return;
    final e164 = PhoneUtils.normalizeToE164(_phoneController.text);
    if (e164 == null) return;

    context.read<AuthBloc>().add(
          AuthPhoneOtpRequested(
            phoneE164: e164,
            fullName: _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim(),
          ),
        );
  }

  void _submitEmail() {
    if (!_formKey.currentState!.validate()) return;
    final bloc = context.read<AuthBloc>();
    if (_isSignUp) {
      bloc.add(
        AuthPassengerSignUpRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        ),
      );
    } else {
      bloc.add(
        AuthPassengerEmailSignInRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }
}

class _PartnerLoginPane extends StatefulWidget {
  const _PartnerLoginPane();

  @override
  State<_PartnerLoginPane> createState() => _PartnerLoginPaneState();
}

class _PartnerLoginPaneState extends State<_PartnerLoginPane> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final loading = state.status == AuthStatus.loading;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'For bus operators, conductors, and admins. '
                  'Your role is verified against the users table.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Work email',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () {
                          if (!_formKey.currentState!.validate()) return;
                          context.read<AuthBloc>().add(
                                AuthPartnerEmailSignInRequested(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text,
                                ),
                              );
                        },
                  child: loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in to partner portal'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
