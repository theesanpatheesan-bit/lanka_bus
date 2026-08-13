import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/core/utils/phone_utils.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify phone'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<AuthBloc>().add(const AuthOtpCancelled());
          },
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (prev, next) =>
            next.errorMessage != null &&
            next.errorMessage != prev.errorMessage,
        listener: (context, state) {
          if (state.errorMessage == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: scheme.error,
            ),
          );
        },
        builder: (context, state) {
          final phone = state.pendingPhoneE164 ?? '';
          final loading = state.status == AuthStatus.loading;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter the 6-digit code sent to',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    PhoneUtils.mask(phone),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          letterSpacing: 12,
                          fontWeight: FontWeight.w600,
                        ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'OTP code',
                      hintText: '••••••',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 4) {
                        return 'Enter the OTP from SMS';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: loading || phone.isEmpty
                        ? null
                        : () {
                            if (!_formKey.currentState!.validate()) return;
                            context.read<AuthBloc>().add(
                                  AuthPhoneOtpVerified(
                                    phoneE164: phone,
                                    token: _otpController.text.trim(),
                                    fullName: state.pendingFullName,
                                  ),
                                );
                          },
                    child: loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify & continue'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading || phone.isEmpty
                        ? null
                        : () {
                            context.read<AuthBloc>().add(
                                  AuthPhoneOtpRequested(
                                    phoneE164: phone,
                                    fullName: state.pendingFullName,
                                  ),
                                );
                          },
                    child: const Text('Resend OTP'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
