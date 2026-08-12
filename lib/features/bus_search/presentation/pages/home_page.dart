import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lanka_bus/core/constants/app_constants.dart';
import 'package:lanka_bus/features/auth/presentation/bloc/auth_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final name = state.user?.fullName ?? 'Passenger';
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ayubowan, $name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Search buses across Sri Lanka — Colombo, Kandy, Galle, and more.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bus search feature — Step 2'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Search buses'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
